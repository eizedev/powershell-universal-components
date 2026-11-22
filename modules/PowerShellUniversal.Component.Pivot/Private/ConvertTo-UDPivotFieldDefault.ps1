function ConvertTo-UDPivotFieldDefault {
    <#
    .SYNOPSIS
        Checks -FieldDefaults and -FieldDescriptions and returns them as one dictionary in pivotkit's
        shape (field name to agg, format, drillFormat, label, description, href, order, type).
    .DESCRIPTION
        Used by New-UDPivotReport. Every entry of -FieldDefaults is a hashtable (or an object) with the
        keys Agg, Format, DrillFormat (names such as average or number:1), Label (text, cut at 120
        characters), Description (text, cut at 1000), Href (an absolute https link without user name or
        password), Order (a list of at most 1000 items: text, numbers, true/false, null) and Type
        (string, number, date or boolean). -FieldDescriptions adds a description per field where
        -FieldDefaults gives none. Values that are no text where text is expected, unknown keys, links
        that are not https and more than 1000 fields throw an error that names the field.
    .PARAMETER FieldDefaults
        The value of -FieldDefaults.
    .PARAMETER FieldDescriptions
        The value of -FieldDescriptions: field name to text. Empty texts, $null and DBNull are left out.
    .EXAMPLE
        ConvertTo-UDPivotFieldDefault -FieldDefaults @{ LeadHours = @{ Agg = 'average'; Label = 'Lead time' } } -FieldDescriptions @{ LeadHours = 'Hours from created to resolved' }
    .OUTPUTS
        System.Collections.Specialized.OrderedDictionary
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param([System.Collections.IDictionary]$FieldDefaults, [System.Collections.IDictionary]$FieldDescriptions)

    $result = [ordered]@{}
    # an ordered dictionary's keys are case-sensitive; the fields are matched without regard to case
    $fieldOf = @{}
    $entryOf = {
        param([string]$Field)
        $key = $Field.ToLowerInvariant()
        if (-not $fieldOf.ContainsKey($key)) {
            if ($fieldOf.Count -ge $Script:MaxFields) { throw ('-FieldDefaults and -FieldDescriptions: more than {0} fields.' -f $Script:MaxFields) }
            $fieldOf[$key] = $Field
            $result[$Field] = [ordered]@{}
        }
        $result[$fieldOf[$key]]
    }
    $checkName = {
        param($Field, [string]$Parameter)
        if ($Field -isnot [string] -or [string]::IsNullOrWhiteSpace($Field) -or $Field.Length -gt $Script:MaxNameLength) {
            throw ('{0}: field names must be text of 1 to {1} characters.' -f $Parameter, $Script:MaxNameLength)
        }
    }

    if ($FieldDefaults) {
        foreach ($field in $FieldDefaults.Keys) {
            & $checkName $field '-FieldDefaults'
            $source = $FieldDefaults[$field]
            if ($source -isnot [System.Collections.IDictionary] -and $source -isnot [System.Management.Automation.PSCustomObject]) {
                throw ('-FieldDefaults, "{0}": expected @{{ Agg = ...; Format = ...; Label = ...; Description = ... }}.' -f $field)
            }
            $names = if ($source -is [System.Collections.IDictionary]) { @($source.Keys | ForEach-Object { [string]$_ }) } else { @($source.PSObject.Properties.Name) }
            $entry = & $entryOf $field
            foreach ($name in $names) {
                $known = $Script:FieldDefaultKeys.Keys | Where-Object { $_ -eq $name } | Select-Object -First 1
                if (-not $known) { throw ('-FieldDefaults, "{0}": unknown key "{1}"; known are {2}.' -f $field, $name, ($Script:FieldDefaultKeys.Keys -join ', ')) }
                $value = Get-UDPivotEntryValue -InputObject $source -Name $name
                if ($null -eq $value -or $value -is [System.DBNull]) { continue }
                $target = $Script:FieldDefaultKeys[$known]
                switch ($known) {
                    { $_ -in 'Agg', 'Format', 'DrillFormat' } {
                        if ($value -isnot [string] -or $value -notmatch $Script:FormatNamePattern) { throw ('-FieldDefaults, "{0}": {1} must be a name such as average or number:1.' -f $field, $known) }
                        $entry[$target] = $value
                    }
                    'Label' {
                        if ($value -isnot [string]) { throw ('-FieldDefaults, "{0}": Label must be text.' -f $field) }
                        $text = Limit-UDPivotText -Text $value -MaxLength $Script:MaxLabelLength
                        if ($text) { $entry[$target] = $text }
                    }
                    'Description' {
                        if ($value -isnot [string]) { throw ('-FieldDefaults, "{0}": Description must be text.' -f $field) }
                        $text = Limit-UDPivotText -Text $value -MaxLength $Script:MaxDescriptionLength
                        if ($text) { $entry[$target] = $text }
                    }
                    'Href' {
                        $uri = $null
                        if ($value -isnot [string] -or $value.Length -gt $Script:MaxHrefLength -or -not [uri]::TryCreate($value.Trim(), [System.UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https' -or $uri.UserInfo) {
                            throw ('-FieldDefaults, "{0}": Href must be an absolute https link without user name or password, at most {1} characters.' -f $field, $Script:MaxHrefLength)
                        }
                        $entry[$target] = $uri.AbsoluteUri
                    }
                    'Order' {
                        $items = @($value)
                        if ($items.Count -gt $Script:MaxOrderLength) { throw ('-FieldDefaults, "{0}": Order has more than {1} items.' -f $field, $Script:MaxOrderLength) }
                        foreach ($item in $items) {
                            $scalar = $null -eq $item -or $item -is [string] -or $item -is [bool] -or $item -is [int] -or $item -is [long] -or $item -is [double] -or $item -is [decimal]
                            if (-not $scalar -or ($item -is [string] -and $item.Length -gt $Script:MaxDescriptionLength)) {
                                throw ('-FieldDefaults, "{0}": Order must list values (text of at most {1} characters, numbers, $true, $false, $null).' -f $field, $Script:MaxDescriptionLength)
                            }
                        }
                        $entry[$target] = [object[]]$items
                    }
                    'Type' {
                        if ($value -isnot [string] -or $value -notin 'string', 'number', 'date', 'boolean') { throw ('-FieldDefaults, "{0}": Type must be string, number, date or boolean.' -f $field) }
                        $entry[$target] = $value.ToLowerInvariant()
                    }
                }
            }
        }
    }
    if ($FieldDescriptions) {
        foreach ($field in $FieldDescriptions.Keys) {
            & $checkName $field '-FieldDescriptions'
            $value = $FieldDescriptions[$field]
            if ($null -eq $value -or $value -is [System.DBNull]) { continue }
            if ($value -isnot [string]) { throw ('-FieldDescriptions, "{0}": the description must be text.' -f $field) }
            $text = Limit-UDPivotText -Text $value -MaxLength $Script:MaxDescriptionLength
            if (-not $text) { continue }
            $entry = & $entryOf $field
            # -FieldDefaults names the field's description more precisely: it wins
            if (-not $entry.Contains('description')) { $entry['description'] = $text }
        }
    }
    foreach ($field in @($result.Keys)) { if ($result[$field].Count -eq 0) { $result.Remove($field) } }
    $result
}
