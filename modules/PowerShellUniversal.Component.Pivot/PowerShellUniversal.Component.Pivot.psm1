$ErrorActionPreference = 'Stop'

#region Shared code and asset registration
# The build copies the repository's shared/powershell/*.ps1 into Private/; from a source checkout
# they are loaded from there directly.
$private = Join-Path $PSScriptRoot 'Private'
if (-not (Test-Path -LiteralPath $private)) { $private = Join-Path $PSScriptRoot '..' '..' 'shared' 'powershell' }
foreach ($file in Get-ChildItem -LiteralPath $private -Filter '*.ps1' -File) { . $file.FullName }
$Script:AssetId = Register-PSUComponentAsset -Path $PSScriptRoot
#endregion

#region Limits of a view
# The keys of a pivotkit view (pivotkit-core's View); ConvertFrom-UDPivotView keeps only these.
$Script:ViewKeys = @{
    version    = 'number'
    rows       = 'names'
    cols       = 'names'
    values     = 'objects'
    filters    = 'objects'
    derived    = 'objects'
    sort       = 'objects'
    totals     = 'object'
    collapsed  = 'object'
    display    = 'string'
    chart      = 'object'
    formatting = 'object'
}
# a view as JSON is a few kilobytes; this leaves room for long filter lists
$Script:MaxViewLength = 64KB
# nesting of a view: values[].conditional.colors, collapsed.rows[][] - four levels
$Script:MaxViewDepth = 8
$Script:MaxListLength = 64
$Script:MaxNameLength = 256
#endregion

#region Limits of field descriptions, schemas and chart options
# the caps of pivotkit (pivotkit-core's SCHEMA_CAPS): longer texts are cut here already, so a prop
# never carries more than the report would show
$Script:MaxFields = 1000
$Script:MaxLabelLength = 120
$Script:MaxDescriptionLength = 1000
$Script:MaxHrefLength = 2000
$Script:MaxOrderLength = 1000
$Script:FieldDefaultKeys = [ordered]@{
    Agg         = 'agg'
    Format      = 'format'
    DrillFormat = 'drillFormat'
    Label       = 'label'
    Description = 'description'
    Href        = 'href'
    Order       = 'order'
    Type        = 'type'
}
$Script:FormatNamePattern = '^[A-Za-z0-9:._%-]{1,64}$'
# a schema or the field defaults as JSON: the browser refuses longer ones too (prepare.js)
$Script:MaxSchemaLength = 1MB
$Script:MaxSchemaDepth = 64
$Script:SchemaTimeoutSec = 15
# a schema fetched from a URL is kept this long per PowerShell runspace, so a page does not fetch it on
# every render
$Script:SchemaCacheMinutes = 10
$Script:SchemaCache = @{}
$Script:MaxChartOptionsLength = 64KB
$Script:MaxChartOptionsDepth = 16
$Script:TipPattern = '^[A-Za-z][A-Za-z0-9-]{0,39}$'
# the descriptions of a table's columns: sys.extended_properties class 1 (object or column), major_id the
# object_id, minor_id the column_id (sys.extended_properties and sys.columns on Microsoft Learn)
$Script:SqlColumnDescriptionQuery = @'
SELECT c.name AS ColumnName, CAST(ep.value AS nvarchar(4000)) AS Description
FROM sys.columns AS c
INNER JOIN sys.extended_properties AS ep
    ON ep.class = 1 AND ep.major_id = c.object_id AND ep.minor_id = c.column_id AND ep.name = @Name
WHERE c.object_id = OBJECT_ID(@Table)
ORDER BY c.column_id;
'@
#endregion

#region Parameters New-UDPivotReport and New-UDPivotReportPlaceholder share
# a CSS length or calc()/clamp()/min()/max(); a bare number is pixels
$Script:HeightPattern = '^\s*(\d+(\.\d+)?(px|vh|svh|dvh|em|rem|%)?|(calc|clamp|min|max)\(.*\))\s*$'
$Script:LocalePattern = '^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*$'
$Script:MissingAssetMessage = 'PowerShellUniversal.Component.Pivot: the JavaScript bundle (index.<hash>.bundle.js) was not found next to the module, or the module was imported outside PowerShell Universal.'
#endregion

function ConvertFrom-UDPivotView {
    <#
    .SYNOPSIS
        Checks a pivot view (a report layout) and returns it as a clean object or as compact JSON.
    .DESCRIPTION
        A view is the report as JSON: the fields on Rows, Columns, Values and Filters, sorting, totals,
        the chart. Views come from the browser ($EventData of -OnViewChange and -OnSaveTemplate), from
        files or from a database, so treat them as untrusted input: this function is the check before
        a view is stored or used.

        It accepts a JSON string, a hashtable or a PSCustomObject. The view goes through one round trip
        ConvertTo-Json/ConvertFrom-Json (nothing is evaluated) and must be a JSON object of at most
        -MaxLength characters and at most eight levels deep. Only the keys of a pivotkit view are kept
        (version, rows, cols, values, filters, derived, sort, totals, collapsed, display, chart,
        formatting); rows and cols must be lists of at most 64 field names, values, filters, derived and
        sort lists of at most 64 objects, display "table" or "chart". Anything else throws an error that
        says what is wrong. The report itself checks every field name and setting against the data
        again (pivotkit-core's normalize) and drops what does not fit.
    .PARAMETER InputObject
        The view: a JSON string, a hashtable or a PSCustomObject (e.g. $EventData.view).
    .PARAMETER MaxLength
        The longest view accepted, in characters of compact JSON. Default: 65536.
    .PARAMETER AsJson
        Return the view as compact JSON (for a file or a database column) instead of an object.
    .EXAMPLE
        $view = ConvertFrom-UDPivotView -InputObject $EventData.view
    .EXAMPLE
        Set-Content -LiteralPath $path -Value (ConvertFrom-UDPivotView -InputObject $EventData.json -AsJson)
    .EXAMPLE
        ConvertFrom-UDPivotView '{"rows":["Team"],"values":[{"field":"Hours","agg":"sum"}]}'
    .OUTPUTS
        System.Management.Automation.PSCustomObject, or System.String with -AsJson.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject], [string])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)][AllowNull()][object]$InputObject,
        [ValidateRange(256, 1MB)][int]$MaxLength = $Script:MaxViewLength,
        [switch]$AsJson
    )
    process {
        if ($null -eq $InputObject) { throw 'Pivot view: no view (null).' }
        if ($InputObject -is [string]) {
            $json = $InputObject.Trim()
        }
        else {
            # deeper than a view can be: ConvertTo-Json cuts it off with a warning, ConvertFrom-Json then sees
            # the cut-off levels as strings and the shape check below refuses them
            $json = ConvertTo-Json -InputObject $InputObject -Depth ($Script:MaxViewDepth + 1) -Compress -WarningAction SilentlyContinue
        }
        if ($json.Length -gt $MaxLength) { throw ('Pivot view: {0} characters, more than the {1} allowed.' -f $json.Length, $MaxLength) }
        try {
            $parsed = ConvertFrom-Json -InputObject $json -Depth $Script:MaxViewDepth -NoEnumerate
        }
        catch {
            throw ('Pivot view: not valid JSON of at most {0} levels ({1})' -f $Script:MaxViewDepth, $_.Exception.Message)
        }
        if ($parsed -isnot [System.Management.Automation.PSCustomObject]) { throw 'Pivot view: expected a JSON object.' }

        $view = [ordered]@{}
        foreach ($property in $parsed.PSObject.Properties) {
            $key = $Script:ViewKeys.Keys | Where-Object { $_ -eq $property.Name } | Select-Object -First 1
            if (-not $key) { continue }
            $value = $property.Value
            if ($null -eq $value) { continue }
            switch ($Script:ViewKeys[$key]) {
                'number' {
                    if ($value -isnot [long] -and $value -isnot [int] -and $value -isnot [double]) { throw ('Pivot view: {0} must be a number.' -f $key) }
                }
                'string' {
                    if ($value -isnot [string] -or $value -notin 'table', 'chart') { throw ('Pivot view: {0} must be "table" or "chart".' -f $key) }
                }
                'object' {
                    if ($value -isnot [System.Management.Automation.PSCustomObject]) { throw ('Pivot view: {0} must be an object.' -f $key) }
                }
                'names' {
                    $list = @($value)
                    if ($value -isnot [array] -or $list.Count -gt $Script:MaxListLength) { throw ('Pivot view: {0} must be a list of at most {1} field names.' -f $key, $Script:MaxListLength) }
                    foreach ($name in $list) {
                        if ($name -isnot [string] -or $name.Length -gt $Script:MaxNameLength) { throw ('Pivot view: {0} must hold field names (text of at most {1} characters).' -f $key, $Script:MaxNameLength) }
                    }
                    $value = [string[]]$list
                }
                'objects' {
                    $list = @($value)
                    if ($value -isnot [array] -or $list.Count -gt $Script:MaxListLength) { throw ('Pivot view: {0} must be a list of at most {1} entries.' -f $key, $Script:MaxListLength) }
                    foreach ($entry in $list) {
                        if ($entry -isnot [System.Management.Automation.PSCustomObject]) { throw ('Pivot view: every entry of {0} must be an object.' -f $key) }
                    }
                    $value = [object[]]$list
                }
            }
            $view[$key] = $value
        }
        $result = [pscustomobject]$view
        if ($AsJson) { return ConvertTo-Json -InputObject $result -Depth $Script:MaxViewDepth -Compress }
        $result
    }
}

function ConvertTo-UDPivotTemplate {
    <#
    .SYNOPSIS
        Checks the entries of -Templates and returns them as name, view, scope and deletable.
    .DESCRIPTION
        Used by New-UDPivotReport. An entry is a hashtable or an object with Name (plain text, 1 to 120
        characters), View (as ConvertFrom-UDPivotView accepts it) or File (a pivotkit view file as text
        or object, read by ConvertFrom-UDPivotViewFile; its name is the default of Name), Scope (shared or
        user; without it a Deletable entry is the reader's own, every other one shared, as in pivotkit)
        and Deletable. A wrong entry throws an error that names it.
    .PARAMETER Template
        The entries.
    .EXAMPLE
        ConvertTo-UDPivotTemplate -Template @(@{ Name = 'Per team'; View = @{ rows = @('Team') } })
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([AllowEmptyCollection()][object[]]$Template)

    $index = 0
    foreach ($entry in $Template) {
        $index++
        if ($null -eq $entry) { continue }
        $name = Get-UDPivotEntryValue -InputObject $entry -Name 'Name'
        $file = Get-UDPivotEntryValue -InputObject $entry -Name 'File'
        $label = if ($name -is [string] -and $name.Trim()) { $name } else { 'entry {0}' -f $index }
        try {
            if ($null -ne $file) {
                $read = ConvertFrom-UDPivotViewFile -InputObject $file -Name $name
                $view = $read.View
                if (-not ($name -is [string] -and $name.Trim())) { $name = $read.Name }
            }
            else {
                $view = ConvertFrom-UDPivotView -InputObject (Get-UDPivotEntryValue -InputObject $entry -Name 'View')
            }
            $name = ConvertTo-UDPivotTemplateName -Name $name
        }
        catch {
            throw ('-Templates, "{0}": {1}' -f $label, $_.Exception.Message)
        }
        $deletable = [bool](Get-UDPivotEntryValue -InputObject $entry -Name 'Deletable')
        $scope = [string](Get-UDPivotEntryValue -InputObject $entry -Name 'Scope')
        # pivotkit's rule without a scope: a deletable entry is the reader's own, every other one shared
        if (-not $scope) { $scope = if ($deletable) { 'user' } else { 'shared' } }
        if ($scope -notin 'shared', 'user') { throw ('-Templates, "{0}": Scope must be shared or user.' -f $name) }
        [pscustomobject]@{ name = $name; view = $view; scope = $scope.ToLowerInvariant(); deletable = $deletable }
    }
}

function Get-UDPivotTimeZone {
    <#
    .SYNOPSIS
        The server's time zone as an IANA name (Europe/Berlin), the default of -TimeZone.
    .DESCRIPTION
        Browsers know IANA names only; on Windows the zone id (W. Europe Standard Time) is converted.
        On Linux and macOS the name comes from TZ or the /etc/localtime link first: .NET may name the
        zone by another entry with the same rules (Atlantic/Jan_Mayen for Europe/Berlin, measured on
        macOS), which shows the same times but reads oddly. UTC when there is no IANA name.
    .EXAMPLE
        Get-UDPivotTimeZone
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    $pattern = '^(UTC|[A-Za-z_]+(/[A-Za-z0-9_+-]+){1,2})$'
    if ($env:TZ -and $env:TZ.TrimStart(':') -match $pattern) { return $env:TZ.TrimStart(':') }
    if (-not $IsWindows) {
        $link = Get-Item -LiteralPath '/etc/localtime' -ErrorAction Ignore
        $name = if ($link -and $link.LinkTarget -match 'zoneinfo/(?<zone>.+)$') { $Matches.zone }
        if ($name -and $name -match $pattern) { return $name }
    }
    $zone = [System.TimeZoneInfo]::Local
    if ($zone.HasIanaId) { return $zone.Id }
    $iana = $null
    if ([System.TimeZoneInfo]::TryConvertWindowsIdToIanaId($zone.Id, [ref]$iana)) { return $iana }
    'UTC'
}

function ConvertTo-UDPivotHeight {
    <#
    .SYNOPSIS
        -Height as the report takes it: a bare number becomes pixels, anything else stays as it is.
    .PARAMETER Height
        The value of -Height (already checked against $Script:HeightPattern).
    .EXAMPLE
        ConvertTo-UDPivotHeight -Height 640
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string]$Height)
    $value = $Height.Trim()
    if ($value -match '^\d+(\.\d+)?$') { '{0}px' -f $value } else { $value }
}

function Test-UDPivotJsonText {
    <#
    .SYNOPSIS
        Checks that a text is one JSON object of at most -MaxLength characters and -MaxDepth levels.
    .DESCRIPTION
        Parses with System.Text.Json (strict JSON, no comments or trailing commas, nothing evaluated) and
        throws an error that starts with -Name when the text is not such an object.
    .PARAMETER Text
        The JSON text.
    .PARAMETER Name
        The parameter the text came from, for the error message.
    .PARAMETER MaxLength
        The longest text accepted, in characters.
    .PARAMETER MaxDepth
        The deepest nesting accepted.
    .EXAMPLE
        Test-UDPivotJsonText -Text '{"title":{"text":"Tickets"}}' -Name '-ChartOptions' -MaxLength 65536 -MaxDepth 16
    .OUTPUTS
        System.String, the text without leading and trailing white space.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][int]$MaxLength,
        [Parameter(Mandatory)][int]$MaxDepth
    )
    $json = $Text.Trim()
    if ($json.Length -gt $MaxLength) { throw ('{0}: {1} characters, more than the {2} allowed.' -f $Name, $json.Length, $MaxLength) }
    $options = [System.Text.Json.JsonDocumentOptions]::new()
    $options.MaxDepth = $MaxDepth
    try {
        $document = [System.Text.Json.JsonDocument]::Parse($json, $options)
    }
    catch {
        throw ('{0}: not valid JSON of at most {1} levels ({2})' -f $Name, $MaxDepth, $_.Exception.InnerException.Message ?? $_.Exception.Message)
    }
    try {
        if ($document.RootElement.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) { throw ('{0}: expected a JSON object.' -f $Name) }
    }
    finally {
        $document.Dispose()
    }
    $json
}

function ConvertTo-UDPivotJsonText {
    <#
    .SYNOPSIS
        A hashtable, an object or a JSON string as checked compact JSON text, for a prop PSU must not
        camelCase.
    .DESCRIPTION
        PSU camelCases the keys of objects in props on their way to the browser; field names and schema
        names in them would change. As JSON text they arrive as they are. A string is taken as JSON;
        anything else goes through ConvertTo-Json. The result is checked by Test-UDPivotJsonText.
    .PARAMETER InputObject
        The value: a hashtable, an ordered dictionary, a PSCustomObject or a JSON string.
    .PARAMETER Name
        The parameter the value came from, for error messages.
    .PARAMETER MaxLength
        The longest JSON accepted, in characters.
    .PARAMETER MaxDepth
        The deepest nesting accepted.
    .EXAMPLE
        ConvertTo-UDPivotJsonText -InputObject @{ legend = @{ show = $false } } -Name '-ChartOptions' -MaxLength 65536 -MaxDepth 16
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][AllowNull()][object]$InputObject,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][int]$MaxLength,
        [Parameter(Mandatory)][int]$MaxDepth
    )
    if ($null -eq $InputObject) { throw ('{0}: no value (null).' -f $Name) }
    $text = if ($InputObject -is [string]) { $InputObject } else {
        # one level deeper than allowed: ConvertTo-Json cuts deeper levels off with a warning and writes
        # them as text, which the depth check below then refuses
        ConvertTo-Json -InputObject $InputObject -Depth ($MaxDepth + 1) -Compress -WarningAction SilentlyContinue
    }
    Test-UDPivotJsonText -Text $text -Name $Name -MaxLength $MaxLength -MaxDepth $MaxDepth
}

function Get-UDPivotEntryValue {
    <#
    .SYNOPSIS
        The value of a key of a dictionary or a property of an object, the name matched without regard to case.
    .PARAMETER InputObject
        A dictionary (hashtable, ordered) or an object.
    .PARAMETER Name
        The key or property name.
    .EXAMPLE
        Get-UDPivotEntryValue -InputObject @{ label = 'Lead time' } -Name 'Label'
    .OUTPUTS
        System.Object
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param([Parameter(Mandatory)][object]$InputObject, [Parameter(Mandatory)][string]$Name)
    if ($InputObject -is [System.Collections.IDictionary]) {
        # the comma keeps a list a list (a one-element array would come back as its element)
        foreach ($key in $InputObject.Keys) { if ([string]$key -eq $Name) { return , $InputObject[$key] } }
        return $null
    }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($property) { , $property.Value }
}

function Limit-UDPivotText {
    <#
    .SYNOPSIS
        A text cut to -MaxLength characters (ending with an ellipsis when cut), or $null for an empty one.
    .PARAMETER Text
        The text.
    .PARAMETER MaxLength
        The longest text kept.
    .EXAMPLE
        Limit-UDPivotText -Text $description -MaxLength 1000
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowNull()][AllowEmptyString()][string]$Text, [Parameter(Mandatory)][int]$MaxLength)
    $value = "$Text".Trim()
    if (-not $value) { return $null }
    if ($value.Length -le $MaxLength) { return $value }
    $value.Substring(0, $MaxLength - 1).TrimEnd() + [char]0x2026
}

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

function Get-UDPivotSchemaText {
    <#
    .SYNOPSIS
        -Schema as checked JSON text: from a hashtable or object, a JSON string, a file or an https URL.
    .DESCRIPTION
        Used by New-UDPivotReport. A string that starts with { is JSON; one that starts with https:// is
        fetched on the server (timeout 15 seconds, at most 1 MB, kept for 10 minutes per PowerShell
        runspace); another address scheme (http://, file://) is refused; any other string is a file path.
        The schema must be one JSON object of at most 1 MB and 64 levels. pivotkit-core reads it in the
        browser; nothing in it runs, and only references inside the document are followed.
    .PARAMETER Schema
        The value of -Schema.
    .EXAMPLE
        Get-UDPivotSchemaText -Schema 'https://example.org/openapi.json'
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][object]$Schema)

    $check = @{ Name = '-Schema'; MaxLength = $Script:MaxSchemaLength; MaxDepth = $Script:MaxSchemaDepth }
    if ($Schema -isnot [string]) { return ConvertTo-UDPivotJsonText -InputObject $Schema @check }
    $value = $Schema.Trim()
    if ($value.StartsWith('{')) { return Test-UDPivotJsonText -Text $value @check }
    if ($value -match '^https://') {
        $cached = $Script:SchemaCache[$value]
        if ($cached -and $cached.Time -gt [datetime]::UtcNow.AddMinutes(-$Script:SchemaCacheMinutes)) { return $cached.Text }
        $client = [System.Net.Http.HttpClient]::new()
        try {
            $client.Timeout = [timespan]::FromSeconds($Script:SchemaTimeoutSec)
            # the answer is read into memory only up to this size; a longer one fails
            $client.MaxResponseContentBufferSize = $Script:MaxSchemaLength * 4
            $text = $client.GetStringAsync($value).GetAwaiter().GetResult()
        }
        catch {
            throw ('-Schema: {0} could not be read ({1})' -f $value, $_.Exception.Message)
        }
        finally {
            $client.Dispose()
        }
        $text = Test-UDPivotJsonText -Text $text @check
        $Script:SchemaCache[$value] = @{ Text = $text; Time = [datetime]::UtcNow }
        return $text
    }
    if ($value -match '^[A-Za-z][A-Za-z0-9+.-]+://') { throw ('-Schema: only https:// addresses are fetched, not "{0}".' -f ($value -replace '^([A-Za-z0-9+.-]+://).*', '$1')) }
    $file = Get-Item -LiteralPath $value -ErrorAction Ignore
    if ($file -isnot [System.IO.FileInfo]) { throw ('-Schema: no file "{0}" (expected a hashtable, JSON, an https URL or a file path).' -f $value) }
    # UTF-8 takes up to four bytes per character; a larger file cannot hold an allowed schema
    if ($file.Length -gt $Script:MaxSchemaLength * 4) { throw ('-Schema: "{0}" is larger than {1} bytes.' -f $value, ($Script:MaxSchemaLength * 4)) }
    Test-UDPivotJsonText -Text (Get-Content -LiteralPath $file.FullName -Raw -Encoding utf8) @check
}

#region Templates: view files, template folders and template stores
# pivotkit's view file (pivotkit-core's VIEW_FILE_LIMITS, VIEW_FILE_SCHEMA, VIEW_VERSION)
$Script:ViewFileFormat = 'pivotkit-view'
$Script:ViewFileSchemaUrl = 'https://pivotkit.eize.dev/schema/view-file-1.json'
$Script:MaxViewFileLength = 1000000
$Script:MaxViewFileDepth = 16
$Script:MaxViewFileDescription = 2000
$Script:KnownViewVersion = 1
# a template's name in the Views menu (pivotkit-react's save field takes 120 characters)
$Script:MaxTemplateNameLength = 120
# templates the report gets in all (pivotkit-core's TEMPLATE_LIMITS.count)
$Script:MaxTemplates = 500
# the default caps of a template store
$Script:DefaultMaxUserViews = 50
$Script:DefaultMaxSharedViews = 200
$Script:StoreLockTimeoutSec = 10
# the stores of the reports, for the event handlers the module registers for them: PSU runs a handler
# in a runspace of its own, which does not see the module's state of the page's runspace, but the same
# process. Process-wide, keyed by a hash of the app, the report and its settings.
$Script:StoreRegistryName = 'PowerShellUniversal.Component.Pivot.TemplateStores'
$Script:MaxStoreRegistryEntries = 1000
$Script:ModuleVersion = (Import-PowerShellDataFile -LiteralPath (Join-Path $PSScriptRoot "PowerShellUniversal.Component.Pivot.psd1")).ModuleVersion

function Get-UDPivotSha256 {
    <#
    .SYNOPSIS
        The SHA-256 of a text (UTF-8) as lower-case hex, cut to -Length characters.
    .PARAMETER Text
        The text.
    .PARAMETER Length
        Characters of the hex string to keep (2 to 64).
    .EXAMPLE
        Get-UDPivotSha256 -Text 'alex' -Length 24
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text, [ValidateRange(2, 64)][int]$Length = 64)
    $hash = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($Text))
    [System.Convert]::ToHexString($hash).Substring(0, $Length).ToLowerInvariant()
}

function ConvertTo-UDPivotTemplateName {
    <#
    .SYNOPSIS
        A template name as plain text: control characters become spaces, trimmed, 1 to 120 characters.
    .PARAMETER Name
        The name from the browser, a file or a store.
    .EXAMPLE
        ConvertTo-UDPivotTemplateName -Name ' Open work per team '
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowNull()][object]$Name)
    if ($Name -isnot [string]) { throw 'A view name must be text.' }
    $text = ($Name -replace '[\p{Cc}\p{Cf}\u2028\u2029]', ' ').Trim()
    if ($text.Length -lt 1 -or $text.Length -gt $Script:MaxTemplateNameLength) {
        throw ('A view name has 1 to {0} characters.' -f $Script:MaxTemplateNameLength)
    }
    $text
}

function Get-UDPivotViewFileName {
    <#
    .SYNOPSIS
        The file name a template store keeps a view under: <slug>-<hash>.pivotkit.json.
    .DESCRIPTION
        The slug is the name in lower case without accents, every run of other characters a "-" (as
        pivotkit-core's viewFileName), at most 60 characters; the hash (10 hex characters of the SHA-256
        of the source id and the name as it is) keeps two names apart that give the same slug, the same
        name in another case (pivotkit tells names apart by case), and the views of two reports with the
        same name. Nothing of the name can leave the folder. The file name of a new view only: a save over
        a stored view keeps that view's file (Invoke-UDPivotTemplateStore finds it by its name).
    .PARAMETER Name
        The checked template name.
    .PARAMETER SourceId
        The id of the data the view was made for (New-UDPivotReport -SourceId).
    .PARAMETER Attempt
        Another file name for the same name (1, 2, ...), when the first one holds another view.
    .PARAMETER Legacy
        The file name version 0.1.0 gave the view: the hash of the source id and the name in lower case
        (one file for a name in any case). Never the same as a file name of this version.
    .NOTES
        The parts of the hashed text are joined with a NUL character, which a checked name never holds,
        so a file name of this version and one of 0.1.0 (joined with "|") never meet.
    .EXAMPLE
        Get-UDPivotViewFileName -Name 'Revenue by region' -SourceId 'sales'
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string]$Name, [AllowEmptyString()][AllowNull()][string]$SourceId, [ValidateRange(0, 100)][int]$Attempt = 0, [switch]$Legacy)
    $plain = -join ($Name.ToLowerInvariant().Normalize([System.Text.NormalizationForm]::FormKD).ToCharArray() |
            Where-Object { [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne [System.Globalization.UnicodeCategory]::NonSpacingMark })
    $slug = ($plain -replace '[^a-z0-9]+', '-').Trim('-')
    if ($slug.Length -gt 60) { $slug = $slug.Substring(0, 60).Trim('-') }
    if (-not $slug) { $slug = 'view' }
    $text = if ($Legacy) { '{0}|{1}' -f $SourceId, $Name.ToLowerInvariant() }
    else { (@($SourceId, $Name) + @(if ($Attempt) { $Attempt })) -join [char]0 }
    '{0}-{1}.pivotkit.json' -f $slug, (Get-UDPivotSha256 -Text $text -Length 10)
}

function ConvertFrom-UDPivotViewFile {
    <#
    .SYNOPSIS
        Reads a pivotkit view file (or a saved view { name, view }) and returns its name, description,
        source and checked view.
    .DESCRIPTION
        A view file is the JSON pivotkit's Views menu downloads (Download view, Copy view as JSON) and a
        template store keeps: format "pivotkit-view", formatVersion 1, name, description, source and the
        view. This function reads one as untrusted input: at most 1,000,000 characters and 16 levels,
        parsed without evaluating anything; a newer formatVersion or view version is refused (saving it
        again would lose what the newer version added); the name becomes plain text of 1 to 120
        characters; the view goes through ConvertFrom-UDPivotView. An object { name, view } (a saved view
        as an app keeps it) is read as well; a bare view needs -Name.
    .PARAMETER InputObject
        The view file: JSON text, a hashtable or an object.
    .PARAMETER Name
        The name of a view file that has none (a bare view), such as the file's name.
    .EXAMPLE
        ConvertFrom-UDPivotViewFile -InputObject (Get-Content -LiteralPath ./open-work.pivotkit.json -Raw)
    .OUTPUTS
        System.Management.Automation.PSCustomObject with Name, Description, Source (id, name), Generator
        (name, version: what wrote the file) and View.
    .LINK
        https://powershell-universal-components.eize.dev/pivot/templates/
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)][AllowNull()][object]$InputObject,
        [string]$Name
    )
    process {
        if ($null -eq $InputObject) { throw 'View file: no content (null).' }
        $json = if ($InputObject -is [string]) { $InputObject.Trim() } else {
            ConvertTo-Json -InputObject $InputObject -Depth ($Script:MaxViewFileDepth + 1) -Compress -WarningAction SilentlyContinue
        }
        $json = Test-UDPivotJsonText -Text $json -Name 'View file' -MaxLength $Script:MaxViewFileLength -MaxDepth $Script:MaxViewFileDepth
        $file = ConvertFrom-Json -InputObject $json -Depth $Script:MaxViewFileDepth -NoEnumerate
        # keys in any case: an object from PowerShell has Name and View
        $get = { param($Key) $p = $file.PSObject.Properties | Where-Object { $_.Name -eq $Key } | Select-Object -First 1; if ($p) { , $p.Value } }

        $isFile = (& $get 'format') -ceq $Script:ViewFileFormat
        if ($isFile) {
            $version = & $get 'formatVersion'
            if ($null -ne $version -and -not (($version -is [int] -or $version -is [long]) -and $version -eq 1)) {
                if (($version -is [int] -or $version -is [long] -or $version -is [double] -or $version -is [decimal]) -and $version -gt 1) {
                    throw ('View file: format version {0} is newer than this module reads (1); update PowerShellUniversal.Component.Pivot.' -f $version)
                }
                throw 'View file: formatVersion must be 1.'
            }
        }
        $view = & $get 'view'
        if ($null -eq $view) {
            # a bare view: the whole document is the view
            if ($isFile) { throw 'View file: no view.' }
            $view = $file
        }
        $viewVersion = if ($view -is [System.Management.Automation.PSCustomObject]) { $view.PSObject.Properties['version'].Value }
        if (($viewVersion -is [int] -or $viewVersion -is [long] -or $viewVersion -is [double]) -and $viewVersion -gt $Script:KnownViewVersion) {
            throw ('View file: view version {0} is newer than this module reads ({1}); update PowerShellUniversal.Component.Pivot.' -f $viewVersion, $Script:KnownViewVersion)
        }
        $checked = ConvertFrom-UDPivotView -InputObject $view

        $title = & $get 'name'
        if ($title -isnot [string] -or [string]::IsNullOrWhiteSpace($title)) { $title = $Name }
        $description = & $get 'description'
        $source = & $get 'source'
        $generator = & $get 'generator'
        [pscustomobject]@{
            Name        = ConvertTo-UDPivotTemplateName -Name $title
            Description = if ($description -is [string]) { Limit-UDPivotText -Text ($description -replace '[\p{Cc}\p{Cf}]', ' ') -MaxLength $Script:MaxViewFileDescription }
            Source      = if ($source -is [System.Management.Automation.PSCustomObject]) {
                [pscustomobject]@{
                    id   = if ($source.id -is [string]) { Limit-UDPivotText -Text $source.id -MaxLength $Script:MaxNameLength }
                    name = if ($source.name -is [string]) { Limit-UDPivotText -Text $source.name -MaxLength $Script:MaxNameLength }
                }
            }
            Generator   = if ($generator -is [System.Management.Automation.PSCustomObject]) {
                [pscustomobject]@{
                    name    = if ($generator.name -is [string]) { Limit-UDPivotText -Text $generator.name -MaxLength $Script:MaxNameLength }
                    version = if ($generator.version -is [string]) { Limit-UDPivotText -Text $generator.version -MaxLength 40 }
                }
            }
            View        = $checked
        }
    }
}

function ConvertTo-UDPivotViewFile {
    <#
    .SYNOPSIS
        A view as a pivotkit view file: the JSON pivotkit's Views menu loads and a template store keeps.
    .DESCRIPTION
        Checks the view with ConvertFrom-UDPivotView and writes the envelope in pivotkit's key order
        ($schema, format, formatVersion, name, description, createdAt, generator, source, extensions,
        view) with a two-space indent and a trailing newline.
    .PARAMETER View
        The view (JSON text, a hashtable or an object).
    .PARAMETER Name
        The view's name (1 to 120 characters of plain text).
    .PARAMETER Description
        More about it, at most 2000 characters.
    .PARAMETER SourceId
        The id of the data the view was made for (New-UDPivotReport -SourceId, default its -Id).
    .PARAMETER SourceName
        The name of that data, for people.
    .PARAMETER SchemaUrl
        The $schema of the file: pivotkit's schema by default, your own copy, or '' to leave it out.
    .PARAMETER CreatedAt
        When it was written (UTC). Without it the file is the same bytes for the same view.
    .EXAMPLE
        ConvertTo-UDPivotViewFile -View $EventData.view -Name 'Open work per team' -SourceId 'tickets'
    .OUTPUTS
        System.String
    .LINK
        https://powershell-universal-components.eize.dev/pivot/templates/
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][AllowNull()][object]$View,
        [Parameter(Mandatory)][string]$Name,
        [AllowEmptyString()][string]$Description,
        [AllowEmptyString()][string]$SourceId,
        [AllowEmptyString()][string]$SourceName,
        [AllowEmptyString()][string]$SchemaUrl = $Script:ViewFileSchemaUrl,
        [Nullable[datetime]]$CreatedAt
    )
    $checked = ConvertFrom-UDPivotView -InputObject $View
    $file = [ordered]@{}
    if ($SchemaUrl) { $file['$schema'] = $SchemaUrl }
    $file['format'] = $Script:ViewFileFormat
    $file['formatVersion'] = 1
    $file['name'] = ConvertTo-UDPivotTemplateName -Name $Name
    $text = Limit-UDPivotText -Text ($Description -replace '[\p{Cc}\p{Cf}]', ' ') -MaxLength $Script:MaxViewFileDescription
    if ($text) { $file['description'] = $text }
    if ($CreatedAt) { $file['createdAt'] = ([datetime]$CreatedAt).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [cultureinfo]::InvariantCulture) }
    $file['generator'] = [ordered]@{ name = 'PowerShellUniversal.Component.Pivot'; version = [string]$Script:ModuleVersion }
    $source = [ordered]@{}
    if ($SourceId) { $source['id'] = Limit-UDPivotText -Text $SourceId -MaxLength $Script:MaxNameLength }
    if ($SourceName) { $source['name'] = Limit-UDPivotText -Text $SourceName -MaxLength $Script:MaxNameLength }
    $file['source'] = $source
    $file['extensions'] = [ordered]@{}
    $file['view'] = $checked
    (ConvertTo-Json -InputObject $file -Depth ($Script:MaxViewDepth + 2)) -replace "`r`n", "`n"
}

function Get-UDPivotTemplateFile {
    <#
    .SYNOPSIS
        The view files (*.pivotkit.json) of one or more folders, as templates: Name, View, File.
    .DESCRIPTION
        Used by New-UDPivotReport -TemplatePath and the file template store. Reads the files of each
        folder (not its subfolders) in the order of their names; a file larger than 4 MB (the
        1,000,000 characters of a view file in UTF-8), one that is no view file or a view
        ConvertFrom-UDPivotView refuses is left out with a warning, so one broken file never breaks a
        page. At most -MaxCount templates.
    .PARAMETER Path
        The folders.
    .PARAMETER MaxCount
        The most templates returned. Default: 500.
    .EXAMPLE
        Get-UDPivotTemplateFile -Path (Join-Path $PSScriptRoot 'views')
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)][string[]]$Path, [int]$MaxCount = $Script:MaxTemplates)
    $count = 0
    foreach ($folder in $Path) {
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) { continue }
        $files = Get-ChildItem -LiteralPath $folder -Filter '*.pivotkit.json' -File -ErrorAction SilentlyContinue | Sort-Object Name
        foreach ($file in $files) {
            if ($count -ge $MaxCount) {
                Write-Warning ('Pivot templates: more than {0}; the rest of {1} is left out.' -f $MaxCount, $folder)
                return
            }
            if ($file.Length -gt $Script:MaxViewFileLength * 4) {
                Write-Warning ('Pivot template {0} skipped: larger than {1} bytes.' -f $file.Name, ($Script:MaxViewFileLength * 4))
                continue
            }
            try {
                $read = ConvertFrom-UDPivotViewFile -InputObject (Get-Content -LiteralPath $file.FullName -Raw -Encoding utf8) -Name ($file.Name -replace '\.pivotkit\.json$', '')
                $count++
                [pscustomobject]@{ Name = $read.Name; View = $read.View; File = $file.Name; SourceId = if ($read.Source) { $read.Source.id } }
            }
            catch {
                Write-Warning ('Pivot template {0} skipped: {1}' -f $file.Name, $_.Exception.Message)
            }
        }
    }
}

function New-UDPivotFileTemplateStore {
    <#
    .SYNOPSIS
        A template store that keeps the readers' views as view files in a folder on the server.
    .DESCRIPTION
        For New-UDPivotReport -TemplateStore. Every signed-in reader saves views under "My views" and sees
        them on every device; views in the shared folder are listed for everyone under "Shared views",
        and only readers with a role of New-UDPivotReport -AdminRole publish or delete them.

        Layout below -Path: users/<hash of the user name>/ holds a reader's own views, shared/ the shared
        ones, each view a pivotkit view file <slug>-<hash>.pivotkit.json (the files Download view in the
        Views menu writes; shared/ also works as a -TemplatePath). Writes go to a new file that then
        replaces the old one, under a lock per folder, so two saves at the same moment never leave half a
        file or lose the count. -MaxUserViews and -MaxSharedViews cap the number of views per folder.

        Without -Path the store lies next to the PSU repository ($Repository), never inside it: a
        repository synced with git would pick the files up. On several PSU nodes (high availability) a
        local folder is per node: use a shared folder, or a store on a database
        (New-UDPivotTemplateStore).
    .PARAMETER Path
        The folder. Default: pivot-views next to the repository folder ($Repository of the app, else
        $env:Data__RepositoryPath).
    .PARAMETER MaxUserViews
        The most views a reader keeps. Default: 50.
    .PARAMETER MaxSharedViews
        The most shared views. Default: 200.
    .EXAMPLE
        $store = New-UDPivotFileTemplateStore
        New-UDPivotReport -Id 'tickets' -Data $tickets -TemplateStore $store -AdminRole 'Administrator'
    .EXAMPLE
        New-UDPivotFileTemplateStore -Path 'D:\PSUData\pivot-views' -MaxUserViews 20
    .OUTPUTS
        System.Management.Automation.PSCustomObject (UDPivotTemplateStore)
    .LINK
        https://powershell-universal-components.eize.dev/pivot/templates/
    #>
    # describes a store; creates nothing until the first save, so no ShouldProcess
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [ValidateNotNullOrEmpty()][string]$Path,
        [ValidateRange(1, 500)][int]$MaxUserViews = $Script:DefaultMaxUserViews,
        [ValidateRange(1, 500)][int]$MaxSharedViews = $Script:DefaultMaxSharedViews
    )
    if (-not $Path) {
        # $Repository of the app script that calls this (PSU's documented global variable)
        $repository = $PSCmdlet.SessionState.PSVariable.GetValue('Repository')
        if (-not $repository) { $repository = $env:Data__RepositoryPath }
        if (-not $repository) { throw 'New-UDPivotFileTemplateStore: no $Repository to put the store next to; pass -Path.' }
        $Path = Join-Path (Split-Path -Parent ([string]$repository)) 'pivot-views'
    }
    [pscustomobject]@{
        PSTypeName     = 'UDPivotTemplateStore'
        Kind           = 'File'
        Path           = [System.IO.Path]::GetFullPath($Path)
        Get            = $null
        Save           = $null
        Delete         = $null
        Publish        = $null
        MaxUserViews   = $MaxUserViews
        MaxSharedViews = $MaxSharedViews
    }
}

function New-UDPivotTemplateStore {
    <#
    .SYNOPSIS
        A template store on your own storage (a database, Valkey or Redis, S3): you write how a view is
        stored, the module does the rest.
    .DESCRIPTION
        For New-UDPivotReport -TemplateStore. The module decides who may do what (the signed-in user,
        -AdminRole for shared views, checked on the server), checks every name and view, applies the
        limits and writes the view file; the script blocks only store and load. Each gets one argument,
        $Request:

        - Get: Scope ('user' or 'shared'), User (the user name; $null for shared), UserKey (a hash of the
          user name, safe in a key or file name). Return the stored views: view file texts (the Json of
          a save), objects with Json and FileName (where it is stored), or objects with Name and View. The
          module checks each one again.
        - Save: Scope, User, UserKey, Name (checked), FileName, Key ('users/<UserKey>/<FileName>' or
          'shared/<FileName>'), Json (the view file to store) and View (the checked view). Store it under
          FileName, replacing what is there: for a name the scope has (the same characters in the same
          case, as pivotkit compares names) the module passes the FileName of that view, so a save
          replaces it; for a new name <slug>-<hash>.pivotkit.json that no stored view has.
        - Delete: Scope, User, UserKey, Name, FileName, Key.
        - Publish (optional): as Save with Scope 'shared' and User the publisher. Without it, publishing
          calls Save with Scope 'shared'.

        Throw to refuse: the reader sees the message. The script blocks run in the runspace of the app
        script that defined them and do not see $User or $Roles: use $Request. PSU runs event handlers
        in runspaces of their own, so a script block needs every module and variable it uses (Import-Module
        inside it).
    .PARAMETER Get
        Returns the views of one scope (and user).
    .PARAMETER Save
        Stores one view.
    .PARAMETER Delete
        Removes one view.
    .PARAMETER Publish
        Stores a shared view, when that differs from Save with Scope 'shared'.
    .PARAMETER MaxUserViews
        The most views a reader keeps. Default: 50.
    .PARAMETER MaxSharedViews
        The most shared views. Default: 200.
    .EXAMPLE
        # SQL Server: a table PivotViews (Scope, UserKey, FileName, Json)
        $store = New-UDPivotTemplateStore -Get {
            param($Request)
            Invoke-Sqlcmd -ConnectionString $cs -Query 'SELECT Json FROM PivotViews WHERE Scope = @s AND UserKey = @u' -Variable ... | ForEach-Object Json
        } -Save { param($Request) ... } -Delete { param($Request) ... }
    .OUTPUTS
        System.Management.Automation.PSCustomObject (UDPivotTemplateStore)
    .LINK
        https://powershell-universal-components.eize.dev/pivot/templates/
    #>
    # describes a store; changes nothing itself, so no ShouldProcess
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][scriptblock]$Get,
        [Parameter(Mandatory)][scriptblock]$Save,
        [Parameter(Mandatory)][scriptblock]$Delete,
        [scriptblock]$Publish,
        [ValidateRange(1, 500)][int]$MaxUserViews = $Script:DefaultMaxUserViews,
        [ValidateRange(1, 500)][int]$MaxSharedViews = $Script:DefaultMaxSharedViews
    )
    [pscustomobject]@{
        PSTypeName     = 'UDPivotTemplateStore'
        Kind           = 'Custom'
        Path           = $null
        Get            = $Get
        Save           = $Save
        Delete         = $Delete
        Publish        = $Publish
        MaxUserViews   = $MaxUserViews
        MaxSharedViews = $MaxSharedViews
    }
}

function Test-UDPivotTemplateStore {
    <#
    .SYNOPSIS
        True for a store of New-UDPivotFileTemplateStore or New-UDPivotTemplateStore.
    .PARAMETER Store
        The value of -TemplateStore.
    .EXAMPLE
        Test-UDPivotTemplateStore -Store $store
    .OUTPUTS
        System.Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([AllowNull()][object]$Store)
    $Store -is [System.Management.Automation.PSCustomObject] -and $Store.PSObject.TypeNames -contains 'UDPivotTemplateStore' -and $Store.Kind -in 'File', 'Custom'
}

function Invoke-UDPivotStoreLock {
    <#
    .SYNOPSIS
        Runs a script block while holding the lock of one store folder or key (a named mutex).
    .PARAMETER Name
        What is locked (a folder, a key).
    .PARAMETER ScriptBlock
        The work.
    .EXAMPLE
        Invoke-UDPivotStoreLock -Name $folder -ScriptBlock { ... }
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][scriptblock]$ScriptBlock)
    $mutex = [System.Threading.Mutex]::new($false, ('udpivot-{0}' -f (Get-UDPivotSha256 -Text $Name.ToLowerInvariant() -Length 32)))
    $held = $false
    try {
        try { $held = $mutex.WaitOne([timespan]::FromSeconds($Script:StoreLockTimeoutSec)) }
        catch [System.Threading.AbandonedMutexException] { $held = $true }
        if (-not $held) { throw 'The view store is busy; try again.' }
        & $ScriptBlock
    }
    finally {
        if ($held) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
}

function Invoke-UDPivotTemplateStore {
    <#
    .SYNOPSIS
        Lists, saves or deletes views in a template store, with the module's checks and limits.
    .DESCRIPTION
        The one place that talks to a store: New-UDPivotReport lists with it, the event handlers save,
        publish and delete with it (Invoke-UDPivotTemplateRequest). Who may do what is decided before:
        this function only checks names, views and limits. Save and Publish are an upsert: a view of the
        name the report lists (the same characters in the same case, as pivotkit compares names; one
        made for this report's data first, else one made for no named data) is replaced where it is
        stored, and a copy of it stored twice goes; Delete removes the views of the name the same way.
    .PARAMETER Store
        A store of New-UDPivotFileTemplateStore or New-UDPivotTemplateStore.
    .PARAMETER Action
        List, Save, Publish or Delete.
    .PARAMETER Scope
        user or shared.
    .PARAMETER UserName
        The signed-in user (scope user; the publisher for Publish).
    .PARAMETER Name
        The view's name (Save, Publish, Delete).
    .PARAMETER View
        The view (Save, Publish).
    .PARAMETER SourceId
        The data the view was made for, written into the view file.
    .PARAMETER SourceName
        Its name for people.
    .PARAMETER SchemaUrl
        The $schema of the view file.
    .EXAMPLE
        Invoke-UDPivotTemplateStore -Store $store -Action List -Scope shared
    .OUTPUTS
        System.Management.Automation.PSCustomObject (List: Name and View)
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][object]$Store,
        [Parameter(Mandatory)][ValidateSet('List', 'Save', 'Publish', 'Delete')][string]$Action,
        [Parameter(Mandatory)][ValidateSet('user', 'shared')][string]$Scope,
        [AllowEmptyString()][string]$UserName,
        [AllowNull()][object]$Name,
        [AllowNull()][object]$View,
        [AllowEmptyString()][string]$SourceId,
        [AllowEmptyString()][string]$SourceName,
        [AllowEmptyString()][string]$SchemaUrl = $Script:ViewFileSchemaUrl
    )
    if (-not (Test-UDPivotTemplateStore -Store $Store)) { throw '-TemplateStore: expected a store of New-UDPivotFileTemplateStore or New-UDPivotTemplateStore.' }
    if ($Action -eq 'Publish') { $Scope = 'shared' }
    if ($Scope -eq 'user' -and [string]::IsNullOrWhiteSpace($UserName)) { throw 'Sign in to keep your own views.' }
    $userKey = if ($Scope -eq 'user') { Get-UDPivotSha256 -Text $UserName.Trim().ToLowerInvariant() -Length 24 }
    $max = if ($Scope -eq 'user') { $Store.MaxUserViews } else { $Store.MaxSharedViews }
    $folder = if ($Store.Kind -eq 'File') {
        if ($Scope -eq 'user') { Join-Path $Store.Path 'users' $userKey } else { Join-Path $Store.Path 'shared' }
    }
    $request = [ordered]@{
        Scope   = $Scope
        User    = if ($Scope -eq 'user' -or $Action -eq 'Publish') { $UserName } else { $null }
        UserKey = $userKey
    }

    # the stored views of this scope, each checked again (a store can be changed by hand); a folder holds
    # the views of every report of the store, so the list is capped by what a report takes, not by $max.
    # File: where a view is stored (its file; for a custom store the FileName Get returns, else the one a
    # save gives it), so a save over it replaces it in place. Files: every place it may be stored: for a
    # custom store without FileName also the one version 0.1.0 gave it (a hash of the name in lower case,
    # which "Sales" and "sales" share), unless the stored file says this module wrote it from 0.2.0 on,
    # which never uses that place: so a view saved now never claims the place of an old one.
    $list = {
        if ($Store.Kind -eq 'File') { return @(Get-UDPivotTemplateFile -Path $folder -MaxCount $Script:MaxTemplates | ForEach-Object { $_ | Add-Member -NotePropertyName Files -NotePropertyValue @($_.File) -PassThru }) }
        $index = 0
        @(foreach ($entry in @(& $Store.Get ([pscustomobject]$request))) {
                $index++
                if ($null -eq $entry) { continue }
                if ($index -gt $Script:MaxTemplates) { Write-Warning ('Pivot template store: more than {0} {1} views; the rest is left out.' -f $Script:MaxTemplates, $Scope); break }
                try {
                    $source = if ($entry -is [string]) { $entry } else {
                        $json = Get-UDPivotEntryValue -InputObject $entry -Name 'Json'
                        if ($json -is [string]) { $json } else { $entry }
                    }
                    $read = ConvertFrom-UDPivotViewFile -InputObject $source
                    $sourceId = if ($read.Source) { $read.Source.id }
                    $stored = if ($entry -isnot [string]) { Get-UDPivotEntryValue -InputObject $entry -Name 'FileName' }
                    $writtenBy = $read.Generator
                    $version = $null
                    $current = $writtenBy -and $writtenBy.name -ceq 'PowerShellUniversal.Component.Pivot' -and [version]::TryParse([string]$writtenBy.version, [ref]$version) -and $version -ge [version]'0.2.0'
                    $files = @(if ($stored -is [string] -and $stored -match '^[^\\/\p{Cc}]{1,255}$' -and $stored -notin '.', '..') { $stored } else {
                            Get-UDPivotViewFileName -Name $read.Name -SourceId $sourceId
                            if (-not $current) { Get-UDPivotViewFileName -Name $read.Name -SourceId $sourceId -Legacy }
                        }) | Select-Object -Unique
                    $files = @($files)
                    [pscustomobject]@{ Name = $read.Name; View = $read.View; File = $files[0]; Files = @($files); SourceId = $sourceId }
                }
                catch { Write-Warning ('Pivot template store: a {0} view skipped: {1}' -f $Scope, $_.Exception.Message) }
            })
    }

    # one store serves several reports: a report lists the views of its data and those made for no
    # named data (as pivotkit's browser store)
    $reportData = [string]$SourceId
    $viewFile = @{ SourceName = $SourceName; SchemaUrl = $SchemaUrl }
    $listed = { param($Entry) -not $reportData -or -not $Entry.SourceId -or $Entry.SourceId -ceq $reportData }
    if ($Action -eq 'List') { return & $list | Where-Object { & $listed $_ } }

    $checkedName = ConvertTo-UDPivotTemplateName -Name $Name
    $request['Name'] = $checkedName
    # the views of this name the report lists, by pivotkit's rule (its Views menu compares names with
    # ===: the same characters in the same case): those made for this data, else those made for no named
    # data, as pivotkit's browser store replaces them
    $named = {
        param($Entries)
        $all = @($Entries | Where-Object { $_.Name -ceq $checkedName -and (& $listed $_) })
        $same = @($all | Where-Object { [string]$_.SourceId -ceq [string]$reportData })
        if ($same.Count) { $same } else { @($all | Where-Object { -not $_.SourceId }) }
    }
    $requestFor = {
        param([string]$FileName)
        $out = [ordered]@{}
        foreach ($k in $request.Keys) { $out[$k] = $request[$k] }
        $out['FileName'] = $FileName
        $out['Key'] = if ($Scope -eq 'user') { 'users/{0}/{1}' -f $userKey, $FileName } else { 'shared/{0}' -f $FileName }
        $out
    }
    $remove = {
        param([string]$FileName)
        if ($Store.Kind -eq 'File') {
            $target = Join-Path $folder $FileName
            if (Test-Path -LiteralPath $target -PathType Leaf) { Remove-Item -LiteralPath $target -Force }
        }
        else { $null = & $Store.Delete ([pscustomobject](& $requestFor $FileName)) }
    }
    # takes the view of this name out of every place it may be stored but -Keep (a copy; the place version
    # 0.1.0 gave it), never out of a place another view may be in. Some of these places are guesses (a
    # custom store without FileName), so a failed delete there is a warning; with -Strict (Delete) a view
    # of which no place could be deleted is an error the reader sees.
    $clear = {
        param([object[]]$Found, [object[]]$All, [string]$Keep, [switch]$Strict)
        $claimed = @($All | Where-Object { $Found -notcontains $_ } | ForEach-Object { $_.Files })
        $done = @{}
        foreach ($entry in $Found) {
            $failed = $null
            $removed = 0
            foreach ($file in @($entry.Files | Where-Object { $_ -ne $Keep -and $claimed -notcontains $_ })) {
                if ($done.ContainsKey($file)) { $removed++; continue }
                try { & $remove $file; $done[$file] = $true; $removed++ }
                catch { if (-not $failed) { $failed = $_ } }
            }
            if ($failed) {
                if ($Strict -and -not $removed) { throw $failed }
                Write-Warning ('Pivot template store: "{0}" could not be removed from one place: {1}' -f $checkedName, $failed.Exception.Message)
            }
        }
    }
    # a folder, or a custom store's scope and user: list and write as one step, so two saves of a new
    # name at the same moment neither store it twice nor go over the limit
    $lockName = if ($Store.Kind -eq 'File') { $folder } else { 'store|{0}|{1}|{2}' -f (Get-UDPivotSha256 -Text $Store.Save.ToString()), $Scope, $userKey }

    if ($Action -eq 'Delete') {
        Invoke-UDPivotStoreLock -Name $lockName -ScriptBlock {
            $all = @(& $list)
            $found = @(& $named $all)
            # none listed (a stored view broken by hand): the file a save of this name gives it
            if ($found.Count) { & $clear $found $all '' -Strict }
            else { & $remove (Get-UDPivotViewFileName -Name $checkedName -SourceId $reportData) }
        }
        return
    }

    # Save and Publish: the checked view as a view file; what is stored is never the input itself. A view
    # of the name replaces the stored one in place (an upsert: pivotkit's Save sends an existing name)
    $checkedView = ConvertFrom-UDPivotView -InputObject $View
    $full = { ('At most {0} {1} views; delete one first.' -f $max, $(if ($Scope -eq 'user') { 'own' } else { 'shared' })) }

    Invoke-UDPivotStoreLock -Name $lockName -ScriptBlock {
        $all = @(& $list)
        $found = @(& $named $all)
        if ($found.Count) {
            # its file and its data stay (a view made for no named data stays one)
            $fileName = $found[0].File
            $fileSource = [string]$found[0].SourceId
        }
        else {
            $count = if ($Store.Kind -eq 'File') { @(Get-ChildItem -LiteralPath $folder -Filter '*.pivotkit.json' -File -ErrorAction SilentlyContinue).Count } else { $all.Count }
            if ($count -ge $max) { throw (& $full) }
            # a file name no other view holds (one stored by hand); file names compared without case, as
            # on Windows and macOS
            $attempt = 0
            do {
                $fileName = Get-UDPivotViewFileName -Name $checkedName -SourceId $reportData -Attempt $attempt
                $attempt++
                $taken = @($all | Where-Object { $_.Files -contains $fileName }).Count -or ($Store.Kind -eq 'File' -and (Test-Path -LiteralPath (Join-Path $folder $fileName)))
            } while ($taken)
            $fileSource = $reportData
        }
        $json = ConvertTo-UDPivotViewFile -View $checkedView -Name $checkedName -SourceId $fileSource -SourceName $(if ($fileSource) { $viewFile.SourceName }) -SchemaUrl $viewFile.SchemaUrl -CreatedAt ([datetime]::UtcNow)

        if ($Store.Kind -eq 'File') {
            try { $null = New-Item -ItemType Directory -Path $folder -Force }
            catch { throw ('The view store cannot create its folder ({0}).' -f $_.Exception.Message) }
            # a new file, then replace: a reader never sees half a file
            $target = Join-Path $folder $fileName
            $temp = Join-Path $folder ('.{0}.{1}.tmp' -f $fileName, [guid]::NewGuid().ToString('n'))
            try {
                [System.IO.File]::WriteAllText($temp, $json, [System.Text.UTF8Encoding]::new($false))
                [System.IO.File]::Move($temp, $target, $true)
            }
            finally {
                if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
            }
        }
        else {
            $save = & $requestFor $fileName
            $save['Json'] = $json
            $save['View'] = $checkedView
            if ($Action -eq 'Publish' -and $Store.Publish) { $null = & $Store.Publish ([pscustomobject]$save) }
            else { $null = & $Store.Save ([pscustomobject]$save) }
        }
        # the same view stored twice before (by hand, under another file name): one is left
        & $clear $found $all $fileName
    }
}

function Get-UDPivotStoreRegistry {
    <#
    .SYNOPSIS
        The process-wide table of the reports' template stores (see $Script:StoreRegistryName).
    .EXAMPLE
        (Get-UDPivotStoreRegistry)[$key]
    .OUTPUTS
        System.Collections.Concurrent.ConcurrentDictionary[string, object]
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Concurrent.ConcurrentDictionary[string, object]])]
    param()
    $domain = [System.AppDomain]::CurrentDomain
    $registry = $domain.GetData($Script:StoreRegistryName)
    if ($null -eq $registry) {
        [System.Threading.Monitor]::Enter($domain)
        try {
            $registry = $domain.GetData($Script:StoreRegistryName)
            if ($null -eq $registry) {
                $registry = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
                $domain.SetData($Script:StoreRegistryName, $registry)
            }
        }
        finally {
            [System.Threading.Monitor]::Exit($domain)
        }
    }
    , $registry
}

function Register-UDPivotTemplateStore {
    <#
    .SYNOPSIS
        Keeps a report's store and settings for the event handlers the module registers, and returns
        the key the handlers find them under.
    .PARAMETER Settings
        Store, AdminRole, SourceId, SourceName, SchemaUrl and the app and report it belongs to.
    .EXAMPLE
        $key = Register-UDPivotTemplateStore -Settings $settings
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][hashtable]$Settings)
    # the same report with the same settings gets the same key on every render; the entry is replaced,
    # so the latest store object (its script blocks) is the one the handlers use
    $identity = [ordered]@{
        App        = $Settings.App
        Report     = $Settings.Report
        Kind       = $Settings.Store.Kind
        Path       = $Settings.Store.Path
        Max        = '{0}/{1}' -f $Settings.Store.MaxUserViews, $Settings.Store.MaxSharedViews
        AdminRole  = @($Settings.AdminRole) -join [char]1
        SourceId   = $Settings.SourceId
        SourceName = $Settings.SourceName
        SchemaUrl  = $Settings.SchemaUrl
    }
    $key = Get-UDPivotSha256 -Text (ConvertTo-Json -InputObject $identity -Compress) -Length 32
    $registry = Get-UDPivotStoreRegistry
    $entry = [pscustomobject]@{ Settings = $Settings; Updated = [datetime]::UtcNow }
    $registry[$key] = $entry
    if ($registry.Count -gt $Script:MaxStoreRegistryEntries) {
        # reports with a store created per render (a new key each time): drop the oldest
        $oldest = $registry.GetEnumerator() | Sort-Object { $_.Value.Updated } | Select-Object -First ($registry.Count - $Script:MaxStoreRegistryEntries)
        foreach ($old in $oldest) { $removed = $null; [void]$registry.TryRemove($old.Key, [ref]$removed) }
    }
    $key
}

function Test-UDPivotRole {
    <#
    .SYNOPSIS
        True when one of -Roles is one of -AdminRole (case-insensitive).
    .PARAMETER Roles
        The user's roles ($Roles of PSU).
    .PARAMETER AdminRole
        The roles that may change shared views.
    .EXAMPLE
        Test-UDPivotRole -Roles $Roles -AdminRole 'Administrator'
    .OUTPUTS
        System.Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([AllowNull()][AllowEmptyCollection()][string[]]$Roles, [AllowNull()][AllowEmptyCollection()][string[]]$AdminRole)
    foreach ($role in @($Roles)) {
        if (-not [string]::IsNullOrWhiteSpace($role) -and (@($AdminRole) | Where-Object { $_ -and $_ -eq $role.Trim() })) { return $true }
    }
    $false
}

function Invoke-UDPivotTemplateRequest {
    <#
    .SYNOPSIS
        Saves, publishes or deletes a view for the report's event handlers; decides on the server who
        may do it.
    .DESCRIPTION
        New-UDPivotReport -TemplateStore registers event handlers that call this function with the
        $EventData of the report and the $User and $Roles PSU sets for the event. A reader saves and
        deletes their own views; publishing and deleting shared views needs a role of -AdminRole, checked
        here with the event's $Roles - never with anything the browser sends. Returns nothing on success,
        @{ error = '...' } when it refuses (the report shows the text).
    .PARAMETER Key
        The key of the report's store (Register-UDPivotTemplateStore).
    .PARAMETER Action
        Save, Publish or Delete.
    .PARAMETER EventData
        The report's $EventData: name, view, scope.
    .PARAMETER UserName
        $User of the event.
    .PARAMETER Roles
        $Roles of the event.
    .EXAMPLE
        Invoke-UDPivotTemplateRequest -Key $key -Action Save -EventData $EventData -UserName $User -Roles $Roles
    .OUTPUTS
        System.Collections.Hashtable on refusal.
    .LINK
        https://powershell-universal-components.eize.dev/pivot/templates/
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{32}$')][string]$Key,
        [Parameter(Mandatory)][ValidateSet('Save', 'Publish', 'Delete')][string]$Action,
        [AllowNull()][object]$EventData,
        [AllowNull()][AllowEmptyString()][string]$UserName,
        [AllowNull()][AllowEmptyCollection()][string[]]$Roles
    )
    $entry = $null
    if (-not (Get-UDPivotStoreRegistry).TryGetValue($Key, [ref]$entry)) {
        return @{ error = 'This page is out of date (the app was restarted); reload it.' }
    }
    $settings = $entry.Settings
    $data = if ($null -ne $EventData) { $EventData } else { @{} }
    $scope = if ($Action -eq 'Delete' -and (Get-UDPivotEntryValue -InputObject $data -Name 'scope') -eq 'shared') { 'shared' } elseif ($Action -eq 'Publish') { 'shared' } else { 'user' }
    $isAdmin = Test-UDPivotRole -Roles $Roles -AdminRole $settings.AdminRole
    if ($scope -eq 'shared' -and -not $isAdmin) { return @{ error = 'Only admins can change shared views.' } }
    if ($scope -eq 'user' -and [string]::IsNullOrWhiteSpace($UserName)) { return @{ error = 'Sign in to keep your own views.' } }
    try {
        $arguments = @{
            Store      = $settings.Store
            Action     = $Action
            Scope      = $scope
            UserName   = $UserName
            Name       = Get-UDPivotEntryValue -InputObject $data -Name 'name'
            SourceId   = $settings.SourceId
            SourceName = $settings.SourceName
            SchemaUrl  = $settings.SchemaUrl
        }
        if ($Action -ne 'Delete') { $arguments['View'] = Get-UDPivotEntryValue -InputObject $data -Name 'view' }
        Invoke-UDPivotTemplateStore @arguments
    }
    catch {
        @{ error = $_.Exception.Message }
    }
}

function New-UDPivotTemplateEndpoint {
    <#
    .SYNOPSIS
        The event handler of one template action of a report with -TemplateStore, as a PSU endpoint.
    .DESCRIPTION
        The handler is code text with the store's key in it: PSU runs it in a runspace of its own, where
        it loads the module and calls Invoke-UDPivotTemplateRequest with the $User and $Roles of the event.
    .PARAMETER Key
        The store's key.
    .PARAMETER Action
        Save, Publish or Delete.
    .EXAMPLE
        New-UDPivotTemplateEndpoint -Key $key -Action Save
    .OUTPUTS
        Endpoint
    #>
    # describes a handler for PSU to register; changes no state, so no ShouldProcess
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{32}$')][string]$Key, [Parameter(Mandatory)][ValidateSet('Save', 'Publish', 'Delete')][string]$Action)
    $code = @'
Import-Module PowerShellUniversal.Component.Pivot
Invoke-UDPivotTemplateRequest -Key '{0}' -Action {1} -EventData $EventData -UserName ([string](Get-Variable -Name User -ValueOnly -ErrorAction Ignore)) -Roles @(Get-Variable -Name Roles -ValueOnly -ErrorAction Ignore)
'@ -f $Key, $Action
    [Endpoint][scriptblock]::Create($code)
}
#endregion

function New-UDPivotReport {
    <#
    .SYNOPSIS
        A pivot report builder for PowerShell Universal apps: readers drag fields into rows, columns,
        values and filters and get a table or a chart, with drill-down, templates and Excel export.
    .DESCRIPTION
        Pass the data as it comes - a DataTable from a SQL query, objects from Invoke-RestMethod or any
        PowerShell command. Readers build their own report: a field list with search, four zones (Rows,
        Columns, Values, Filters) with drag and drop and a menu on every field, sums, counts, averages
        and "show values as", date grouping by year, quarter, month or day, filters with value counts,
        table or chart (bars, lines, area, pie, heatmap), a click on a value opens the rows behind it,
        undo and redo, templates, and Excel (XLSX), CSV and PNG export. All of it runs in the browser
        (pivotkit); the server is only asked for what the event parameters do.

        A view - what the report shows - is plain JSON that pivotkit checks against the data; it never
        runs as code. -View sets the start view, -Templates the views offered in the Views menu,
        -TemplatePath reads view files from folders, and -TemplateStore keeps readers' own views and the
        shared ones (New-UDPivotFileTemplateStore, New-UDPivotTemplateStore) with -AdminRole for who may
        change shared views; -OnSaveTemplate and -OnDeleteTemplate stay for full control. Field names are
        matched without regard to case.
    .PARAMETER Id
        Component id. Default: a new GUID. Get-UDElement -Id returns the current view as .view;
        Set-UDElement -Id -Properties @{ view = ... } shows another view (one undo step). The browser
        tab keeps the reader's view under this id; without -Id the report is identified by its page,
        its place in the app script (line and column of the call) and its column names. Set -Id when
        one call builds several reports (a loop) or reports are added or removed at run time.
    .PARAMETER Data
        Rows: a DataTable (Invoke-Sqlcmd, SqlClient, ODBC), DataRows, PSCustomObjects, hashtables or a
        script block returning them. DBNull becomes an empty value, dates stay dates, TimeSpans become
        seconds. The column names are the field names the reader sees.
    .PARAMETER View
        The view the report starts with (and goes back to with Reset): a hashtable or JSON, e.g.
        @{ rows = @('Team'); cols = @('Priority'); values = @(@{ field = 'Id'; agg = 'count' }) }.
        Keys: rows, cols (field names), values (field, agg: sum, count, average, min, max, ...;
        format: a format name), filters, sort, totals, display (table or chart), chart (type: bar, line,
        area, pie, heatmap). A saved template's view goes in as it is. Default: an empty report with the
        hint where to start. A view in the address bar (#pivot-<id>=..., written by the report on every
        change unless -NoAddressBar, so a copied link opens the same layout) wins over it.
    .PARAMETER SavedView
        The reader's own view stored by the app (from -OnViewChange or a "save as my default" action),
        a hashtable or JSON. A browser tab without a view of its own (in its address bar or its
        sessionStorage) starts with it; a tab that already shows a view keeps that one, so a view stored
        for the whole PSU session (shared by all tabs of the browser) never takes over another tab. Reset still goes back to -View. A view that does not
        pass ConvertFrom-UDPivotView is left out with a warning.
    .PARAMETER Templates
        Views offered in the Views menu (the first three also on the empty report): a list of
        @{ Name = 'Tickets per team'; View = <view> } or @{ File = <view file> }, with Scope shared
        ("Shared views") or user ("My views") and Deletable (a delete button when -OnDeleteTemplate is
        set). Without Scope a Deletable entry is the reader's own, every other one shared.
    .PARAMETER TemplatePath
        Folders of pivotkit view files (*.pivotkit.json, as Download view in the Views menu writes them),
        read on the server on every render and offered under "Shared views", read-only. Each file is
        checked (at most 1,000,000 characters, a view ConvertFrom-UDPivotView accepts); a broken one is
        left out with a warning. A module ships its views with -TemplatePath (Join-Path $PSScriptRoot 'views').
        A shared view of -TemplateStore with the same name (same characters, same case) takes the file's
        place: an admin's Publish or Save over a shipped view shows, and deleting it brings the file back.
    .PARAMETER TemplateStore
        Where readers keep their own views ("My views") and admins the shared ones. Without it nothing is
        written and Save is not offered (unless -OnSaveTemplate). Browser: pivotkit keeps each reader's
        views in the browser's localStorage (this browser and device only). A store of
        New-UDPivotFileTemplateStore (view files in a folder on the server) or New-UDPivotTemplateStore
        (your own storage: a database, Valkey, S3): the module registers the event handlers, saves a
        reader's views under their $User, and lets readers with a role of -AdminRole publish and delete
        shared views - checked on the server with $Roles of each event. In an app without sign-in the
        server cannot tell readers apart: their own views then stay in the browser, shared views come
        from the store.
    .PARAMETER AdminRole
        Roles ($Roles) that may publish views as shared views and delete shared views (with
        -TemplateStore, or -OnPublishTemplate), and that see the admin panel under the report (the view as
        JSON, the columns and their types, timings).
    .PARAMETER UserName
        The signed-in user the page shows views for. Default: $User of the page. Pass $User when the call
        runs in a script block or function defined in the app script, which does not see it (measured on
        PSU 2026.2.5 and 2026.3.4). The event handlers use $User of the event.
    .PARAMETER Roles
        The roles of the user, for -AdminRole. Default: $Roles of the page; pass $Roles where -UserName
        has to be passed.
    .PARAMETER SourceId
        The id of the data the report shows, written into view files and links (pivotkit asks before it
        loads a view made for another id). Default: -Id, or the key the module derives without one.
        The Views menu offers the views of -TemplateStore (also Browser) made for this id and those made
        for no named data. A report whose data changes from call to call under the same -Id (an uploaded
        file, a parameter the reader picks) sets -SourceId per data source, e.g. from the file name;
        otherwise the views made for all of its data show together.
    .PARAMETER SourceName
        The name of that data for people (in view files and the load check). Default: -Label.
    .PARAMETER SchemaUrl
        The $schema of the view files the report writes: pivotkit's published schema by default, an
        https address of your own copy, or '' to leave it out. Loading never depends on it.
    .PARAMETER FieldDefaults
        Per field name, what the report knows about the field:
        @{ LeadHours = @{ Agg = 'average'; Format = 'number:1'; Label = 'Lead time (h)'; Description = 'Hours from created to resolved'; Href = 'https://wiki.example.org/lead-time' }; Priority = @{ Order = 'Low', 'Normal', 'High' } }.
        Agg and Format: what the field gets when the reader puts it into Values (format names: number,
        number:2, integer, percent, percent:1, currency:EUR, compact, bytes, duration:s, duration:h, date,
        datetime, time); DrillFormat: the format of its values in the drill-down (text shows an id as it
        is); Label: the name shown for the field everywhere (views keep the field name; at most 120
        characters); Description: plain text behind an "i" next to the field, in its menu and on its
        headers (at most 1000 characters); Href: an https link shown as "Learn more" with the description;
        Order: the field's own order of items on Rows and Columns; Type: string, number, date or boolean,
        the type its column is read as. Checked on the server: text only, https links only, sizes capped.
    .PARAMETER FieldDescriptions
        A description per field name, e.g. from SQL Server column comments
        (Get-UDPivotSqlColumnDescription): @{ LeadHours = 'Hours from created to resolved' }. A Description
        in -FieldDefaults wins; empty values, $null and DBNull are left out.
    .PARAMETER Schema
        A JSON Schema of a row, or an OpenAPI 3 / Swagger 2 document with -SchemaName: a hashtable or
        object, JSON text, a file path, or an https URL (fetched on the server with a timeout of 15
        seconds, at most 1 MB, kept 10 minutes per runspace; the browser never fetches it). The report
        reads titles (labels), descriptions, externalDocs links (https), types and enums (orders) of the
        row's properties with pivotkit-core's fieldDefaultsFromSchema; -FieldDefaults and
        -FieldDescriptions win over it. At most 1 MB and 64 levels.
    .PARAMETER SchemaName
        The schema of a row in an OpenAPI document: a name in components.schemas (definitions in
        Swagger 2) or a local reference such as #/components/schemas/Ticket.
    .PARAMETER ChartOptions
        Plain JSON merged over the chart's Apache ECharts option (a hashtable or JSON text, at most 64 KB),
        e.g. @{ legend = @{ top = 0 }; grid = @{ left = 80 } }; it wins over the view's chart settings.
        pivotkit leaves out options that are markup or addresses (formatter strings, rich, link, image).
    .PARAMETER Tips
        The tips above the result: On (default), Off (none, and no switch in Options), or the ids of the
        tips allowed (showAs, chartOverTime, pieSlices, pieColumns, chartDates, chartTrend, chartSeries,
        textValue, dateUngrouped, manyColumns, afterDrag, values, saveTemplate, menus, cells; the
        notices filterEmpty, top and chartCapped always show). Dismissed tips are remembered per report
        in the browser's localStorage.
    .PARAMETER FieldInfo
        On or Off: the "i" with the field descriptions. Without it the reader switches it in Options.
    .PARAMETER ZoneInfo
        On or Off: the "i" next to the zone titles that explains each zone. Without it the reader
        switches it in Options.
    .PARAMETER SettingInfo
        On or Off: the "i" next to settings that need explaining (totals, Show as, export formats, chart
        labels). Without it the reader switches it ("Show explanations" in Options, Help).
    .PARAMETER FieldList
        Open or Collapsed: how the field list starts on a wide report (collapsed: a rail of about 40
        pixels). Without it the reader's last choice decides.
    .PARAMETER Grow
        On or Off: whether the report grows past -Height to keep its result readable (the page scrolls)
        or stays inside it (the table scrolls). Default: Off, since the report always has a height; a
        card of a fixed size keeps the whole report.
    .PARAMETER Label
        The name screen readers hear for the report (its region landmark). Several reports on one page
        need one name each. Default: "Pivot report".
    .PARAMETER Labels
        Single texts of the report in your own words, merged over the language -Locale picked:
        @{ zones = @{ values = 'Kennzahlen' }; core = @{ grandTotal = 'Summe' } }. The keys are the ones of
        pivotkit-react's LABELS.
    .PARAMETER Locale
        Language and formats: numbers, dates and sorting, and the labels (de-* German, others English).
        Default: en-US. The report never uses the browser's or the server's locale on its own, so a
        report looks the same for every reader; pass de-DE for German.
    .PARAMETER TimeZone
        The zone dates with an offset (DateTimeOffset, a DateTime of kind Local or Utc) are shown in, as an
        IANA name (Europe/Berlin) or UTC. Dates without an offset - what SQL returns for datetime
        columns - are shown as they are. Default: the server's time zone.
    .PARAMETER Theme
        Auto (follows the app's light/dark switch, default), Light or Dark.
    .PARAMETER Height
        Height of the report, e.g. 640px, 80vh or 640 (pixels); the table and the field list scroll inside
        it. Default: one screen, the window's height minus 180 pixels for PSU's app bar and a page title,
        between 600 and 1400 pixels, so the whole report is on screen when the page loads; in a window
        narrower than 640 pixels (a phone) almost the whole window, since the zones stack above the table
        there.
    .PARAMETER FileName
        Name of exported files without the extension. Default: pivot.
    .PARAMETER NoAddressBar
        Keeps the reader's view out of the address bar; the browser tab then keeps it in sessionStorage
        only (a reload and the light/dark switch still keep it, a copied link does not carry it). By
        default the view, filter values included, is written into the address (#pivot-<id>=...), so it
        also ends up in the browser history, in copied links and in the page address PSU sends with its
        requests. Use it for reports whose filter values are sensitive.
    .PARAMETER NoDrillDown
        No panel with the source rows when a value is clicked (-OnCellClick still runs).
    .PARAMETER ClassName
        CSS class of the outer element.
    .PARAMETER Style
        CSS styles of the outer element, e.g. @{ maxWidth = '1200px' }.
    .PARAMETER OnViewChange
        Runs on the server after the reader changed the view (once the reader paused for 0.6 seconds).
        $EventData: view (the view as an object), json (the same as JSON text, to store).
    .PARAMETER OnCellClick
        Runs on the server when the reader clicks a value or a chart point. $EventData: row, col (the
        key paths), rowFields, colFields, filter (one @{ field; value } per level, rows first), valueField,
        value, text (as shown), count (source rows behind the value) and rows (the first 100 of them).
    .PARAMETER OnSaveTemplate
        Shows Save as (and Save on a loaded view of the reader's own) in the Views menu and runs when the
        reader saves. $EventData: name, view, json, scope (user). Save and a confirmed Save as send a name the reader's views already have:
        replace that view (an upsert by name, the same characters in the same case), never add a second
        one. The template appears in the menu (deletable) once the script block finished without
        an error; throw, or return @{ error = 'message' }, to refuse - the reader sees the message.
    .PARAMETER OnDeleteTemplate
        Runs when the reader deletes a deletable template (after confirming in the menu). $EventData:
        name, scope (user or shared). Throw, or return @{ error = 'message' }, to refuse.
    .PARAMETER OnPublishTemplate
        With -AdminRole: "Publish as shared view" on the reader's own views and Save on a shared view, for
        readers with one of the roles. $EventData: name, view, json. A name the shared views have replaces
        that view (an upsert by name). Check $Roles in it again: the browser only hides the button.
    .EXAMPLE
        New-UDPivotReport -Id 'tickets' -Data (Invoke-Sqlcmd -Query 'SELECT * FROM Tickets') -Locale de-DE
    .EXAMPLE
        $view = @{ rows = @('Team'); cols = @('Priority'); values = @(@{ field = 'Id'; agg = 'count' }) }
        New-UDPivotReport -Id 'tickets' -Data $tickets -View $view -Templates @(
            @{ Name = 'Tickets per team'; View = $view }
            @{ Name = 'Lead time per month'; View = @{ rows = @('Created'); values = @(@{ field = 'LeadHours'; agg = 'average'; format = 'number:1' }) } }
        )
    .EXAMPLE
        New-UDPivotReport -Id 'tickets' -Data $tickets -OnCellClick {
            Show-UDToast -Message ('{0} tickets: {1}' -f $EventData.count, (($EventData.filter | ForEach-Object { '{0} = {1}' -f $_.field, $_.value }) -join ', '))
        }
    .EXAMPLE
        New-UDPivotReport -Id 'tickets' -Data $tickets -Templates $saved -OnSaveTemplate {
            $view = ConvertFrom-UDPivotView -InputObject $EventData.view -AsJson
            # store $EventData.name and $view (a file per user, a database table), then:
            Show-UDToast -Message "Saved $($EventData.name)"
        }
    .EXAMPLE
        # shipped views from a folder, readers' own views and shared views in files next to the repository
        $store = New-UDPivotFileTemplateStore
        New-UDPivotReport -Id 'tickets' -Data $tickets -TemplatePath (Join-Path $PSScriptRoot 'views') -TemplateStore $store -AdminRole 'Administrator'
    .EXAMPLE
        # a new tab continues with the reader's last view; open tabs keep their own
        New-UDPivotReport -Id 'tickets' -Data $tickets -View $startView -SavedView $Session:PivotView -OnViewChange {
            Import-Module PowerShellUniversal.Component.Pivot
            $Session:PivotView = ConvertFrom-UDPivotView -InputObject $EventData.json
        }
    .OUTPUTS
        System.Collections.Hashtable
    .LINK
        https://powershell-universal-components.eize.dev/pivot/
    #>
    # describes a component for PSU to render; changes no state, so no ShouldProcess
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string]$Id = [guid]::NewGuid().ToString(),
        [Parameter(Mandatory)][AllowNull()][object]$Data,
        [object]$View,
        [object]$SavedView,
        [AllowEmptyCollection()][object[]]$Templates,
        [ValidateNotNullOrEmpty()][string[]]$TemplatePath,
        [ValidateScript({ $_ -eq 'Browser' -or (Test-UDPivotTemplateStore -Store $_) }, ErrorMessage = 'TemplateStore: expected Browser, or a store of New-UDPivotFileTemplateStore or New-UDPivotTemplateStore.')][object]$TemplateStore,
        [ValidateNotNullOrEmpty()][string[]]$AdminRole,
        [AllowEmptyString()][AllowNull()][string]$UserName,
        [AllowEmptyCollection()][AllowNull()][string[]]$Roles,
        [ValidateLength(1, 256)][string]$SourceId,
        [ValidateLength(1, 256)][string]$SourceName,
        [ValidateScript({ $_ -eq '' -or ($_ -match '^https://\S+$' -and $_.Length -le 2000) }, ErrorMessage = 'SchemaUrl "{0}": expected an https address or an empty string.')][AllowEmptyString()][string]$SchemaUrl,
        [System.Collections.IDictionary]$FieldDefaults,
        [System.Collections.IDictionary]$FieldDescriptions,
        [object]$Schema,
        [ValidateLength(1, 200)][string]$SchemaName,
        [object]$ChartOptions,
        [ValidateScript({ $_ -match $Script:TipPattern }, ErrorMessage = 'Tips "{0}": expected On, Off or tip ids such as values or chartSeries.')][string[]]$Tips,
        [ValidateSet('On', 'Off')][string]$FieldInfo,
        [ValidateSet('On', 'Off')][string]$ZoneInfo,
        [ValidateSet('On', 'Off')][string]$SettingInfo,
        [ValidateSet('Open', 'Collapsed')][string]$FieldList,
        [ValidateSet('On', 'Off')][string]$Grow,
        [ValidateLength(1, 120)][string]$Label,
        [hashtable]$Labels,
        [ValidateScript({ $_ -match $Script:LocalePattern }, ErrorMessage = 'Locale "{0}": expected a language tag such as en-US or de-DE.')][string]$Locale = 'en-US',
        [ValidatePattern('^(UTC|[A-Za-z_]+(/[A-Za-z0-9_+-]+){1,2})$')][string]$TimeZone = (Get-UDPivotTimeZone),
        [ValidateSet('Auto', 'Light', 'Dark')][string]$Theme = 'Auto',
        [ValidateScript({ $_ -match $Script:HeightPattern }, ErrorMessage = 'Height "{0}": expected a CSS length such as 640px, 80vh or 640.')][string]$Height,
        [ValidateLength(1, 120)][string]$FileName = 'pivot',
        [switch]$NoAddressBar,
        [switch]$NoDrillDown,
        [string]$ClassName,
        [hashtable]$Style,
        [Endpoint]$OnViewChange,
        [Endpoint]$OnCellClick,
        [Endpoint]$OnSaveTemplate,
        [Endpoint]$OnDeleteTemplate,
        [Endpoint]$OnPublishTemplate
    )

    if (-not $Script:AssetId) { throw $Script:MissingAssetMessage }
    $timer = [System.Diagnostics.Stopwatch]::StartNew()

    # one array (ConvertTo-PSUComponentData returns it as a single object; @() would nest it)
    $rows = ConvertTo-PSUComponentData -InputObject $Data
    $convertMs = $timer.Elapsed.TotalMilliseconds
    $columnNames = @($rows | Select-Object -First 1 | ForEach-Object { $_.PSObject.Properties.Name })
    # the key the browser keeps the reader's view under: -Id, or without it (a new GUID per build) the
    # place of this call in the app script and the columns, hashed (no server path reaches the browser)
    $storageKey = if ($PSBoundParameters.ContainsKey('Id')) { $Id } else {
        $site = '{0}|{1}|{2}|{3}' -f $MyInvocation.ScriptName, $MyInvocation.ScriptLineNumber, $MyInvocation.OffsetInLine, ($columnNames -join [char]1)
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try { $hash = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($site)) } finally { $sha.Dispose() }
        'auto-' + (-join ($hash[0..7] | ForEach-Object { $_.ToString('x2') }))
    }
    $props = @{
        assetId     = $Script:AssetId
        isPlugin    = $true
        type        = 'ud-pivot-report'
        id          = $Id
        storageKey  = $storageKey
        data        = $rows
        # PSU camelCases the keys of the rows on their way to the browser; the report shows the field
        # names as they are, so the original ones travel along as values (which PSU leaves alone)
        columnNames = $columnNames
        locale      = $Locale
        timeZone    = $TimeZone
        theme       = $Theme.ToLowerInvariant()
        fileName    = $FileName
        drillDown   = -not $NoDrillDown
        addressBar  = -not $NoAddressBar
    }
    if ($PSBoundParameters.ContainsKey('View') -and $null -ne $View) {
        try { $props['view'] = ConvertFrom-UDPivotView -InputObject $View }
        catch { throw ('-View: {0}' -f $_.Exception.Message) }
    }
    if ($PSBoundParameters.ContainsKey('SavedView') -and $null -ne $SavedView) {
        # the reader's stored view is user data: a broken one must not break the page
        try { $props['savedView'] = ConvertFrom-UDPivotView -InputObject $SavedView }
        catch { Write-Warning ('-SavedView left out: {0}' -f $_.Exception.Message) }
    }
    # the data the view files and links name; a view made for another id asks before it is loaded
    $source = [ordered]@{ id = if ($SourceId) { $SourceId } else { $storageKey } }
    if ($SourceName) { $source['name'] = $SourceName } elseif ($Label) { $source['name'] = $Label }
    $props['source'] = [pscustomobject]$source
    if ($PSBoundParameters.ContainsKey('SchemaUrl')) { $props['schemaUrl'] = $SchemaUrl }

    #region Templates, the store and who may change shared views
    $store = if (Test-UDPivotTemplateStore -Store $TemplateStore) { $TemplateStore }
    $customEvents = @('OnSaveTemplate', 'OnDeleteTemplate', 'OnPublishTemplate') | Where-Object { $PSBoundParameters[$_] }
    if ($store -and $customEvents) { throw ('-TemplateStore with a store does the saving itself; leave out {0}, or use them without a store.' -f (($customEvents | ForEach-Object { "-$_" }) -join ', ')) }
    if ($OnPublishTemplate -and -not $AdminRole) { throw '-OnPublishTemplate needs -AdminRole: only readers with one of its roles may publish.' }
    $isAdmin = $false
    $user = $null
    if ($store -or $AdminRole) {
        # $User and $Roles of the page that calls this; a script block defined in the app script has
        # neither (measured), so -UserName and -Roles can be passed
        $user = if ($PSBoundParameters.ContainsKey('UserName')) { $UserName } else { [string]$PSCmdlet.SessionState.PSVariable.GetValue('User') }
        $userRoles = if ($PSBoundParameters.ContainsKey('Roles')) { $Roles } else { @($PSCmdlet.SessionState.PSVariable.GetValue('Roles')) }
        $isAdmin = Test-UDPivotRole -Roles $userRoles -AdminRole $AdminRole
    }
    $templateList = [System.Collections.Generic.List[object]]::new()
    if ($PSBoundParameters.ContainsKey('Templates')) { foreach ($t in @(ConvertTo-UDPivotTemplate -Template $Templates)) { $templateList.Add($t) } }
    $storeViews = @{ shared = @(); user = @() }
    if ($store) {
        # the store's views: a broken store must not break the page
        foreach ($scope in 'shared', 'user') {
            if ($scope -eq 'user' -and -not $user) { continue }
            try {
                $storeViews[$scope] = @(foreach ($t in @(Invoke-UDPivotTemplateStore -Store $store -Action List -Scope $scope -UserName $user -SourceId $source.id)) {
                        [pscustomobject]@{ name = $t.Name; view = $t.View; scope = $scope; deletable = ($scope -eq 'user' -or $isAdmin) }
                    })
            }
            catch { Write-Warning ('Pivot template store ({0} views) left out: {1}' -f $scope, $_.Exception.Message) }
        }
    }
    # a shared view of the store takes the place of the -TemplatePath files of its name: Publish and Save
    # write a name the files have into the store, and the Views menu must show that change. Names match
    # as in pivotkit's Views menu and the store's upsert (same characters, same case).
    $replaced = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    if ($TemplatePath) {
        foreach ($t in @(Get-UDPivotTemplateFile -Path $TemplatePath)) {
            $fromStore = @($storeViews['shared'] | Where-Object { $_.name -ceq $t.Name })
            if (-not $fromStore.Count) { $templateList.Add([pscustomobject]@{ name = $t.Name; view = $t.View; scope = 'shared'; deletable = $false }) }
            elseif ($replaced.Add($t.Name)) { $templateList.AddRange([object[]]$fromStore) }
        }
    }
    foreach ($t in @($storeViews['shared'] | Where-Object { -not $replaced.Contains($_.name) }) + @($storeViews['user'])) { $templateList.Add($t) }
    if ($store) {
        $settings = @{
            App        = [string]$PSCmdlet.SessionState.PSVariable.GetValue('DashboardName')
            Report     = $storageKey
            Store      = $store
            AdminRole  = @($AdminRole)
            SourceId   = $source.id
            SourceName = [string]$source['name']
            SchemaUrl  = if ($PSBoundParameters.ContainsKey('SchemaUrl')) { $SchemaUrl } else { $Script:ViewFileSchemaUrl }
        }
        $key = Register-UDPivotTemplateStore -Settings $settings
        # without a signed-in user the server cannot tell readers apart: their own views stay in the browser
        if ($user) {
            $OnSaveTemplate = New-UDPivotTemplateEndpoint -Key $key -Action Save
            $OnDeleteTemplate = New-UDPivotTemplateEndpoint -Key $key -Action Delete
        }
        else {
            $props['templateStore'] = 'browser'
            if ($isAdmin) { $OnDeleteTemplate = New-UDPivotTemplateEndpoint -Key $key -Action Delete }
        }
        if ($isAdmin) { $OnPublishTemplate = New-UDPivotTemplateEndpoint -Key $key -Action Publish }
    }
    elseif ($TemplateStore -eq 'Browser') {
        $props['templateStore'] = 'browser'
    }
    if ($templateList.Count -gt $Script:MaxTemplates) {
        Write-Warning ('Pivot templates: {0}, more than the {1} the report takes; the rest is left out.' -f $templateList.Count, $Script:MaxTemplates)
        $templateList.RemoveRange($Script:MaxTemplates, $templateList.Count - $Script:MaxTemplates)
    }
    if ($PSBoundParameters.ContainsKey('Templates') -or $TemplatePath -or $store) { $props['templates'] = $templateList.ToArray() }
    if ($isAdmin -and ($OnPublishTemplate)) { $props['canPublish'] = $true }
    #endregion
    if ($FieldDefaults -or $FieldDescriptions) {
        $defaults = ConvertTo-UDPivotFieldDefault -FieldDefaults $FieldDefaults -FieldDescriptions $FieldDescriptions
        # as JSON text: PSU would camelCase the field names of an object prop
        if ($defaults.Count) {
            $props['fieldDefaults'] = ConvertTo-UDPivotJsonText -InputObject $defaults -Name '-FieldDefaults' -MaxLength $Script:MaxSchemaLength -MaxDepth 4
        }
    }
    if ($PSBoundParameters.ContainsKey('Schema') -and $null -ne $Schema) {
        $props['schema'] = Get-UDPivotSchemaText -Schema $Schema
        if ($SchemaName) { $props['schemaName'] = $SchemaName }
    }
    elseif ($SchemaName) { throw '-SchemaName needs -Schema.' }
    if ($PSBoundParameters.ContainsKey('ChartOptions') -and $null -ne $ChartOptions) {
        $props['chartOptions'] = ConvertTo-UDPivotJsonText -InputObject $ChartOptions -Name '-ChartOptions' -MaxLength $Script:MaxChartOptionsLength -MaxDepth $Script:MaxChartOptionsDepth
    }
    if ($Tips) {
        if ($Tips.Count -gt 1 -and ($Tips -contains 'On' -or $Tips -contains 'Off')) { throw '-Tips: On or Off alone, or a list of tip ids.' }
        $props['tips'] = if ($Tips.Count -eq 1 -and $Tips[0] -in 'On', 'Off') { $Tips[0].ToLowerInvariant() } else { @($Tips) }
    }
    if ($FieldInfo) { $props['fieldInfo'] = $FieldInfo.ToLowerInvariant() }
    if ($ZoneInfo) { $props['zoneInfo'] = $ZoneInfo.ToLowerInvariant() }
    if ($SettingInfo) { $props['settingInfo'] = $SettingInfo.ToLowerInvariant() }
    if ($FieldList) { $props['fieldList'] = $FieldList.ToLowerInvariant() }
    if ($Grow) { $props['grow'] = $Grow.ToLowerInvariant() }
    if ($Label) { $props['label'] = $Label }
    if ($Height) { $props['height'] = ConvertTo-UDPivotHeight -Height $Height }
    if ($Labels) { $props['labels'] = $Labels }
    if ($ClassName) { $props['className'] = $ClassName }
    if ($Style) { $props['style'] = $Style }
    $events = [ordered]@{ OnViewChange = 'onViewChange'; OnCellClick = 'onCellClick'; OnSaveTemplate = 'onSaveTemplate'; OnDeleteTemplate = 'onDeleteTemplate'; OnPublishTemplate = 'onPublishTemplate' }
    foreach ($name in $events.Keys) {
        # a parameter, or a handler of the template store above
        $endpoint = Get-Variable -Name $name -ValueOnly -Scope 0
        if ($endpoint) {
            # one registration per event: endpoints registered under the same id replace each other
            $endpoint.Register(('{0}-{1}' -f $Id, $events[$name]), $PSCmdlet)
            $props[$events[$name]] = $endpoint
        }
    }
    if ($isAdmin) {
        # the admin panel under the report: how long the server took for this report, and the size
        $props['admin'] = [pscustomobject]@{
            rows      = @($rows).Count
            columns   = $columnNames.Count
            convertMs = [math]::Round($convertMs, 1)
            serverMs  = [math]::Round($timer.Elapsed.TotalMilliseconds, 1)
            templates = $templateList.Count
            store     = if ($store) { $store.Kind } elseif ($props['templateStore']) { 'Browser' } else { $null }
        }
    }
    $props
}

function New-UDPivotReportPlaceholder {
    <#
    .SYNOPSIS
        A placeholder in the pivot report's own look, for New-UDDynamic -LoadingComponent: it shows the
        report's frame while the server builds the data.
    .DESCRIPTION
        PSU renders a component only once its properties have arrived, and the report's properties hold
        all of its rows: with thousands of rows the page stays empty until the server has converted and
        sent them. Put the report into New-UDDynamic and this placeholder into its -LoadingComponent:

            New-UDDynamic -Id 'tickets-report' -LoadingComponent {
                New-UDPivotReportPlaceholder -Height 640px
            } -Content {
                New-UDPivotReport -Id 'tickets' -Data $tickets -Height 640px
            }

        The placeholder comes with the page and shows pivotkit's own skeleton of the report: the field
        list, the toolbar, the zones and table rows as grey bars, in the report's colours (light, dark, a
        corporate design from the app's stylesheet); the bars pulse unless the reader asked for reduced
        motion. Screen readers hear "Loading the report". It also makes the browser load the module's code at
        once, while the server is still working on the data.

        Give it the -Height, -Theme, -Locale and -Label of the report, so nothing moves when the report
        replaces it.
    .PARAMETER Id
        Component id. Default: a new GUID.
    .PARAMETER Height
        Height, as -Height of New-UDPivotReport (e.g. 640px, 80vh or 640). Default: the report's default
        height.
    .PARAMETER Theme
        Auto (follows the app's light/dark switch, default), Light or Dark.
    .PARAMETER Locale
        The language of the text screen readers hear: German for de-*, English otherwise. Default: en-US.
    .PARAMETER Label
        The name screen readers hear for it, as -Label of the report.
    .PARAMETER ClassName
        CSS class of the outer element.
    .PARAMETER Style
        CSS styles of the outer element, e.g. @{ maxWidth = '1200px' }.
    .EXAMPLE
        New-UDDynamic -Id 'tickets-report' -LoadingComponent { New-UDPivotReportPlaceholder } -Content {
            New-UDPivotReport -Id 'tickets' -Data (Invoke-Sqlcmd -Query 'SELECT * FROM Tickets')
        }
    .EXAMPLE
        New-UDDynamic -LoadingComponent { New-UDPivotReportPlaceholder -Height 560px -Locale de-DE } -Content {
            New-UDPivotReport -Data $tickets -Height 560px -Locale de-DE
        }
    .OUTPUTS
        System.Collections.Hashtable
    .LINK
        https://powershell-universal-components.eize.dev/pivot/
    #>
    # describes a component for PSU to render; changes no state, so no ShouldProcess
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string]$Id = [guid]::NewGuid().ToString(),
        [ValidateScript({ $_ -match $Script:HeightPattern }, ErrorMessage = 'Height "{0}": expected a CSS length such as 640px, 80vh or 640.')][string]$Height,
        [ValidateSet('Auto', 'Light', 'Dark')][string]$Theme = 'Auto',
        [ValidateScript({ $_ -match $Script:LocalePattern }, ErrorMessage = 'Locale "{0}": expected a language tag such as en-US or de-DE.')][string]$Locale = 'en-US',
        [ValidateLength(1, 120)][string]$Label,
        [string]$ClassName,
        [hashtable]$Style
    )

    if (-not $Script:AssetId) { throw $Script:MissingAssetMessage }
    $props = @{
        assetId  = $Script:AssetId
        isPlugin = $true
        type     = 'ud-pivot-placeholder'
        id       = $Id
        theme    = $Theme.ToLowerInvariant()
        locale   = $Locale
    }
    if ($Height) { $props['height'] = ConvertTo-UDPivotHeight -Height $Height }
    if ($Label) { $props['label'] = $Label }
    if ($ClassName) { $props['className'] = $ClassName }
    if ($Style) { $props['style'] = $Style }
    $props
}

function Get-UDPivotSqlColumnDescription {
    <#
    .SYNOPSIS
        The column descriptions of a SQL Server table or view (extended property MS_Description), as the
        hashtable -FieldDescriptions of New-UDPivotReport takes.
    .DESCRIPTION
        Reads sys.extended_properties for the columns of one table or view (class 1, major_id the object,
        minor_id the column) with the property name MS_Description - what SQL Server Management Studio
        writes as a column's Description - and returns column name to text, in column order. Columns
        without a description are left out.

        Pass an open connection (-Connection: System.Data.SqlClient, Microsoft.Data.SqlClient or any
        ADO.NET connection to SQL Server; it stays open) or a connection string (-ConnectionString: the
        function opens and closes a connection with Microsoft.Data.SqlClient when that is loaded, for
        example by the SqlServer module, else with System.Data.SqlClient, which PowerShell 7 ships).
        The table name goes to SQL Server as a parameter of OBJECT_ID(), never into the query text. The
        account sees only the descriptions of objects it has permissions on; an unknown table gives an
        empty result.
    .PARAMETER Connection
        An open ADO.NET connection to the database that holds the table.
    .PARAMETER ConnectionString
        A connection string to the database that holds the table.
    .PARAMETER Table
        The table or view, as OBJECT_ID() takes it: dbo.Tickets, [sales].[Order Lines] or Tickets
        (the user's default schema).
    .PARAMETER PropertyName
        The extended property to read. Default: MS_Description.
    .PARAMETER TimeoutSec
        Command timeout in seconds. Default: 30.
    .EXAMPLE
        $descriptions = Get-UDPivotSqlColumnDescription -ConnectionString $connectionString -Table 'dbo.Tickets'
        New-UDPivotReport -Id 'tickets' -Data $tickets -FieldDescriptions $descriptions
    .EXAMPLE
        $connection = [System.Data.SqlClient.SqlConnection]::new($connectionString)
        $connection.Open()
        try { $descriptions = Get-UDPivotSqlColumnDescription -Connection $connection -Table '[sales].[Orders]' }
        finally { $connection.Dispose() }
    .OUTPUTS
        System.Collections.Specialized.OrderedDictionary
    .LINK
        https://powershell-universal-components.eize.dev/pivot/fields/
    #>
    [CmdletBinding(DefaultParameterSetName = 'ConnectionString')]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Connection')][System.Data.IDbConnection]$Connection,
        [Parameter(Mandatory, ParameterSetName = 'ConnectionString')][ValidateNotNullOrEmpty()][string]$ConnectionString,
        [Parameter(Mandatory)][ValidateLength(1, 776)][string]$Table,
        [ValidateLength(1, 128)][string]$PropertyName = 'MS_Description',
        [ValidateRange(1, 3600)][int]$TimeoutSec = 30
    )

    $own = $PSCmdlet.ParameterSetName -eq 'ConnectionString'
    if ($own) {
        $type = 'Microsoft.Data.SqlClient.SqlConnection' -as [type]
        if (-not $type) { $type = 'System.Data.SqlClient.SqlConnection' -as [type] }
        if (-not $type) { throw 'Get-UDPivotSqlColumnDescription: no SQL Server client (Microsoft.Data.SqlClient or System.Data.SqlClient) is loaded; pass an open connection with -Connection.' }
        $Connection = $type::new($ConnectionString)
    }
    try {
        if ($own) { $Connection.Open() }
        $command = $Connection.CreateCommand()
        try {
            $command.CommandTimeout = $TimeoutSec
            $command.CommandText = $Script:SqlColumnDescriptionQuery
            foreach ($parameter in @{ '@Table' = $Table; '@Name' = $PropertyName }.GetEnumerator()) {
                $p = $command.CreateParameter()
                $p.ParameterName = $parameter.Key
                $p.DbType = [System.Data.DbType]::String
                $p.Value = $parameter.Value
                [void]$command.Parameters.Add($p)
            }
            $result = [ordered]@{}
            $reader = $command.ExecuteReader()
            try {
                while ($reader.Read()) {
                    if ($reader.IsDBNull(1)) { continue }
                    $text = [string]$reader.GetValue(1)
                    if (-not [string]::IsNullOrWhiteSpace($text)) { $result[[string]$reader.GetValue(0)] = $text }
                }
            }
            finally {
                $reader.Dispose()
            }
            $result
        }
        finally {
            $command.Dispose()
        }
    }
    finally {
        if ($own) { $Connection.Dispose() }
    }
}

Export-ModuleMember -Function New-UDPivotReport, New-UDPivotReportPlaceholder, ConvertFrom-UDPivotView, ConvertFrom-UDPivotViewFile, ConvertTo-UDPivotViewFile, New-UDPivotFileTemplateStore, New-UDPivotTemplateStore, Invoke-UDPivotTemplateRequest, Get-UDPivotSqlColumnDescription
