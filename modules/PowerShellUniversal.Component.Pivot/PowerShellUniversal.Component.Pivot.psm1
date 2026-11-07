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
        Checks the entries of -Templates and returns them as name, view and deletable.
    .DESCRIPTION
        Used by New-UDPivotReport. An entry is a hashtable or an object with Name (text, at most 200
        characters), View (as ConvertFrom-UDPivotView accepts it) and optionally Deletable. A wrong entry
        throws an error that names it.
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
        $get = {
            param($Name)
            if ($entry -is [System.Collections.IDictionary]) {
                foreach ($key in $entry.Keys) { if ([string]$key -eq $Name) { return $entry[$key] } }
                return $null
            }
            $property = $entry.PSObject.Properties[$Name]
            if ($property) { $property.Value }
        }
        $name = & $get 'Name'
        if ($name -isnot [string] -or [string]::IsNullOrWhiteSpace($name) -or $name.Length -gt 200) {
            throw ('-Templates, entry {0}: Name must be text of 1 to 200 characters.' -f $index)
        }
        try {
            $view = ConvertFrom-UDPivotView -InputObject (& $get 'View')
        }
        catch {
            throw ('-Templates, "{0}": {1}' -f $name, $_.Exception.Message)
        }
        [pscustomobject]@{ name = $name; view = $view; deletable = [bool](& $get 'Deletable') }
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
        runs as code. -View sets the start view, -Templates the views offered in the Templates menu,
        -OnSaveTemplate and -OnDeleteTemplate let readers keep their own (the app decides where: see
        the example app and ConvertFrom-UDPivotView). Field names are matched without regard to case.
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
        Views offered in the Templates menu (the first three also on the empty report): a list of
        @{ Name = 'Tickets per team'; View = <view>; Deletable = $false }. Deletable entries get a delete
        button when -OnDeleteTemplate is set.
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
        tips allowed (filterEmpty, top, chartCapped, showAs, chartDates, chartTrend, chartSeries,
        textValue, dateUngrouped, manyColumns, values, afterDrag, saveTemplate, menus, cells). Dismissed
        tips are remembered per report in the browser's localStorage.
    .PARAMETER FieldInfo
        On or Off: the "i" with the field descriptions. Without it the reader switches it in Options.
    .PARAMETER ZoneInfo
        On or Off: the "i" next to the zone titles that explains each zone. Without it the reader
        switches it in Options.
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
        it. Default: the window's height minus the app bar and a page title, between 480 and 1400 pixels;
        in a window narrower than 640 pixels (a phone) almost the whole window, since the zones stack
        above the table there.
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
        Shows "Save current view" in the Templates menu and runs when the reader saves. $EventData: name,
        view, json. The template appears in the menu (deletable) once the script block finished without
        an error; throw, or return @{ error = 'message' }, to refuse - the reader sees the message.
    .PARAMETER OnDeleteTemplate
        Runs when the reader deletes a deletable template (after confirming in the menu). $EventData:
        name. Throw, or return @{ error = 'message' }, to refuse.
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
        [System.Collections.IDictionary]$FieldDefaults,
        [System.Collections.IDictionary]$FieldDescriptions,
        [object]$Schema,
        [ValidateLength(1, 200)][string]$SchemaName,
        [object]$ChartOptions,
        [ValidateScript({ $_ -match $Script:TipPattern }, ErrorMessage = 'Tips "{0}": expected On, Off or tip ids such as values or chartSeries.')][string[]]$Tips,
        [ValidateSet('On', 'Off')][string]$FieldInfo,
        [ValidateSet('On', 'Off')][string]$ZoneInfo,
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
        [Endpoint]$OnDeleteTemplate
    )

    if (-not $Script:AssetId) { throw $Script:MissingAssetMessage }

    # one array (ConvertTo-PSUComponentData returns it as a single object; @() would nest it)
    $rows = ConvertTo-PSUComponentData -InputObject $Data
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
    if ($PSBoundParameters.ContainsKey('Templates')) { $props['templates'] = @(ConvertTo-UDPivotTemplate -Template $Templates) }
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
    if ($Label) { $props['label'] = $Label }
    if ($Height) { $props['height'] = ConvertTo-UDPivotHeight -Height $Height }
    if ($Labels) { $props['labels'] = $Labels }
    if ($ClassName) { $props['className'] = $ClassName }
    if ($Style) { $props['style'] = $Style }
    $events = [ordered]@{ OnViewChange = 'onViewChange'; OnCellClick = 'onCellClick'; OnSaveTemplate = 'onSaveTemplate'; OnDeleteTemplate = 'onDeleteTemplate' }
    foreach ($name in $events.Keys) {
        $endpoint = $PSBoundParameters[$name]
        if ($endpoint) {
            # one registration per event: endpoints registered under the same id replace each other
            $endpoint.Register(('{0}-{1}' -f $Id, $events[$name]), $PSCmdlet)
            $props[$events[$name]] = $endpoint
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

Export-ModuleMember -Function New-UDPivotReport, New-UDPivotReportPlaceholder, ConvertFrom-UDPivotView, Get-UDPivotSqlColumnDescription
