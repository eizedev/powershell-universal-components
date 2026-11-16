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

#region Limits of files readers load (-AllowImport)
# the keys of pivotkit-core's LIMITS for a loaded file -ImportLimit may set, with their defaults
# (docs/concepts/limits.md of pivotkit); the report sends them as pivotkit-react's importLimits, merged
# over its limits for a loaded file only. Components/prepare.js keeps the same list (IMPORT_LIMIT_KEYS)
$Script:ImportLimitDefaults = [ordered]@{
    fileBytes      = 104857600
    rows           = 1000000
    columns        = 1000
    importCells    = 10000000
    textLength     = 32767
    archiveEntries = 10000
    unpackedBytes  = 524288000
}
# pivotkit takes whole numbers from 1 up to JavaScript's Number.MAX_SAFE_INTEGER
$Script:MaxImportLimit = 9007199254740991
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
        says what is wrong. Filters pass as they are, of view version 2 (in, blank, text, compare,
        relative, top, value with not and blanks) and of version 1 (include, exclude, label), which the
        report migrates. The report itself checks every field name and setting against the data
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

function ConvertTo-UDPivotImportLimit {
    <#
    .SYNOPSIS
        Checks -ImportLimit and returns it as the report's import limits: pivotkit's key names, whole numbers.
    .DESCRIPTION
        Used by New-UDPivotReport. The keys are pivotkit-core's limits of a loaded file: fileBytes (bytes
        of a file), rows, columns, importCells (rows x columns, a workbook's texts and formats),
        textLength (characters of one value), archiveEntries (parts of a workbook) and unpackedBytes (bytes a workbook unpacks to), matched
        without regard to case and
        returned in pivotkit's spelling and order. Each value is a whole number from 1 to 9007199254740991
        (JavaScript's largest exact integer); 250MB and 2GB are fine. An unknown key, a value that is
        not a whole number or one out of range throws an error that names the key. Keys left out keep
        pivotkit's defaults.
    .PARAMETER ImportLimit
        The limits, e.g. @{ fileBytes = 250MB; rows = 2000000 }.
    .EXAMPLE
        ConvertTo-UDPivotImportLimit -ImportLimit @{ FileBytes = 250MB; rows = 2000000 }
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$ImportLimit)
    $limits = [ordered]@{}
    foreach ($key in $ImportLimit.Keys) {
        $name = $Script:ImportLimitDefaults.Keys | Where-Object { $_ -eq [string]$key } | Select-Object -First 1
        if (-not $name) {
            throw ('-ImportLimit: unknown limit "{0}"; known are {1}.' -f $key, ($Script:ImportLimitDefaults.Keys -join ', '))
        }
        if ($limits.Contains($name)) { throw ('-ImportLimit: {0} is given twice.' -f $name) }
        $value = $ImportLimit[$key]
        $isNumber = $value -is [int] -or $value -is [long] -or $value -is [double] -or $value -is [decimal] -or $value -is [single]
        if (-not $isNumber -or $value -ne [math]::Truncate($value) -or $value -lt 1 -or $value -gt $Script:MaxImportLimit) {
            throw ('-ImportLimit: {0} must be a whole number from 1 to {1}, not "{2}".' -f $name, $Script:MaxImportLimit, $value)
        }
        $limits[$name] = [long]$value
    }
    # in pivotkit's order, whatever order the hashtable had
    $ordered = [ordered]@{}
    foreach ($name in $Script:ImportLimitDefaults.Keys) { if ($limits.Contains($name)) { $ordered[$name] = $limits[$name] } }
    [pscustomobject]$ordered
}

function ConvertTo-UDPivotExportData {
    <#
    .SYNOPSIS
        -ExportData and -ExportDataColumn as pivotkit-react's exportData: $true, or @{ columns } with the
        names as the data spells them.
    .DESCRIPTION
        Every name in -Column must be a column of the data (without regard to case), each once: an
        unknown name throws and names it, so a typo never turns into an export of every column. Data
        without rows (-AllowImport with an empty -Data) has no columns to check against; the names go
        to pivotkit as given, which offers nothing for a name that matches no column.
    .PARAMETER Column
        The columns of -ExportDataColumn, or none for every column.
    .PARAMETER ColumnName
        The columns of the data.
    .EXAMPLE
        ConvertTo-UDPivotExportData -Column 'team', 'Hours' -ColumnName 'Team', 'Hours', 'Customer'
    .OUTPUTS
        System.Boolean or System.Collections.Hashtable
    #>
    [CmdletBinding()]
    [OutputType([bool], [hashtable])]
    param(
        [AllowNull()][AllowEmptyCollection()][string[]]$Column,
        [AllowNull()][AllowEmptyCollection()][string[]]$ColumnName
    )
    if (-not $Column) { return $true }
    $known = @($ColumnName | Where-Object { $_ })
    $picked = [System.Collections.Generic.List[string]]::new()
    $unknown = [System.Collections.Generic.List[string]]::new()
    foreach ($name in $Column) {
        $match = if ($known.Count) { $known | Where-Object { $_ -eq $name } | Select-Object -First 1 } else { $name }
        if ($null -eq $match) { $unknown.Add($name) }
        elseif (-not ($picked | Where-Object { $_ -eq $match })) { $picked.Add($match) }
    }
    if ($unknown.Count) {
        throw ('-ExportDataColumn: {0} {1} no column of -Data (columns: {2}).' -f (($unknown | ForEach-Object { '"{0}"' -f $_ }) -join ', '), $(if ($unknown.Count -eq 1) { 'is' } else { 'are' }), ($known -join ', '))
    }
    # an array, also for one name: pivotkit turns everything off for columns that are no list
    @{ columns = [string[]]$picked.ToArray() }
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
# pivotkit's view file (pivotkit-core's VIEW_FILE_LIMITS, VIEW_FILE_SCHEMA, VIEW_VERSION): format version
# 2 carries views of version 2, format 1 views of version 1; both are read, and a view without a version
# is version 1 (pivotkit migrates it to version 2 when it reads it)
$Script:ViewFileFormat = 'pivotkit-view'
$Script:ViewFileSchemaUrls = @{
    1 = 'https://pivotkit.eize.dev/schema/view-file-1.json'
    2 = 'https://pivotkit.eize.dev/schema/view-file-2.json'
}
$Script:KnownViewFileVersions = @(1, 2)
$Script:MaxViewFileLength = 1000000
$Script:MaxViewFileDepth = 16
$Script:MaxViewFileDescription = 2000
$Script:KnownViewVersion = 2
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
        template store keeps: format "pivotkit-view", formatVersion 1 or 2, name, description, source and
        the view. This function reads one as untrusted input: at most 1,000,000 characters and 16 levels,
        parsed without evaluating anything; a newer formatVersion or view version (above 2) is refused
        (saving it again would lose what the newer version added); a view of version 1 is read as it is
        and migrated to version 2 by the report; the name becomes plain text of 1 to 120
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
            $newest = ($Script:KnownViewFileVersions | Measure-Object -Maximum).Maximum
            if ($null -ne $version -and -not (($version -is [int] -or $version -is [long]) -and $version -in $Script:KnownViewFileVersions)) {
                if (($version -is [int] -or $version -is [long] -or $version -is [double] -or $version -is [decimal]) -and $version -gt $newest) {
                    throw ('View file: format version {0} is newer than this module reads ({1}); update PowerShellUniversal.Component.Pivot.' -f $version, $newest)
                }
                throw ('View file: formatVersion must be one of {0}.' -f ($Script:KnownViewFileVersions -join ', '))
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
        view) with a two-space indent and a trailing newline. The format version follows the view: 2 for
        a view of version 2 (what the report sends), 1 for a view of version 1 or without a version, so
        a pivotkit that reads only format 1 still loads the file of an older view.
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
        The $schema of the file: by default pivotkit's schema of the format version written
        (view-file-2.json or view-file-1.json), else your own copy, or '' to leave it out.
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
        [AllowEmptyString()][string]$SchemaUrl,
        [Nullable[datetime]]$CreatedAt
    )
    $checked = ConvertFrom-UDPivotView -InputObject $View
    $viewVersion = $checked.PSObject.Properties['version'].Value
    if ($null -ne $viewVersion -and ($viewVersion -ne [math]::Truncate($viewVersion) -or $viewVersion -lt 1 -or $viewVersion -gt $Script:KnownViewVersion)) {
        # the number as written, whatever the culture of the thread (1.5, not 1,5)
        throw ([string]::Format([cultureinfo]::InvariantCulture, 'View file: view version {0} is not one this module writes (1 to {1}).', $viewVersion, $Script:KnownViewVersion))
    }
    $formatVersion = if ($null -ne $viewVersion -and $viewVersion -ge 2) { 2 } else { 1 }
    if (-not $PSBoundParameters.ContainsKey('SchemaUrl')) { $SchemaUrl = $Script:ViewFileSchemaUrls[$formatVersion] }
    $file = [ordered]@{}
    if ($SchemaUrl) { $file['$schema'] = $SchemaUrl }
    $file['format'] = $Script:ViewFileFormat
    $file['formatVersion'] = $formatVersion
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
        The $schema of the view file; without it pivotkit's schema of the format version written.
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
        [AllowEmptyString()][string]$SchemaUrl
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
    # -SchemaUrl only when given: ConvertTo-UDPivotViewFile picks pivotkit's schema of the format otherwise
    $viewFile = @{ SourceName = $SourceName; Schema = @{} }
    if ($PSBoundParameters.ContainsKey('SchemaUrl')) { $viewFile.Schema['SchemaUrl'] = $SchemaUrl }
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
        $schemaArgument = $viewFile.Schema
        $json = ConvertTo-UDPivotViewFile -View $checkedView -Name $checkedName -SourceId $fileSource -SourceName $(if ($fileSource) { $viewFile.SourceName }) -CreatedAt ([datetime]::UtcNow) @schemaArgument

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
        }
        # $null: pivotkit's schema of the format the view file is written in
        if ($null -ne $settings.SchemaUrl) { $arguments['SchemaUrl'] = $settings.SchemaUrl }
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
        undo and redo, templates, Excel (XLSX), CSV, PNG, SVG and HTML export and print. All of it runs in the browser
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
        Keys: version (2), rows, cols (field names), values (field, agg: sum, count, average, min, max,
        ...; format: a format name), filters (e.g. @{ field = 'Status'; type = 'in'; items = @('Open');
        blanks = 'exclude' }; a view without version is read as version 1 and migrated), sort, totals,
        display (table or chart), chart (type: bar, line, area, pie, heatmap). A saved template's view
        goes in as it is. Default: an empty report with the hint where to start. A view in the address bar (#pivot-<id>=..., written by the report on every
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
        Where readers keep their own views ("My views") and admins the shared ones; views of a file loaded
        with -AllowImport always stay in the browser. Folder and file names of the stores:
        https://powershell-universal-components.eize.dev/pivot/templates/#ids Without it nothing is
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
        otherwise the views made for all of its data show together. A file the reader loads with
        -AllowImport needs none: pivotkit names its data itself and keeps its views in the browser. How
        the ids are built: https://powershell-universal-components.eize.dev/pivot/templates/#ids
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
        tips allowed (showAs, colSubtotals, chartOverTime, pieSlices, pieColumns, chartDates, chartTrend, chartSeries,
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
    .PARAMETER ExportData
        Adds Source data to the Export menu: every row of the data, before filters, grouping and totals,
        as a CSV or JSON file (pivotkit's exportData). Off by default. The report and its drill-down
        hand out different things: the report's own exports (Excel, Table as CSV, HTML, Print) hold the
        result the reader sees; the drill-down hands out up to 1,000 rows behind a clicked value, with
        every column, unless -NoDrillDown; Source data hands out every row and every column of -Data,
        also the columns no view places and the rows the filters leave out. All of these are rows the
        browser already holds (its developer tools reach them), so turn it on only where readers may take
        every row home, and select the columns first. With -AllowImport a loaded file's rows are exported
        too. https://pivotkit.eize.dev/security/#source-data
    .PARAMETER ExportDataColumn
        With -ExportData: only these columns, in this order, in Source data and in the drill-down panel's
        copies and files (the panel itself still shows every column). Names are matched without regard to
        case against the columns of the first row of -Data; a name that is no column is an error, so a
        typo never widens the export. It is no access control: the field list, the drill-down panel, the
        exports of the result and $EventData.rows still carry every column. Remove a column readers must
        not have before -Data (Select-Object -ExcludeProperty, the SQL query).
    .PARAMETER AllowImport
        Readers may load a file of their own into the report: a Data menu in the toolbar, a file dropped
        onto the report, and a preview (first rows, a type per column, a sheet of a workbook) before the
        data is replaced. CSV, TSV, text, JSON and Excel workbooks (.xlsx) are read in the browser;
        nothing is uploaded, and after a reload the app's data is back. While a file's data is shown,
        its view stays in the browser (the address bar, -SavedView, Get-UDElement and -OnViewChange keep
        the app's data), -OnCellClick does not run, and views the reader saves go to the browser's store
        per file (pivotkit names the file's data by its name and a hash of its column names), never to
        -TemplateStore or -OnSaveTemplate. PSU's light/dark switch and Sync-UDElement keep the file shown
        (in the page's memory, per report). -Data may be empty: the report then asks for a file.
    .PARAMETER ImportLimit
        Raises or lowers pivotkit's limits for a file loaded with -AllowImport (pivotkit-react's
        importLimits): a hashtable of fileBytes (bytes of a file, default 100 MiB), rows (default
        1,000,000), columns (default 1,000), importCells (rows x columns, and a workbook's different
        texts and cell formats; default 10,000,000),
        textLength (characters of one value, longer text is cut; default 32,767), archiveEntries (parts
        of an Excel workbook, default 10,000) and unpackedBytes (bytes a workbook unpacks to, default
        500 MiB), e.g. @{ fileBytes = 250MB; rows = 2000000 }. Needs -AllowImport. Keys left out keep
        pivotkit's defaults; an unknown key or a value that is not a whole number of at least 1 is an
        error that names it. Only a loaded file gets these limits; -Data keeps pivotkit's. A file over
        a limit is refused in the browser with a message that names it; larger limits cost the reader's
        browser memory (about 650 MB more for a CSV of 1,000,000 rows and 5 columns in pivotkit's
        measurement).
    .PARAMETER OnDataLoad
        With -AllowImport: runs on the server after the data shown changed. It only reports; it cannot
        refuse a file. $EventData: cause (load, original, undo, redo, restore), source (id, name), file (name,
        size, type; $null for the app's data), sheet, rows, columnCount, columns (the first 200, name and
        type) and notes (the codes of the readers' notes). Never a value of the file; the names come from
        the reader's file, so show them as text.
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
        # readers pivot a CSV, JSON or Excel file of their own, read in the browser; their views are kept per file
        New-UDPivotReport -Id 'own-data' -Data @() -AllowImport -TemplateStore Browser -OnDataLoad {
            if ($EventData.file) { Write-Information ('{0} loaded: {1} rows' -f $EventData.file.name, $EventData.rows) }
        }
    .EXAMPLE
        # files of up to 250 MB and 2,000,000 rows; the other limits stay pivotkit's
        New-UDPivotReport -Id 'own-data' -Data @() -AllowImport -ImportLimit @{ fileBytes = 250MB; rows = 2000000 }
    .EXAMPLE
        # readers may download the rows behind the report, without the customer column
        New-UDPivotReport -Id 'tickets' -Data $tickets -ExportData -ExportDataColumn 'Id', 'Team', 'Created', 'LeadHours'
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
        [switch]$ExportData,
        [ValidateNotNullOrEmpty()][string[]]$ExportDataColumn,
        [switch]$AllowImport,
        [System.Collections.IDictionary]$ImportLimit,
        [string]$ClassName,
        [hashtable]$Style,
        [Endpoint]$OnViewChange,
        [Endpoint]$OnCellClick,
        [Endpoint]$OnSaveTemplate,
        [Endpoint]$OnDeleteTemplate,
        [Endpoint]$OnPublishTemplate,
        [Endpoint]$OnDataLoad
    )

    if (-not $Script:AssetId) { throw $Script:MissingAssetMessage }
    if ($OnDataLoad -and -not $AllowImport) { throw '-OnDataLoad needs -AllowImport: without it the data shown never changes.' }
    if ($PSBoundParameters.ContainsKey('ImportLimit') -and -not $AllowImport) { throw '-ImportLimit needs -AllowImport: without it no file is loaded.' }
    if ($ExportDataColumn -and -not $ExportData) { throw '-ExportDataColumn needs -ExportData: naming columns never turns an export on by itself.' }
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
    if ($ExportData) { $props['exportData'] = ConvertTo-UDPivotExportData -Column $ExportDataColumn -ColumnName $columnNames }
    if ($AllowImport) { $props['allowImport'] = $true }
    if ($PSBoundParameters.ContainsKey('ImportLimit') -and $null -ne $ImportLimit) {
        $limits = ConvertTo-UDPivotImportLimit -ImportLimit $ImportLimit
        if (@($limits.PSObject.Properties).Count) { $props['importLimits'] = $limits }
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
    # the views the app ships: -Templates, then the -TemplatePath files made for this report's data or
    # for no data (as the store and pivotkit's browser store list them, ids compared with case)
    $shipped = [System.Collections.Generic.List[object]]::new()
    if ($PSBoundParameters.ContainsKey('Templates')) { foreach ($t in @(ConvertTo-UDPivotTemplate -Template $Templates)) { $shipped.Add($t) } }
    if ($TemplatePath) {
        foreach ($t in @(Get-UDPivotTemplateFile -Path $TemplatePath)) {
            if ($t.SourceId -and $t.SourceId -cne $source.id) { continue }
            $shipped.Add([pscustomobject]@{ name = $t.Name; view = $t.View; scope = 'shared'; deletable = $false })
        }
    }
    # a shared view of the store takes the place of a shipped shared view of its name: Publish and Save
    # write a name the app ships into the store, and the Views menu must show that change. Names match
    # as in pivotkit's Views menu and the store's upsert (same characters, same case).
    $replaced = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($t in $shipped) {
        $fromStore = if ($t.scope -eq 'shared') { @($storeViews['shared'] | Where-Object { $_.name -ceq $t.name }) } else { @() }
        if (-not $fromStore.Count) { $templateList.Add($t) }
        elseif ($replaced.Add($t.name)) { $templateList.AddRange([object[]]$fromStore) }
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
            SchemaUrl  = if ($PSBoundParameters.ContainsKey('SchemaUrl')) { $SchemaUrl } else { $null }
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
    $events = [ordered]@{ OnViewChange = 'onViewChange'; OnCellClick = 'onCellClick'; OnSaveTemplate = 'onSaveTemplate'; OnDeleteTemplate = 'onDeleteTemplate'; OnPublishTemplate = 'onPublishTemplate'; OnDataLoad = 'onDataLoad' }
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

#region Reports without a browser: Invoke-UDPivotReport
# the formats of pivotkit's render (pivotkit-cli render -f, pivotkit-server render_view format) and the
# file name extensions that name one (.htm is html, as in the command line)
$Script:ReportFormats = @('xlsx', 'html', 'csv', 'json', 'svg')
$Script:ReportExtensions = @{ '.xlsx' = 'xlsx'; '.html' = 'html'; '.htm' = 'html'; '.csv' = 'csv'; '.json' = 'json'; '.svg' = 'svg' }
# the keys of a layout (pivotkit-core's viewFromLayout input; RenderViewInput.layout of the REST service)
$Script:LayoutKeys = @('rows', 'cols', 'values', 'groups', 'filters', 'chart', 'map')
$Script:ReportTimeoutSec = 120
# a request body above this gets a warning: pivotkit-server's default rest.data.maxBytes
$Script:ReportDataWarnBytes = 10MB
# Rows into JSON without a PowerShell statement per cell: in PowerShell 100,000 rows x 3 columns
# allocated about 2 GB on the way and took the managed heap of the process up by about 750 MB before the
# garbage collector caught up (measured 2026-11-15, PowerShell 7.6 on macOS; the live test on PSU
# 2026.2.5 saw about 700 MB). Compiled once per process when a table of at least
# $Script:ReportWriterMinRows rows arrives, as ConvertTo-PSUComponentData does; where Add-Type fails,
# PowerShell writes the rows with the same result. The module needs full language mode (it does not load
# in constrained language mode, and the JSON writer is a .NET type that mode blocks).
$Script:ReportWriterSource = @'
using System;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using System.Globalization;
using System.Management.Automation;
using System.Text.Json;
namespace PivotReportTable
{
    public static class Writer_SUFFIX
    {
        // Each row as a JSON array of its values in the columns' order: a DataRow (or DataRowView) by
        // position, anything else by property name. Returns the rows written, or -1 as soon as the
        // writer holds more than maxBytes (0: no cap), checked every 256 rows.
        public static long WriteRows(Utf8JsonWriter writer, string[] columns, IEnumerable rows, long maxBytes, ICollection<string> dropped)
        {
            HashSet<string> known = new HashSet<string>(columns, StringComparer.OrdinalIgnoreCase);
            long count = 0;
            foreach (object item in rows)
            {
                object row = item is PSObject wrapped ? wrapped.BaseObject : item;
                if (row is DataRowView view) row = view.Row;
                // a row deleted but not yet accepted has no values to read (ItemArray throws): left out
                if (row is DataRow gone && (gone.RowState == DataRowState.Deleted || gone.RowState == DataRowState.Detached)) continue;
                writer.WriteStartArray();
                if (row is DataRow dataRow)
                {
                    foreach (object value in dataRow.ItemArray) WriteValue(writer, value);
                }
                else
                {
                    PSObject properties = PSObject.AsPSObject(item);
                    foreach (string column in columns)
                    {
                        PSPropertyInfo property = properties.Properties[column];
                        WriteValue(writer, property == null ? null : property.Value);
                    }
                    foreach (PSPropertyInfo property in properties.Properties)
                    {
                        if (!known.Contains(property.Name)) dropped.Add(property.Name);
                    }
                }
                writer.WriteEndArray();
                count++;
                if (maxBytes > 0 && (count & 255) == 0 && writer.BytesCommitted + writer.BytesPending > maxBytes) return -1;
            }
            return count;
        }

        // whether every row is a PSCustomObject (Select-Object, Invoke-RestMethod, Import-Csv): those are
        // written by property name as they are, without ConvertTo-PSUComponentData's copy of each row
        public static bool AllCustomObjects(IEnumerable rows)
        {
            bool any = false;
            foreach (object item in rows)
            {
                if (!(item is PSObject wrapped) || !(wrapped.BaseObject is PSCustomObject)) return false;
                any = true;
            }
            return any;
        }

        // text, a finite number, true, false or null; dates as ISO 8601 text, TimeSpans as seconds;
        // anything else as PowerShell's [string] makes it (a list joined with spaces, an object as
        // @{x=1; y=z}), so a report says the same whichever writer wrote its rows
        public static void WriteValue(Utf8JsonWriter writer, object value)
        {
            if (value is PSObject wrapped && !(wrapped.BaseObject is PSCustomObject)) value = wrapped.BaseObject;
            switch (value)
            {
                case null: writer.WriteNullValue(); break;
                case DBNull _: writer.WriteNullValue(); break;
                case string text: writer.WriteStringValue(text); break;
                case bool flag: writer.WriteBooleanValue(flag); break;
                case double d: if (double.IsNaN(d) || double.IsInfinity(d)) writer.WriteNullValue(); else writer.WriteNumberValue(d); break;
                case float f: if (float.IsNaN(f) || float.IsInfinity(f)) writer.WriteNullValue(); else writer.WriteNumberValue((double)f); break;
                case int i: writer.WriteNumberValue(i); break;
                case long l: writer.WriteNumberValue(l); break;
                case short s: writer.WriteNumberValue(s); break;
                case byte b: writer.WriteNumberValue(b); break;
                case sbyte sb: writer.WriteNumberValue(sb); break;
                case ushort us: writer.WriteNumberValue(us); break;
                case uint ui: writer.WriteNumberValue(ui); break;
                case ulong ul: writer.WriteNumberValue(ul); break;
                case decimal m: writer.WriteNumberValue(m); break;
                case DateTime date: writer.WriteStringValue(date.ToString("o", CultureInfo.InvariantCulture)); break;
                case DateTimeOffset offset: writer.WriteStringValue(offset.ToString("o", CultureInfo.InvariantCulture)); break;
                case TimeSpan span: writer.WriteNumberValue(span.TotalSeconds); break;
                default: writer.WriteStringValue(LanguagePrimitives.ConvertTo<string>(value) ?? string.Empty); break;
            }
        }
    }
}
'@
$Script:ReportWriterType = & {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $hash = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Script:ReportWriterSource)) } finally { $sha.Dispose() }
    'PivotReportTable.Writer_' + (-join ($hash[0..7] | ForEach-Object { $_.ToString('x2') }))
}
$Script:ReportWriterSource = $Script:ReportWriterSource.Replace('Writer_SUFFIX', ($Script:ReportWriterType -split '\.')[-1])
$Script:ReportWriterMinRows = 1000
$Script:LastTableWriter = $null
# $true: compiled, $false: not available (or switched off by a test), $null: not tried yet
$Script:ReportWriterCompiled = $null
# a token taken from the cache has at least this much time left, so it does not expire on the way
$Script:TokenSkewSec = 60
# OAuth access tokens per token endpoint, client and scope, for this runspace: @{ Token; Expires }
$Script:TokenCache = @{}
# The connection under every request of the REST engine reads the server's answer while the body is
# still being sent. pivotkit-server answers a body over its cap with 413 at once and resets the
# connection while the client still sends (measured with pivotkit c390784b on 2026-11-15: the answer
# after about 600 KB, the reset a few milliseconds later). HttpClient (and Invoke-WebRequest) reads the
# answer only once the body is sent: on a plain connection the write fails with "Error while copying
# content to a stream" and the 413 is lost, also with Expect: 100-continue (node:http sends 100 Continue
# before the answer).
# The stream below keeps reading the socket in the background and, when a write fails after bytes of an
# answer arrived, drops the rest of the body, so HttpClient reads that answer. It sits below TLS and
# a proxy's tunnel, so both work as before. Compiled on first use; where Add-Type fails, the requests go
# through a plain handler and an early answer is lost. Neither is meant for constrained language mode:
# the module needs full language mode (see the row writer above; it does not load in constrained
# language mode), and the REST engine builds HttpClient objects either way.
$Script:HttpTransportSource = @'
using System;
using System.IO;
using System.Net.Http;
using System.Net.Sockets;
using System.Threading;
using System.Threading.Channels;
using System.Threading.Tasks;

namespace PivotReportHttp
{
    public static class Transport_SUFFIX
    {
        private static int activeReaders;

        /// <summary>Background readers still running, for the tests: each ends with its connection.</summary>
        public static int ActiveReaders => Volatile.Read(ref activeReaders);

        /// <summary>The stream a connection of NewHandler uses, over a connected socket (for the tests).</summary>
        public static Stream Open(Socket socket) => new ReadAheadStream(socket);

        /// <summary>A handler without redirects or cookies whose connections keep an early answer.</summary>
        public static SocketsHttpHandler NewHandler()
        {
            var handler = new SocketsHttpHandler
            {
                AllowAutoRedirect = false,
                UseCookies = false,
                AutomaticDecompression = System.Net.DecompressionMethods.All
            };
            handler.ConnectCallback = async (context, cancel) =>
            {
                var socket = new Socket(SocketType.Stream, ProtocolType.Tcp) { NoDelay = true };
                try
                {
                    await socket.ConnectAsync(context.DnsEndPoint, cancel).ConfigureAwait(false);
                    return new ReadAheadStream(socket);
                }
                catch
                {
                    socket.Dispose();
                    throw;
                }
            };
            return handler;
        }

        private sealed class ReadAheadStream : Stream
        {
            // how long a failed write waits for the answer that may have caused it
            private const int AnswerWaitMs = 2000;
            private readonly NetworkStream inner;
            // at most 256 reads of 16 KiB ahead of the reader
            private readonly Channel<byte[]> received = Channel.CreateBounded<byte[]>(new BoundedChannelOptions(256) { SingleReader = true, SingleWriter = true });
            private byte[] current = Array.Empty<byte>();
            private int offset;
            // bytes received and not read yet
            private long unread;
            private volatile bool ended;
            // set once a write failed after the server had started to answer: the rest of the body is
            // dropped on purpose, without an error, so the request goes on to read that answer (a 413
            // for a body over the cap). Any byte received counts as the start of an answer, as the
            // request is sent without Expect: 100-continue
            private volatile bool dropping;
            // ends the background reader's wait for room in the buffer when the stream is disposed
            private readonly CancellationTokenSource closing = new CancellationTokenSource();
            // 1 once disposed: a stream may be disposed more than once (HttpClient and its connection)
            private int disposed;

            public ReadAheadStream(Socket socket)
            {
                inner = new NetworkStream(socket, ownsSocket: true);
                _ = PumpAsync();
            }

            private async Task PumpAsync()
            {
                var buffer = new byte[16384];
                Interlocked.Increment(ref activeReaders);
                try
                {
                    while (true)
                    {
                        int n = await inner.ReadAsync(buffer.AsMemory()).ConfigureAwait(false);
                        if (n == 0) break;
                        Interlocked.Add(ref unread, n);
                        await received.Writer.WriteAsync(buffer.AsSpan(0, n).ToArray(), closing.Token).ConfigureAwait(false);
                    }
                    received.Writer.TryComplete();
                }
                catch (Exception e)
                {
                    received.Writer.TryComplete(e is IOException ? e : new IOException(e.Message, e));
                }
                finally
                {
                    ended = true;
                    Interlocked.Decrement(ref activeReaders);
                }
            }

            public override async ValueTask<int> ReadAsync(Memory<byte> destination, CancellationToken cancellationToken = default)
            {
                while (offset >= current.Length)
                {
                    if (!await received.Reader.WaitToReadAsync(cancellationToken).ConfigureAwait(false)) return 0;
                    // a zero-byte read only waits until there is something to read
                    if (destination.Length == 0) return 0;
                    if (received.Reader.TryRead(out var next)) { current = next; offset = 0; }
                }
                int count = Math.Min(destination.Length, current.Length - offset);
                current.AsMemory(offset, count).CopyTo(destination);
                offset += count;
                Interlocked.Add(ref unread, -count);
                return count;
            }

            public override async ValueTask WriteAsync(ReadOnlyMemory<byte> source, CancellationToken cancellationToken = default)
            {
                if (dropping) return;
                try
                {
                    await inner.WriteAsync(source, cancellationToken).ConfigureAwait(false);
                }
                catch (IOException)
                {
                    // the server stopped taking the body: when it answered, the answer is what counts
                    for (int waited = 0; Interlocked.Read(ref unread) == 0 && !ended && waited < AnswerWaitMs; waited += 10)
                    {
                        await Task.Delay(10, CancellationToken.None).ConfigureAwait(false);
                    }
                    if (Interlocked.Read(ref unread) == 0) throw;
                    dropping = true;
                }
            }

            public override Task<int> ReadAsync(byte[] buffer, int index, int count, CancellationToken cancellationToken) => ReadAsync(buffer.AsMemory(index, count), cancellationToken).AsTask();
            public override Task WriteAsync(byte[] buffer, int index, int count, CancellationToken cancellationToken) => WriteAsync(buffer.AsMemory(index, count), cancellationToken).AsTask();
            public override int Read(byte[] buffer, int index, int count) => ReadAsync(buffer.AsMemory(index, count)).AsTask().GetAwaiter().GetResult();
            public override void Write(byte[] buffer, int index, int count) => WriteAsync(buffer.AsMemory(index, count)).AsTask().GetAwaiter().GetResult();
            public override void Flush() { if (!dropping) inner.Flush(); }
            public override Task FlushAsync(CancellationToken cancellationToken) => dropping ? Task.CompletedTask : inner.FlushAsync(cancellationToken);
            public override bool CanRead => true;
            public override bool CanWrite => true;
            public override bool CanSeek => false;
            public override long Length => throw new NotSupportedException();
            public override long Position { get => throw new NotSupportedException(); set => throw new NotSupportedException(); }
            public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
            public override void SetLength(long value) => throw new NotSupportedException();

            protected override void Dispose(bool disposing)
            {
                if (disposing && Interlocked.Exchange(ref disposed, 1) == 0)
                {
                    // a reader waiting for room in a full buffer wakes up and ends, so neither the task
                    // nor its buffers outlive the connection
                    received.Writer.TryComplete();
                    closing.Cancel();
                    inner.Dispose();
                    closing.Dispose();
                }
                base.Dispose(disposing);
            }
        }
    }
}
'@
$Script:HttpTransportType = & {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $hash = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Script:HttpTransportSource)) } finally { $sha.Dispose() }
    'PivotReportHttp.Transport_' + (-join ($hash[0..7] | ForEach-Object { $_.ToString('x2') }))
}
$Script:HttpTransportSource = $Script:HttpTransportSource.Replace('Transport_SUFFIX', ($Script:HttpTransportType -split '\.')[-1])
# $true: compiled, $false: not available (or switched off by a test), $null: not tried yet
$Script:HttpTransportCompiled = $null

function New-UDPivotError {
    <#
    .SYNOPSIS
        An ErrorRecord with a fixed error id, so a script can tell the reasons apart
        ($_.FullyQualifiedErrorId, Should -Throw -ErrorId).
    .DESCRIPTION
        The ids: PivotServerUnreachable, PivotRedirectRefused, PivotTokenRefused, PivotDataTooLarge,
        PivotViewHasErrors, PivotServerError, PivotCliNotFound, PivotCliFailed. Data holds what the
        caller may act on, where the server sent it: Status, Code, RetryAfter (the Retry-After header:
        seconds or an HTTP date), Retryable (bool: whether the same request may work when tried again)
        and RequestId (from the problem document, else the X-Request-Id header). The record carries no
        request, so no token or secret.
    .PARAMETER Id
        The error id.
    .PARAMETER Message
        What happened and what to do.
    .PARAMETER Category
        The ErrorCategory.
    .PARAMETER Data
        Values for Exception.Data.
    .EXAMPLE
        throw (New-UDPivotError -Id PivotCliNotFound -Message 'pivotkit was not found' -Category ObjectNotFound)
    .OUTPUTS
        System.Management.Automation.ErrorRecord
    #>
    # Builds an errorrecord in memory; changes no state, so no ShouldProcess
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        [Parameter(Mandatory)][ValidateSet('PivotServerUnreachable', 'PivotRedirectRefused', 'PivotTokenRefused', 'PivotDataTooLarge', 'PivotViewHasErrors', 'PivotServerError', 'PivotCliNotFound', 'PivotCliFailed')][string]$Id,
        [Parameter(Mandatory)][string]$Message,
        [System.Management.Automation.ErrorCategory]$Category = 'InvalidResult',
        [hashtable]$Data
    )
    $exception = [System.InvalidOperationException]::new($Message)
    if ($Data) { foreach ($k in $Data.Keys) { if ($null -ne $Data[$k]) { $exception.Data[$k] = $Data[$k] } } }
    [System.Management.Automation.ErrorRecord]::new($exception, $Id, $Category, $null)
}

function Test-UDPivotLoopbackUri {
    <#
    .SYNOPSIS
        Whether an address is https, or http on this machine (localhost, 127.0.0.0/8, ::1).
    .DESCRIPTION
        A bearer token and a client secret go only over https; plain http only to a server on the same
        machine (a pivotkit-server next to PSU, a test), as pivotkit's command line allows it.
    .PARAMETER Uri
        The address.
    .EXAMPLE
        Test-UDPivotLoopbackUri -Uri ([uri]'http://127.0.0.1:3333/api/v1')
    .OUTPUTS
        System.Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][uri]$Uri)
    if ($Uri.Scheme -eq 'https') { return $true }
    if ($Uri.Scheme -ne 'http') { return $false }
    if ($Uri.IsLoopback) { return $true }
    $address = $null
    [System.Net.IPAddress]::TryParse($Uri.DnsSafeHost, [ref]$address) -and [System.Net.IPAddress]::IsLoopback($address)
}

function Get-UDPivotSafeAddress {
    <#
    .SYNOPSIS
        An address as messages may show it: scheme, host, port and path, never user info or a query.
    .PARAMETER Uri
        The address.
    .EXAMPLE
        Get-UDPivotSafeAddress -Uri ([uri]'https://reports.example.com/api/v1/views/render/file')
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][uri]$Uri)
    '{0}://{1}{2}' -f $Uri.Scheme, $Uri.Authority, $Uri.AbsolutePath
}

function ConvertTo-UDPivotPlainText {
    <#
    .SYNOPSIS
        A secret given as a string or a SecureString, as plain text for the one request that needs it.
    .DESCRIPTION
        PSU hands a secret variable to a script as its value; a SecureString (Read-Host -AsSecureString,
        a PSCredential's password) works the same. The text is never written to any stream.
    .PARAMETER Secret
        The secret.
    .PARAMETER Name
        The parameter it came from, for the error message.
    .EXAMPLE
        ConvertTo-UDPivotPlainText -Secret $Secret:PivotkitToken -Name '-Token'
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowNull()][object]$Secret, [Parameter(Mandatory)][string]$Name)
    $text = if ($Secret -is [securestring]) { [System.Net.NetworkCredential]::new('', $Secret).Password } elseif ($Secret -is [string]) { $Secret }
    if ([string]::IsNullOrEmpty($text)) { throw ('{0}: expected a token as a string or SecureString (a PSU secret).' -f $Name) }
    if ($text -match '[\s\p{Cc}]') { throw ('{0}: the token holds whitespace or a control character.' -f $Name) }
    $text
}

function Get-UDPivotTableWriter {
    <#
    .SYNOPSIS
        The compiled row writer of Write-UDPivotReportTable, compiled on first use; $null when Add-Type
        is not available.
    .EXAMPLE
        $type = Get-UDPivotTableWriter
    .OUTPUTS
        System.Type, or $null.
    #>
    [CmdletBinding()]
    [OutputType([type])]
    param()
    if ($false -eq $Script:ReportWriterCompiled) { return $null }
    $type = $Script:ReportWriterType -as [type]
    if (-not $type) {
        try {
            $references = @('System.Text.Json', 'System.Data.Common', 'System.Collections', 'System.Runtime', 'System.Memory', 'System.ComponentModel.Primitives', 'System.Text.Encodings.Web', ([psobject].Assembly.Location))
            Add-Type -TypeDefinition $Script:ReportWriterSource -ReferencedAssemblies $references -ErrorAction Stop
            $type = $Script:ReportWriterType -as [type]
        }
        catch {
            # another runspace of the process may have compiled the same type a moment before: use it
            $type = $Script:ReportWriterType -as [type]
            if (-not $type) { Write-Verbose ('Invoke-UDPivotReport: no compiled row writer ({0}); PowerShell writes the rows.' -f $_.Exception.Message) }
        }
    }
    $Script:ReportWriterCompiled = $null -ne $type
    $type
}

function Write-UDPivotReportTable {
    <#
    .SYNOPSIS
        Writes rows as pivotkit's table of data (columns, rows, rowCount) into an open JSON object, row by
        row, and stops as soon as the JSON passes -MaxBytes.
    .DESCRIPTION
        A DataTable or DataView is read straight from its rows (no row objects in between), when its
        columns hold text, numbers, booleans, GUIDs, dates or TimeSpans; any other -Data goes through
        ConvertTo-PSUComponentData first. Values: text, a finite number, true, false or null; dates as
        ISO 8601 text, TimeSpans as seconds, DBNull, NaN and infinity as null, anything else its text.
        The columns are those of the first row; every row is read by those names, so another property
        order keeps its columns, a missing one is null, and one the first row lacks is left out with one
        warning. With -MaxBytes the row count times the columns is checked first (each cell takes at
        least two bytes), then the JSON written so far every 256 rows; past the cap it throws
        PivotDataTooLarge, before the rest is converted.
    .PARAMETER Writer
        The writer, inside an object (WriteStartObject done).
    .PARAMETER Data
        The rows: a DataTable, DataView, DataRows, objects, hashtables or a script block returning them.
    .PARAMETER MaxBytes
        The most bytes the writer may hold; 0 for no cap.
    .PARAMETER RowCount
        Write rowCount after the rows (pivotkit-server's data in the request needs it).
    .EXAMPLE
        Write-UDPivotReportTable -Writer $writer -Data $table -MaxBytes 10MB -RowCount
    .OUTPUTS
        None.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)][System.Text.Json.Utf8JsonWriter]$Writer,
        [Parameter(Mandatory)][AllowNull()][AllowEmptyCollection()][object]$Data,
        [long]$MaxBytes = 0,
        [switch]$RowCount
    )
    $tooLarge = {
        throw (New-UDPivotError -Id PivotDataTooLarge -Category LimitsExceeded -Data @{ MaxBytes = $MaxBytes } -Message ('-Data is larger than {0:N0} bytes, the most this request may carry (-MaxBytes; pivotkit-server takes 10 MiB from a caller unless its operator raised rest.data.maxBytes): send fewer rows or columns, raise -MaxBytes to what the server takes, or let the operator configure a source for the data and use -Source.' -f $MaxBytes))
    }
    # a DataTable or DataView whose column types need no PowerShell rules: its rows as they are
    # assigned, not taken from an if's output: the pipeline would enumerate the table into its rows
    $table = $null
    if ($Data -is [System.Data.DataTable]) { $table = $Data } elseif ($Data -is [System.Data.DataView]) { $table = $Data.Table }
    $plainTypes = [type[]]@([string], [bool], [char], [byte], [sbyte], [int16], [uint16], [int], [uint32], [long], [uint64], [single], [double], [decimal], [guid], [datetime], [datetimeoffset], [timespan])
    $direct = $table -and $table.Columns.Count -and @($table.Columns | Where-Object { $_.DataType -notin $plainTypes }).Count -eq 0
    if ($direct) {
        $columns = [string[]]@($table.Columns | ForEach-Object ColumnName)
        $source = $table.Rows
        if ($Data -is [System.Data.DataView]) { $source = $Data }
        $count = $source.Count
    }
    else {
        # PSCustomObjects as they are (the compiled writer reads them by name and applies the value rules);
        # anything else through ConvertTo-PSUComponentData
        $writerType = if ($Data -is [System.Collections.IList] -and $Data.Count -ge $Script:ReportWriterMinRows) { Get-UDPivotTableWriter }
        if ($writerType -and $writerType::AllCustomObjects($Data)) { $source = $Data }
        else { $source = ConvertTo-PSUComponentData -InputObject $Data }
        $columns = [string[]]@($source | Select-Object -First 1 | ForEach-Object { $_.PSObject.Properties.Name })
        $count = @($source).Count
    }
    # an empty result has no columns to check a view against: the caller decides (a schedule skips the run)
    if (-not $columns.Count) { throw '-Data: no rows, so there is no report to render; check for rows before you call (if (@($rows).Count) { ... }).' }
    if ($MaxBytes -gt 0 -and [long]$count * (2 * $columns.Count + 1) -gt $MaxBytes) { & $tooLarge }

    $Writer.WriteStartArray('columns')
    foreach ($name in $columns) { $Writer.WriteStringValue($name) }
    $Writer.WriteEndArray()
    $Writer.WriteStartArray('rows')
    $known = [System.Collections.Generic.HashSet[string]]::new($columns, [System.StringComparer]::OrdinalIgnoreCase)
    $dropped = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $width = $columns.Count
    $written = 0
    $compiled = if ($count -ge $Script:ReportWriterMinRows) { Get-UDPivotTableWriter }
    # which writer wrote the last table: Compiled or PowerShell (the tests check that the class runs)
    $Script:LastTableWriter = if ($compiled) { 'Compiled' } else { 'PowerShell' }
    if ($compiled) {
        $written = $compiled::WriteRows($Writer, $columns, $source, $MaxBytes, $dropped)
        if ($written -lt 0) { & $tooLarge }
        # nothing left for the loop below
        $source = @()
    }
    foreach ($item in $source) {
        if ($direct) {
            $dataRow = if ($item -is [System.Data.DataRowView]) { $item.Row } else { $item }
            # a row deleted but not yet accepted has no values to read (ItemArray throws): left out
            if ($dataRow.RowState -in [System.Data.DataRowState]::Deleted, [System.Data.DataRowState]::Detached) { continue }
            $values = $dataRow.ItemArray
        }
        else {
            # by name: the rows' properties may come in another order than the first row's
            $properties = $item.PSObject.Properties
            $values = [object[]]::new($width)
            for ($i = 0; $i -lt $width; $i++) { $p = $properties[$columns[$i]]; if ($p) { $values[$i] = $p.Value } }
            foreach ($name in $properties.Name) { if (-not $known.Contains($name)) { [void]$dropped.Add($name) } }
        }
        $Writer.WriteStartArray()
        foreach ($v in $values) {
            if ($null -eq $v -or $v -is [System.DBNull]) { $Writer.WriteNullValue() }
            elseif ($v -is [string]) { $Writer.WriteStringValue($v) }
            elseif ($v -is [bool]) { $Writer.WriteBooleanValue($v) }
            elseif ($v -is [double] -or $v -is [single]) { if ([double]::IsNaN($v) -or [double]::IsInfinity($v)) { $Writer.WriteNullValue() } else { $Writer.WriteNumberValue([double]$v) } }
            elseif ($v -is [int] -or $v -is [long] -or $v -is [short] -or $v -is [byte] -or $v -is [sbyte] -or $v -is [uint16] -or $v -is [uint32]) { $Writer.WriteNumberValue([long]$v) }
            elseif ($v -is [decimal] -or $v -is [uint64]) { $Writer.WriteNumberValue([decimal]$v) }
            elseif ($v -is [datetime] -or $v -is [datetimeoffset]) { $Writer.WriteStringValue($v.ToString('o', [cultureinfo]::InvariantCulture)) }
            elseif ($v -is [timespan]) { $Writer.WriteNumberValue([double]$v.TotalSeconds) }
            else { $Writer.WriteStringValue([string]$v) }
        }
        $Writer.WriteEndArray()
        $written++
        if ($MaxBytes -gt 0 -and ($written % 256) -eq 0 -and $Writer.BytesCommitted + $Writer.BytesPending -gt $MaxBytes) { & $tooLarge }
    }
    $Writer.WriteEndArray()
    if ($MaxBytes -gt 0 -and $Writer.BytesCommitted + $Writer.BytesPending -gt $MaxBytes) { & $tooLarge }
    if ($RowCount) { $Writer.WriteNumber('rowCount', [long]$written) }
    if ($dropped.Count) {
        $names = @($dropped | Select-Object -First 5) -join ', '
        Write-Warning ('-Data: properties the first row does not have are left out: {0}{1}. Give every row the same properties (Select-Object) to keep them.' -f $names, $(if ($dropped.Count -gt 5) { ', and {0} more' -f ($dropped.Count - 5) }))
    }
}

function New-UDPivotJsonWriter {
    <#
    .SYNOPSIS
        A UTF-8 JSON writer on a stream, compact, with non-ASCII text as it is.
    .DESCRIPTION
        The relaxed encoder leaves letters with accents as they are instead of \u escapes: the JSON goes to
        pivotkit (a request body, a data file), never into an HTML page.
    .PARAMETER Stream
        The stream to write to.
    .EXAMPLE
        $writer = New-UDPivotJsonWriter -Stream $memory
    .OUTPUTS
        System.Text.Json.Utf8JsonWriter
    #>
    # Creates a writer object in memory; changes no state, so no ShouldProcess
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType([System.Text.Json.Utf8JsonWriter])]
    param([Parameter(Mandatory)][System.IO.Stream]$Stream)
    $options = [System.Text.Json.JsonWriterOptions]::new()
    $options.Encoder = [System.Text.Encodings.Web.JavaScriptEncoder]::UnsafeRelaxedJsonEscaping
    [System.Text.Json.Utf8JsonWriter]::new($Stream, $options)
}

function ConvertTo-UDPivotReportLayout {
    <#
    .SYNOPSIS
        Checks a layout (a view by field names) and returns it as an ordered dictionary of its keys.
    .DESCRIPTION
        Keys: rows, cols (field names), values (@{ field; agg }), groups (@{ field; by; size }), filters
        (as a view writes them), chart (auto, bar, line, area, pie, donut, heatmap) and map (old name =
        the data's name), as pivotkit's layout flags and the REST service's layout take them. An unknown
        key is an error that names it.
    .PARAMETER Layout
        The layout.
    .EXAMPLE
        ConvertTo-UDPivotReportLayout -Layout @{ rows = 'Team'; values = @{ field = 'Hours'; agg = 'sum' } }
    .OUTPUTS
        System.Collections.Specialized.OrderedDictionary
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Layout)
    $out = [ordered]@{}
    foreach ($key in $Layout.Keys) {
        $name = $Script:LayoutKeys | Where-Object { $_ -eq [string]$key } | Select-Object -First 1
        if (-not $name) { throw ('-Layout: unknown key "{0}"; expected {1}.' -f $key, ($Script:LayoutKeys -join ', ')) }
        $value = $Layout[$key]
        $out[$name] = switch ($name) {
            { $_ -in 'rows', 'cols' } { , [string[]]@($value | ForEach-Object { [string]$_ }) }
            'chart' {
                $type = [string]$value
                if ($type -notin 'auto', 'bar', 'line', 'area', 'pie', 'donut', 'heatmap') { throw ('-Layout: chart "{0}"; expected auto, bar, line, area, pie, donut or heatmap.' -f $type) }
                $type.ToLowerInvariant()
            }
            'map' {
                if ($value -isnot [System.Collections.IDictionary]) { throw '-Layout: map is a hashtable of a field the layout names and the data''s field: @{ Revenue = ''Turnover'' }.' }
                $map = [ordered]@{}
                foreach ($k in $value.Keys) { $map[[string]$k] = [string]$value[$k] }
                $map
            }
            default {
                $items = @($value | ForEach-Object {
                        if ($_ -isnot [System.Collections.IDictionary] -and $_ -isnot [System.Management.Automation.PSCustomObject]) { throw ('-Layout: {0} is a list of hashtables.' -f $name) }
                        $_
                    })
                , $items
            }
        }
    }
    if (-not $out.Count) { throw '-Layout: empty; give rows, cols or values.' }
    $out
}

function Get-UDPivotLayoutArgument {
    <#
    .SYNOPSIS
        A layout as the layout flags of pivotkit's command line (--rows, --cols, --values, --group,
        --filter, --chart-type, --map).
    .DESCRIPTION
        Each value is one argument of its own, written as --option=value, so a field name may hold commas,
        spaces and colons and may start with a dash ("--rows -x" would read -x as an option).
    .PARAMETER Layout
        The layout of ConvertTo-UDPivotReportLayout.
    .EXAMPLE
        Get-UDPivotLayoutArgument -Layout ([ordered]@{ rows = @('Team'); values = @(@{ field = 'Hours'; agg = 'sum' }) })
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Layout)
    $get = { param($Item, $Key) if ($Item -is [System.Collections.IDictionary]) { $Item[$Key] } else { $Item.$Key } }
    foreach ($field in @($Layout['rows'])) { if ($field) { '--rows=' + $field } }
    foreach ($field in @($Layout['cols'])) { if ($field) { '--cols=' + $field } }
    foreach ($v in @($Layout['values'])) {
        if (-not $v) { continue }
        $field = [string](& $get $v 'field')
        $agg = [string](& $get $v 'agg')
        '--values=' + $(if ($agg -and $field) { '{0}:{1}' -f $agg, $field } elseif ($field) { $field } else { $agg })
    }
    foreach ($g in @($Layout['groups'])) {
        if (-not $g) { continue }
        $size = & $get $g 'size'
        $text = if ($null -ne $size) { [string]::Format([cultureinfo]::InvariantCulture, '{0}:{1}:{2}', (& $get $g 'field'), (& $get $g 'by'), $size) } else { '{0}:{1}' -f (& $get $g 'field'), (& $get $g 'by') }
        '--group=' + $text
    }
    foreach ($f in @($Layout['filters'])) { if ($f) { '--filter=' + (ConvertTo-Json -InputObject $f -Depth 8 -Compress) } }
    if ($Layout['chart']) { '--chart-type=' + $Layout['chart'] }
    if ($Layout['map']) { foreach ($k in $Layout['map'].Keys) { '--map={0}={1}' -f $k, $Layout['map'][$k] } }
}

function Get-UDPivotCliCommand {
    <#
    .SYNOPSIS
        How to start pivotkit's command line: the program and the arguments before pivotkit's own.
    .DESCRIPTION
        -CliPath, else the command pivotkit on the PATH (npm install --global pivotkit-cli). A .js file
        runs with node. On Windows npm installs pivotkit.cmd, a batch file that would pass every argument
        through cmd.exe's quoting: the function runs the package's bin/pivotkit.js next to it with node
        instead.
    .PARAMETER CliPath
        The pivotkit program or its bin/pivotkit.js.
    .EXAMPLE
        Get-UDPivotCliCommand -CliPath '/usr/local/bin/pivotkit'
    .OUTPUTS
        System.Management.Automation.PSCustomObject with FileName and Arguments.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([AllowEmptyString()][string]$CliPath)
    $path = if ($CliPath) {
        if (-not (Test-Path -LiteralPath $CliPath -PathType Leaf)) { throw (New-UDPivotError -Id PivotCliNotFound -Category ObjectNotFound -Message ('-CliPath "{0}": no such file.' -f $CliPath)) }
        (Resolve-Path -LiteralPath $CliPath).ProviderPath
    }
    else {
        $found = Get-Command -Name 'pivotkit' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $found) { throw (New-UDPivotError -Id PivotCliNotFound -Category ObjectNotFound -Message 'pivotkit''s command line was not found: install it with "npm install --global pivotkit-cli" (Node 22 or later) on the PSU server, or pass -CliPath.') }
        $found.Source
    }
    if ($path -match '\.(cmd|bat|ps1)$') {
        # npm's shims sit next to node_modules/pivotkit-cli
        $js = Join-Path (Split-Path -Parent $path) 'node_modules' 'pivotkit-cli' 'bin' 'pivotkit.js'
        if (-not (Test-Path -LiteralPath $js -PathType Leaf)) { throw (New-UDPivotError -Id PivotCliNotFound -Category ObjectNotFound -Message ('"{0}" is a script shim; pass -CliPath with pivotkit-cli''s bin/pivotkit.js.' -f $path)) }
        $path = $js
    }
    if ($path -match '\.(js|mjs)$') {
        $node = Get-Command -Name 'node' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $node) { throw (New-UDPivotError -Id PivotCliNotFound -Category ObjectNotFound -Message 'node was not found: pivotkit''s command line needs Node 22 or later on the PSU server.') }
        return [pscustomobject]@{ FileName = $node.Source; Arguments = @($path) }
    }
    [pscustomobject]@{ FileName = $path; Arguments = @() }
}

function Invoke-UDPivotCli {
    <#
    .SYNOPSIS
        Runs pivotkit's command line with an argument list and returns its --json answer.
    .DESCRIPTION
        Every argument is passed as one (ProcessStartInfo.ArgumentList, no shell, no quoting). stdout is
        read as the JSON object of --json; a run longer than -TimeoutSec is stopped.
    .PARAMETER Command
        Get-UDPivotCliCommand's result.
    .PARAMETER Argument
        pivotkit's arguments.
    .PARAMETER TimeoutSec
        The longest run.
    .EXAMPLE
        Invoke-UDPivotCli -Command (Get-UDPivotCliCommand) -Argument 'render', 'view.json', '--data', 'data.json', '-o', 'out.xlsx', '--json'
    .OUTPUTS
        System.Management.Automation.PSCustomObject (pivotkit's --json object).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][pscustomobject]$Command,
        [Parameter(Mandatory)][string[]]$Argument,
        [ValidateRange(1, 3600)][int]$TimeoutSec = $Script:ReportTimeoutSec
    )
    $info = [System.Diagnostics.ProcessStartInfo]::new($Command.FileName)
    foreach ($a in @($Command.Arguments) + $Argument) { $info.ArgumentList.Add($a) }
    $info.UseShellExecute = $false
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.RedirectStandardInput = $true
    $info.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $info.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $info
    try {
        try { [void]$process.Start() }
        catch { throw (New-UDPivotError -Id PivotCliFailed -Category OpenError -Message ('pivotkit''s command line did not start ({0}): {1}' -f $Command.FileName, $_.Exception.Message)) }
        $process.StandardInput.Close()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSec * 1000)) {
            $process.Kill($true)
            throw (New-UDPivotError -Id PivotCliFailed -Category OperationTimeout -Message ('pivotkit''s command line took longer than {0} seconds and was stopped.' -f $TimeoutSec))
        }
        $process.WaitForExit()
        $text = $stdout.GetAwaiter().GetResult()
        $errText = $stderr.GetAwaiter().GetResult()
        try { $answer = ConvertFrom-Json -InputObject $text -Depth 32 }
        catch { $answer = $null }
        if ($null -eq $answer -or $null -eq $answer.PSObject.Properties['ok']) {
            $line = ($errText -split "`n" | Where-Object { $_.Trim() } | Select-Object -First 1)
            throw (New-UDPivotError -Id PivotCliFailed -Category InvalidResult -Message ('pivotkit''s command line (exit {0}) gave no --json answer: {1} (pivotkit-cli 0.2.1 or later is needed).' -f $process.ExitCode, $(if ($line) { $line.Trim() } else { 'no output' })))
        }
        $answer | Add-Member -NotePropertyName exitCode -NotePropertyValue $process.ExitCode -Force
        $answer
    }
    finally {
        $process.Dispose()
    }
}

function Get-UDPivotFindingText {
    <#
    .SYNOPSIS
        pivotkit's findings as lines: "error unknownField at rows[0]: unknown field "Regoin" (did you mean Region?)".
    .PARAMETER Finding
        The findings of a --json answer or a problem document.
    .EXAMPLE
        Get-UDPivotFindingText -Finding $answer.findings
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowNull()][object[]]$Finding)
    foreach ($f in @($Finding | Where-Object { $_ })) {
        $text = '{0} {1}' -f $f.severity, $f.code
        if ($f.path) { $text += ' at {0}' -f $f.path }
        $text += ': {0}' -f $f.message
        if ($f.suggestion) { $text += ' (did you mean {0}?)' -f $f.suggestion }
        $text
    }
}

function New-UDPivotHttpHandler {
    <#
    .SYNOPSIS
        The HTTP handler of the REST engine: no redirects, no cookies, and connections that keep an answer
        the server sends while the body is still being sent.
    .DESCRIPTION
        Compiles $Script:HttpTransportSource on first use. Where Add-Type is not available, a plain
        SocketsHttpHandler with the same settings: requests work, but an early answer (pivotkit-server's
        413 for a body over its cap) is lost and the request fails as unreachable.
    .EXAMPLE
        $client = [System.Net.Http.HttpClient]::new((New-UDPivotHttpHandler), $true)
    .OUTPUTS
        System.Net.Http.SocketsHttpHandler
    #>
    # Builds a handler in memory; changes no state, so no ShouldProcess
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType([System.Net.Http.SocketsHttpHandler])]
    param()
    $type = $null
    if ($false -ne $Script:HttpTransportCompiled) {
        $type = $Script:HttpTransportType -as [type]
        if (-not $type) {
            try {
                $references = @('System.Net.Http', 'System.Net.Sockets', 'System.Net.Primitives', 'System.Threading.Channels', 'System.Runtime', 'System.Memory', 'System.Threading', 'System.Collections.Concurrent')
                Add-Type -TypeDefinition $Script:HttpTransportSource -ReferencedAssemblies $references -ErrorAction Stop
                $type = $Script:HttpTransportType -as [type]
            }
            catch {
                # another runspace of the process may have compiled the same type a moment before: use it
                $type = $Script:HttpTransportType -as [type]
                if (-not $type) { Write-Verbose ('Invoke-UDPivotReport: no compiled HTTP transport ({0}); an answer the server sends before the body is sent is lost.' -f $_.Exception.Message) }
            }
        }
        $Script:HttpTransportCompiled = $null -ne $type
    }
    if ($type) { return $type::NewHandler() }
    $handler = [System.Net.Http.SocketsHttpHandler]::new()
    $handler.AllowAutoRedirect = $false
    $handler.UseCookies = $false
    $handler.AutomaticDecompression = [System.Net.DecompressionMethods]::All
    $handler
}

function Invoke-UDPivotHttp {
    <#
    .SYNOPSIS
        One POST without redirects whose errors carry no request: the answer, or an error with the
        message alone.
    .DESCRIPTION
        Sends with HttpClient over New-UDPivotHttpHandler: a redirect is returned as it is, not followed,
        and an answer the server sends while the body is still being sent (a 413 for a body over its
        cap, after which it closes the connection) is returned like any other. A request that gets no
        answer becomes PivotServerUnreachable with the exception's message alone; the record PowerShell
        keeps of the failed call is removed from $Error. Nothing is written to the verbose or debug
        stream, so no token or secret reaches one.
    .PARAMETER Request
        Uri, Body (bytes or a string, sent as UTF-8), ContentType, Headers, TimeoutSec.
    .PARAMETER What
        What is called, for the message ("pivotkit-server https://...").
    .PARAMETER Hint
        A line added to the message when there is no answer.
    .EXAMPLE
        Invoke-UDPivotHttp -Request @{ Uri = $uri; Body = $bytes; ContentType = 'application/json'; Headers = $headers; TimeoutSec = 30 } -What 'pivotkit-server'
    .OUTPUTS
        PSCustomObject with StatusCode (int), Headers (a case-insensitive hashtable of the answer's
        headers, the values of a repeated header joined by a comma) and Content (the body's bytes).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)][hashtable]$Request, [Parameter(Mandatory)][string]$What, [string]$Hint)
    $body = if ($Request['Body'] -is [byte[]]) { $Request['Body'] } else { [System.Text.Encoding]::UTF8.GetBytes([string]$Request['Body']) }
    # every header value as visible ASCII or a tab (RFC 9110 5.5): HttpClient sends other characters as
    # they are (a line break would start another header) or fails with a message that looks like an
    # unreachable server. The error names the header (without line breaks), never its value (a token)
    $headers = [ordered]@{
        # a client name, as Invoke-WebRequest sends one: some proxies and firewalls refuse a request without
        'User-Agent' = 'PowerShellUniversal.Component.Pivot/{0} PowerShell/{1}' -f $ExecutionContext.SessionState.Module.Version, $PSVersionTable.PSVersion
    }
    if ($Request['Headers']) { foreach ($k in $Request['Headers'].Keys) { $headers[$k] = [string]$Request['Headers'][$k] } }
    foreach ($k in @($headers.Keys) + 'Content-Type') {
        $value = if ($k -eq 'Content-Type') { [string]$Request['ContentType'] } else { $headers[$k] }
        if ($value -cnotmatch '^[\x20-\x7E\t]*$') { throw ('{0}: the request header {1} holds a character a header cannot carry (a control character other than tab, or one outside ASCII); nothing was sent.' -f $What, ($k -replace '[\r\n]', '')) }
    }
    $client = $null
    $message = $null
    $response = $null
    $failure = $null
    try {
        $client = [System.Net.Http.HttpClient]::new((New-UDPivotHttpHandler), $true)
        $message = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Post, [uri]$Request['Uri'])
        if ($Request['TimeoutSec']) { $client.Timeout = [timespan]::FromSeconds($Request['TimeoutSec']) }
        $message.Content = [System.Net.Http.ByteArrayContent]::new($body)
        if (-not $message.Content.Headers.TryAddWithoutValidation('Content-Type', [string]$Request['ContentType'])) { throw ('{0}: the request header Content-Type could not be set; nothing was sent.' -f $What) }
        foreach ($k in $headers.Keys) {
            if (-not $message.Headers.TryAddWithoutValidation($k, $headers[$k])) { throw ('{0}: the request header {1} could not be set; nothing was sent.' -f $What, ($k -replace '[\r\n]', '')) }
        }
        try {
            $response = $client.SendAsync($message).GetAwaiter().GetResult()
            $headers = [hashtable]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($pair in @($response.Headers) + @($response.Content.Headers)) { $headers[$pair.Key] = @($pair.Value) -join ', ' }
            return [pscustomobject]@{
                StatusCode = [int]$response.StatusCode
                Headers    = $headers
                Content    = [byte[]]$response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
            }
        }
        catch {
            # the innermost exception that says what went wrong (a method call wraps it once)
            $e = $_.Exception
            while ($e -is [System.Management.Automation.MethodInvocationException] -and $e.InnerException) { $e = $e.InnerException }
            $failure = $e.Message
            if ($e.InnerException -and $e.InnerException.Message -and $e.InnerException.Message -ne $failure) { $failure = '{0} ({1})' -f $failure, $e.InnerException.Message }
            # keep no record of the call in $Error (catch hands over a copy of the record: it is found by its exception)
            if ($global:Error.Count -and [object]::ReferenceEquals($global:Error[0].Exception, $_.Exception)) { $global:Error.RemoveAt(0) }
        }
    }
    finally {
        if ($response) { $response.Dispose() }
        if ($message) { $message.Dispose() }
        if ($client) { $client.Dispose() }
    }
    $text = '{0} did not answer: {1}' -f $What, $(if ($failure) { $failure } else { 'no response' })
    if ($Hint) { $text += [Environment]::NewLine + $Hint }
    throw (New-UDPivotError -Id PivotServerUnreachable -Category ConnectionError -Message $text)
}

function Get-UDPivotAccessToken {
    <#
    .SYNOPSIS
        An OAuth access token by the client credentials grant, from this runspace's cache while it is
        valid.
    .DESCRIPTION
        POSTs grant_type=client_credentials to the token endpoint with the client id and secret (in the
        body, or as HTTP Basic with -ClientAuthentication Basic) and the optional scope, audience and
        resource. The token is kept until a minute before expires_in runs out, per token endpoint, client
        id, SHA-256 of the secret, scope, audience, resource and target server; a token without
        expires_in is not kept. -Renew drops a cached token first (after a 401). The secret and the token
        never reach an error message or a stream.
    .PARAMETER TokenUri
        The token endpoint (https, http only on this machine).
    .PARAMETER Credential
        The client id as the user name, the client secret as the password.
    .PARAMETER Scope
        Scopes to ask for.
    .PARAMETER Audience
        The audience parameter some providers want (Auth0).
    .PARAMETER Resource
        RFC 8707's resource: the REST service's address.
    .PARAMETER ClientAuthentication
        Post (client_secret_post, default) or Basic (client_secret_basic).
    .PARAMETER TimeoutSec
        The longest wait for the token endpoint.
    .PARAMETER Target
        The address the token is for (the REST service): part of the cache key, so a token fetched for one
        server never goes to another.
    .PARAMETER Renew
        Ask for a new token even when one is cached.
    .EXAMPLE
        Get-UDPivotAccessToken -TokenUri 'https://login.example.com/application/o/token/' -Credential $Secret:PivotkitClient -Scope 'pivotkit:rest'
    .OUTPUTS
        System.Security.SecureString
    #>
    [CmdletBinding()]
    [OutputType([securestring])]
    param(
        [Parameter(Mandatory)][uri]$TokenUri,
        [Parameter(Mandatory)][pscredential]$Credential,
        [string[]]$Scope,
        [string]$Audience,
        [string]$Resource,
        [ValidateSet('Post', 'Basic')][string]$ClientAuthentication = 'Post',
        [ValidateRange(1, 3600)][int]$TimeoutSec = 30,
        [Parameter(Mandatory)][uri]$Target,
        [switch]$Renew
    )
    if (-not $TokenUri.IsAbsoluteUri -or $TokenUri.UserInfo) { throw '-TokenUri: an absolute address without a user name or password in it.' }
    $where = Get-UDPivotSafeAddress -Uri $TokenUri
    if (-not (Test-UDPivotLoopbackUri -Uri $TokenUri)) { throw ('-TokenUri {0}: https only (http only for this machine), so the client secret is never sent in clear text.' -f $where) }
    # per token endpoint, client, secret (as its hash), scope, audience, resource and the server the
    # token is for: a changed secret is checked at the endpoint, and a token never goes to another server
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $secretHash = [Convert]::ToHexString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Credential.GetNetworkCredential().Password))) } finally { $sha.Dispose() }
    $key = ($TokenUri.AbsoluteUri, $Credential.UserName, $secretHash, (@($Scope) -join ' '), $Audience, $Resource, (Get-UDPivotSafeAddress -Uri $Target)) -join [char]1
    $entry = $Script:TokenCache[$key]
    if ($Renew) { $Script:TokenCache.Remove($key) }
    elseif ($entry -and $entry.Expires -gt [datetime]::UtcNow.AddSeconds($Script:TokenSkewSec)) { return $entry.Token }

    $body = [ordered]@{ grant_type = 'client_credentials' }
    $headers = @{ Accept = 'application/json' }
    $secret = $Credential.GetNetworkCredential().Password
    if ($ClientAuthentication -eq 'Basic') {
        # RFC 6749 2.3.1: both form-encoded before they are joined
        $pair = '{0}:{1}' -f [uri]::EscapeDataString($Credential.UserName), [uri]::EscapeDataString($secret)
        $headers['Authorization'] = 'Basic ' + [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($pair))
    }
    else {
        $body['client_id'] = $Credential.UserName
        $body['client_secret'] = $secret
    }
    if ($Scope) { $body['scope'] = @($Scope) -join ' ' }
    if ($Audience) { $body['audience'] = $Audience }
    if ($Resource) { $body['resource'] = $Resource }
    $form = ($body.Keys | ForEach-Object { '{0}={1}' -f $_, [uri]::EscapeDataString([string]$body[$_]) }) -join '&'
    try {
        $response = Invoke-UDPivotHttp -What ('Token endpoint {0}' -f $where) -Request @{
            Uri = $TokenUri; Body = $form; ContentType = 'application/x-www-form-urlencoded'; Headers = $headers; TimeoutSec = $TimeoutSec
        }
    }
    finally {
        $secret = $null
        $form = $null
        $headers = $null
    }
    if ([int]$response.StatusCode -ge 300 -and [int]$response.StatusCode -lt 400) { throw (New-UDPivotError -Id PivotRedirectRefused -Category SecurityError -Data @{ Status = [int]$response.StatusCode } -Message ('Token endpoint {0} answered with a redirect ({1}); it is not followed, so the client secret stays with this endpoint: use the address it names in -TokenUri.' -f $where, [int]$response.StatusCode)) }
    $json = $null
    try { $json = ConvertFrom-Json -InputObject ([System.Text.Encoding]::UTF8.GetString($response.Content)) -Depth 8 } catch { $json = $null }
    if ($response.StatusCode -ne 200) {
        # RFC 6749 5.2: error and error_description; nothing of the request is repeated
        $reason = if ($json -and $json.error) { '{0}{1}' -f $json.error, $(if ($json.error_description) { ': ' + $json.error_description }) } else { 'no OAuth error in the answer' }
        throw (New-UDPivotError -Id PivotTokenRefused -Category AuthenticationError -Data @{ Status = [int]$response.StatusCode; Code = if ($json -and $json.error) { [string]$json.error } } -Message ('Token endpoint {0} refused the client credentials ({1}): {2}' -f $where, [int]$response.StatusCode, $reason))
    }
    if (-not $json -or -not ($json.access_token -is [string]) -or -not $json.access_token) { throw (New-UDPivotError -Id PivotTokenRefused -Category AuthenticationError -Message ('Token endpoint {0} answered without an access_token.' -f $where)) }
    if ($json.token_type -and $json.token_type -ne 'Bearer' -and $json.token_type -ne 'bearer') { throw (New-UDPivotError -Id PivotTokenRefused -Category AuthenticationError -Message ('Token endpoint {0} gave a token of type "{1}"; pivotkit-server takes Bearer tokens.' -f $where, $json.token_type)) }
    $token = [System.Net.NetworkCredential]::new('', [string]$json.access_token).SecurePassword
    $seconds = 0
    if ($null -ne $json.expires_in -and [int]::TryParse([string]$json.expires_in, [ref]$seconds) -and $seconds -gt $Script:TokenSkewSec) {
        $Script:TokenCache[$key] = @{ Token = $token; Expires = [datetime]::UtcNow.AddSeconds($seconds) }
    }
    $token
}

function New-UDPivotRenderBody {
    <#
    .SYNOPSIS
        The input of pivotkit-server's render_view as UTF-8 JSON, the rows written straight into it.
    .DESCRIPTION
        source, then data (columns, rows, rowCount, name, asOf) or params, then view or layout, format and
        title. The rows go through Write-UDPivotReportTable: no copy of them as objects or as one JSON
        string, and past -MaxBytes it stops with PivotDataTooLarge before the rest is converted.
    .PARAMETER Data
        The rows, or $null with -Source.
    .PARAMETER Source
        A source the operator configured, instead of -Data.
    .PARAMETER Parameter
        The source's parameters.
    .PARAMETER View
        The view (an object), or $null with -Layout.
    .PARAMETER Layout
        The layout, or $null with -View.
    .PARAMETER Format
        The format.
    .PARAMETER Title
        The report's title.
    .PARAMETER DataName
        What the data is.
    .PARAMETER DataAsOf
        When the data is from.
    .PARAMETER MaxBytes
        The most bytes of the body; 0 for no cap.
    .EXAMPLE
        New-UDPivotRenderBody -Data $rows -View $view -Format csv -MaxBytes 10MB
    .OUTPUTS
        System.Byte[]
    #>
    # Builds a request body in memory; changes no state, so no ShouldProcess
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType([byte[]])]
    param(
        [AllowNull()][object]$Data,
        [string]$Source,
        [System.Collections.IDictionary]$Parameter,
        [AllowNull()][object]$View,
        [AllowNull()][System.Collections.IDictionary]$Layout,
        [Parameter(Mandatory)][string]$Format,
        [string]$Title,
        [string]$DataName,
        [Nullable[datetime]]$DataAsOf,
        [long]$MaxBytes = 0
    )
    $memory = [System.IO.MemoryStream]::new()
    $writer = New-UDPivotJsonWriter -Stream $memory
    try {
        $writer.WriteStartObject()
        if ($Source) { $writer.WriteString('source', $Source) }
        else {
            $writer.WriteString('source', 'inline:')
            $writer.WriteStartObject('data')
            Write-UDPivotReportTable -Writer $writer -Data $Data -MaxBytes $MaxBytes -RowCount
            if ($DataName) { $writer.WriteString('name', $DataName) }
            if ($DataAsOf) { $writer.WriteString('asOf', ([datetime]$DataAsOf).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ', [cultureinfo]::InvariantCulture)) }
            $writer.WriteEndObject()
        }
        if ($Parameter) { $writer.WritePropertyName('params'); $writer.WriteRawValue((ConvertTo-Json -InputObject $Parameter -Depth 4 -Compress)) }
        # the view and the layout are small and checked already: their JSON goes in as it is
        if ($null -ne $View) { $writer.WritePropertyName('view'); $writer.WriteRawValue((ConvertTo-Json -InputObject $View -Depth 32 -Compress -WarningAction SilentlyContinue)) }
        else { $writer.WritePropertyName('layout'); $writer.WriteRawValue((ConvertTo-Json -InputObject $Layout -Depth 32 -Compress -WarningAction SilentlyContinue)) }
        $writer.WriteString('format', $Format)
        if ($Title) { $writer.WriteString('title', $Title) }
        $writer.WriteEndObject()
        $writer.Flush()
        , $memory.ToArray()
    }
    finally {
        $writer.Dispose()
        $memory.Dispose()
    }
}

function Get-UDPivotRetryText {
    <#
    .SYNOPSIS
        "Try again in N seconds." or "Try again after <time>." from a Retry-After header; $null when it
        is absent, neither form, or a date in the past.
    .PARAMETER RetryAfter
        The header's value: seconds, or an HTTP date (RFC 9110 10.2.3).
    .EXAMPLE
        Get-UDPivotRetryText -RetryAfter '7'
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowNull()][AllowEmptyString()][string]$RetryAfter)
    if ([string]::IsNullOrWhiteSpace($RetryAfter)) { return $null }
    $seconds = 0
    if ([int]::TryParse($RetryAfter.Trim(), [System.Globalization.NumberStyles]::None, [cultureinfo]::InvariantCulture, [ref]$seconds)) { return 'Try again in {0} seconds.' -f $seconds }
    $when = [datetimeoffset]::MinValue
    # a date in the past (a clock that is off, a cached answer) says nothing about when
    if ([datetimeoffset]::TryParse($RetryAfter, [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal, [ref]$when) -and $when -gt [datetimeoffset]::UtcNow) { return 'Try again after {0}.' -f $when.UtcDateTime.ToString('u', [cultureinfo]::InvariantCulture) }
    $null
}

function Invoke-UDPivotRestRender {
    <#
    .SYNOPSIS
        POSTs a render to pivotkit-server's file route and returns the file's bytes.
    .DESCRIPTION
        POST <Uri>/views/render/file with the input as JSON and the bearer token. No redirect is followed
        (the token would go along). A problem document (RFC 9457) becomes an error with its code, detail
        (or the "error" text of a crashed handler's 500), findings (422), Retry-After (429, 503),
        retryable and request id (from the X-Request-Id header when there is no body); a 413 says what to
        do by its code. With a credential, a 401 gets one new token and one more try.
    .PARAMETER Uri
        The REST service's address, https://host/api/v1.
    .PARAMETER Body
        The input of render_view as UTF-8 JSON (New-UDPivotRenderBody).
    .PARAMETER Auth
        @{ Token } or @{ Credential; TokenUri; Scope; Audience; Resource; ClientAuthentication }.
    .PARAMETER TimeoutSec
        The longest wait for the answer.
    .EXAMPLE
        Invoke-UDPivotRestRender -Uri 'https://reports.example.com/api/v1' -Body $json -Auth @{ Token = $Secret:PivotkitToken }
    .OUTPUTS
        System.Byte[]
    #>
    [CmdletBinding()]
    [OutputType([byte[]])]
    param(
        [Parameter(Mandatory)][uri]$Uri,
        [Parameter(Mandatory)][byte[]]$Body,
        [Parameter(Mandatory)][hashtable]$Auth,
        [ValidateRange(1, 3600)][int]$TimeoutSec = $Script:ReportTimeoutSec
    )
    $target = [uri]((Get-UDPivotSafeAddress -Uri $Uri).TrimEnd('/') + '/views/render/file')
    $where = Get-UDPivotSafeAddress -Uri $target
    $bytes = $Body
    if ($bytes.Length -gt $Script:ReportDataWarnBytes) { Write-Warning ('The request is {0:N1} MiB; pivotkit-server takes at most 10 MiB unless its operator raised rest.data.maxBytes (up to 64 MiB).' -f ($bytes.Length / 1MB)) }
    $oauth = $Auth.ContainsKey('Credential')
    $tokenArgs = @{}
    if ($oauth) {
        foreach ($k in 'TokenUri', 'Credential', 'Scope', 'Audience', 'Resource', 'ClientAuthentication', 'TimeoutSec') { if ($null -ne $Auth[$k]) { $tokenArgs[$k] = $Auth[$k] } }
        $tokenArgs['Target'] = $Uri
    }
    # a server that takes less closes the connection while a large body is sent; where its answer is
    # lost on the way (no compiled transport), this is the likely reason
    $unansweredHint = if ($bytes.Length -gt $Script:ReportDataWarnBytes) { 'The request was {0:N1} MiB: a server that takes less may close the connection while it is sent. Send fewer rows or columns, or let the operator configure a source for the data and use -Source.' -f ($bytes.Length / 1MB) }
    for ($attempt = 1; ; $attempt++) {
        $token = if ($oauth) { ConvertTo-UDPivotPlainText -Secret (Get-UDPivotAccessToken @tokenArgs -Renew:($attempt -gt 1)) -Name 'The access token' } else { ConvertTo-UDPivotPlainText -Secret $Auth['Token'] -Name '-Token' }
        try {
            $response = Invoke-UDPivotHttp -What ('pivotkit-server {0}' -f $where) -Hint $unansweredHint -Request @{
                Uri = $target; Body = $bytes; ContentType = 'application/json; charset=utf-8'; Headers = @{ Authorization = 'Bearer ' + $token; Accept = '*/*' }; TimeoutSec = $TimeoutSec
            }
        }
        finally {
            $token = $null
        }
        $status = $response.StatusCode
        if ($status -eq 200) { return , $response.Content }
        if ($status -eq 401 -and $oauth -and $attempt -eq 1) { continue }
        if ($status -ge 300 -and $status -lt 400) { throw (New-UDPivotError -Id PivotRedirectRefused -Category SecurityError -Data @{ Status = $status } -Message ('pivotkit-server {0} answered with a redirect ({1}); it is not followed, so the token stays with this server: use the address it names in -Uri.' -f $where, $status)) }
        $problem = $null
        try { $problem = ConvertFrom-Json -InputObject ([System.Text.Encoding]::UTF8.GetString($response.Content)) -Depth 16 } catch { $problem = $null }
        # a problem document (RFC 9457) is an object; anything else (an empty body, a proxy's page) has no members to read
        if ($problem -isnot [System.Management.Automation.PSCustomObject]) { $problem = $null }
        $code = if ($problem -and $problem.code) { [string]$problem.code } else { 'HTTP {0}' -f $status }
        # detail; the answer of a handler that crashed has only "error" (pivotkit-server's 500)
        $detail = if ($problem -and $problem.detail) { [string]$problem.detail } elseif ($problem -and $problem.error -is [string] -and $problem.error) { $problem.error }
        # the body's id, else the header's: the listener's own 400, a proxy's answer
        $requestId = if ($problem -and $problem.requestId) { [string]$problem.requestId } elseif ($response.Headers['X-Request-Id']) { [string]$response.Headers['X-Request-Id'] }
        # whether the same request may work later, where the server said so
        $retryable = if ($problem -and $problem.retryable -is [bool]) { $problem.retryable }
        $message = 'pivotkit-server {0}: {1} ({2})' -f $where, $code, $status
        if ($detail) { $message += ': {0}' -f $detail }
        $findings = @(Get-UDPivotFindingText -Finding @($problem.findings))
        if ($findings.Count) { $message += [Environment]::NewLine + ($findings -join [Environment]::NewLine) }
        $retryAfter = $response.Headers['Retry-After']
        $retryText = Get-UDPivotRetryText -RetryAfter $retryAfter
        if (-not $retryText -and $retryable) { $retryText = 'Trying again may work.' }
        if ($retryText) { $message += [Environment]::NewLine + $retryText }
        if ($status -eq 401) { $message += [Environment]::NewLine + 'Check the token: the server did not accept it.' }
        if ($status -eq 413) {
            $message += [Environment]::NewLine + $(if ($code -eq 'LIMIT_EXCEEDED') { 'The report is over a limit of the server (rows, cells or memory): make the view smaller or filter the data.' }
                else { 'The data is too large for the server: send fewer rows or columns, or let the operator configure a source for it and use -Source.' })
        }
        # pivotkit-server 0.1.1 knows neither data in the request nor params; its answer reads like a
        # fault in the request (#129). 0.2.0 answers params the same way for a source without parameters.
        if ($status -eq 400 -and $code -eq 'INVALID_INPUT' -and $detail -match 'no key "(data|params)"') {
            $message += [Environment]::NewLine + $(if ($Matches[1] -eq 'data') { '-Data needs pivotkit-server 0.2.0 or later; an older server renders only -Source.' }
                else { '-Parameter needs a source with parameters on pivotkit-server 0.2.0 or later.' })
        }
        $scopeMissing = $status -eq 403 -and $code -eq 'INSUFFICIENT_SCOPE'
        if ($scopeMissing) { $message += [Environment]::NewLine + 'The token lacks a scope the server needs: ask the token endpoint for it with -Scope (the scope the operator set in rest.requiredScopes, for example pivotkit:rest), and make sure the OAuth provider grants it to this client.' }
        if ($requestId) { $message += [Environment]::NewLine + ('Request id for the operator: {0}' -f $requestId) }
        $id = if ($scopeMissing) { 'PivotTokenRefused' } else { switch ($status) { 401 { 'PivotTokenRefused' } 413 { 'PivotDataTooLarge' } 422 { 'PivotViewHasErrors' } default { 'PivotServerError' } } }
        $category = switch ($status) { 401 { 'AuthenticationError' } 403 { 'PermissionDenied' } 413 { 'LimitsExceeded' } 422 { 'InvalidData' } default { 'InvalidResult' } }
        throw (New-UDPivotError -Id $id -Category $category -Message $message -Data @{
                Status = $status; Code = $code; RetryAfter = if ($retryAfter) { [string]$retryAfter }; Retryable = $retryable; RequestId = $requestId
            })
    }
}

function Invoke-UDPivotReport {
    <#
    .SYNOPSIS
        Renders a pivot report without a browser - an Excel workbook, an HTML report, CSV, JSON or the
        chart as SVG - from data PowerShell already has, with pivotkit's command line (Node) or a
        pivotkit-server (REST).
    .DESCRIPTION
        For endpoints, scheduled scripts and jobs: the same view a reader builds in New-UDPivotReport
        (Views, Download view, or Get-UDElement's .view) runs over the rows and becomes a file.

        -Engine Node runs pivotkit's command line on the PSU server (npm install --global pivotkit-cli,
        Node 22 or later, pivotkit-cli 0.2.1 or later): the rows go into a temporary JSON file in a folder of its own that only this
        user can read, pivotkit reads and writes only there (--allow-dir), and the folder is removed
        afterwards, also on an error.

        -Engine Rest calls a pivotkit-server (POST /api/v1/views/render/file). The rows go in the request
        (source "inline:", pivotkit's data in the request): nothing has to be put on the server first.
        The server's operator turns this on per caller (a profile with data: true, or policy.data) and
        caps the body (rest.data.maxBytes, default 10 MiB). With -Source instead of -Data the report
        runs over a source the operator configured (the caller needs results: true). -Data and
        -Parameter need pivotkit-server 0.2.0 or later; pivotkit-server 0.1.1 renders -Source without
        parameters, and the error of its answer to -Data or -Parameter says so. Sign-in: a static
        token (-Token), or OAuth client credentials (-Credential with -TokenUri), the access token kept
        per runspace until shortly before it expires and fetched again once after a 401. Only https, or
        http to this machine; redirects are not followed; neither the token nor the client secret is
        ever written to an error, a log or the output.

        A view with errors writes nothing: the error lists pivotkit's findings (the field it did not
        find, the name it probably meant). Warnings of the command line go to the warning stream.

        Every failure has a fixed error id ($_.FullyQualifiedErrorId): PivotServerUnreachable,
        PivotRedirectRefused, PivotTokenRefused, PivotDataTooLarge (over -MaxBytes, or the server's 413:
        BODY_TOO_LARGE for a request over its cap, also when the server answers it while the request is
        still being sent; LIMIT_EXCEEDED for a report over a limit of the server), PivotViewHasErrors,
        PivotServerError (any other answer, 400 and 404 included), PivotCliNotFound, PivotCliFailed.
        $_.Exception.Data holds Status, Code, RetryAfter, Retryable and RequestId where the server sent
        them; the message says when to try again or that trying again may work.
    .PARAMETER Data
        The rows: a DataTable (Invoke-Sqlcmd), DataRows, objects, hashtables or a script block, as
        New-UDPivotReport takes them. Dates are sent as ISO 8601 text and read as dates; DBNull is empty.
    .PARAMETER Source
        -Engine Rest: the id of a source the server's operator configured, instead of -Data.
    .PARAMETER Parameter
        -Engine Rest with -Source: the values of the source's parameters (@{ customer = 'acme' }).
    .PARAMETER View
        The view: a hashtable, JSON text, or a view file (pivotkit's Views, Download view) as JSON text or
        object. Checked like every view (ConvertFrom-UDPivotViewFile); its name is the default title.
    .PARAMETER Layout
        Instead of -View, the view by field names, as pivotkit's layout flags take it:
        @{ rows = 'Team'; cols = 'Priority'; values = @{ field = 'Hours'; agg = 'sum' };
        groups = @{ field = 'Created'; by = 'yearMonth' }; filters = @(...); chart = 'bar';
        map = @{ Revenue = 'Turnover' } }.
    .PARAMETER Format
        xlsx (Excel), html (a report to read or print), csv, json or svg (the chart). Default: the
        extension of -OutFile, else xlsx.
    .PARAMETER OutFile
        Write the file here and return it as a FileInfo. Without it the function returns the file's bytes
        (System.Byte[]), for an endpoint's answer or a mail attachment. A file that is there is replaced,
        and a symbolic link is followed to its target: give a path of your script's, never one from a
        reader, a request or other input.
    .PARAMETER Title
        The report's title in the workbook and the HTML report (default: the view's name).
    .PARAMETER Engine
        Node (pivotkit's command line on this server) or Rest (a pivotkit-server).
    .PARAMETER CliPath
        -Engine Node: the pivotkit program, or pivotkit-cli's bin/pivotkit.js. Default: pivotkit on the
        PATH.
    .PARAMETER Locale
        -Engine Node: numbers, dates and the report's words (de-DE writes German ones). Default en-US.
    .PARAMETER TimeZone
        -Engine Node: the zone of the data's dates (IANA, default UTC).
    .PARAMETER Uri
        -Engine Rest: the REST service's address, https://reports.example.com/api/v1. An address with a user
        name or password, a query string (?...) or a fragment (#...) in it is refused.
    .PARAMETER Token
        -Engine Rest: a static token, as a string or SecureString - a PSU secret ($Secret:PivotkitToken).
    .PARAMETER Credential
        -Engine Rest: OAuth client credentials, the client id as user name and the client secret as
        password - a PSU secret of type PSCredential ($Secret:PivotkitClient). Needs -TokenUri.
    .PARAMETER TokenUri
        The OAuth provider's token endpoint (Authentik: https://<authentik>/application/o/token/).
    .PARAMETER Scope
        Scopes to ask the provider for: the REST scope the operator set (rest.requiredScopes), e.g.
        pivotkit:rest. Without it the server answers 403 INSUFFICIENT_SCOPE (PivotTokenRefused).
    .PARAMETER Audience
        The audience parameter some providers want for the access token (Auth0).
    .PARAMETER Resource
        RFC 8707's resource parameter: the REST service's address, for providers that issue tokens per
        resource.
    .PARAMETER ClientAuthentication
        How the client authenticates at the token endpoint: Post (client_secret_post, the default) or
        Basic (client_secret_basic).
    .PARAMETER DataName
        -Engine Rest with -Data: what the data is, the report's name when it has no title.
    .PARAMETER DataAsOf
        -Engine Rest with -Data: when the data is from, sent as the data's asOf. The server keeps it with
        the request (its answer's suppliedAsOf); the file's own "Data as of" is when the data arrived.
    .PARAMETER MaxBytes
        -Engine Rest with -Data: the most bytes the request may carry, default 10 MiB (pivotkit-server's
        default rest.data.maxBytes; raise it to what the operator set, at most 64 MiB). The rows are
        written into the request one by one and checked every 256 rows: the function stops with
        PivotDataTooLarge at most 255 rows after they pass it, before the rest is converted and before
        anything is sent. Rows that are no DataTable and no list of PSCustomObjects (hashtables, a mix)
        are converted in full first.
    .PARAMETER TimeoutSec
        The longest a run may take, in seconds. Default 120. -Engine Node: the command line's run.
        -Engine Rest: each call as a whole, from sending the request to the last byte of the answer
        (the report is read in full before it is returned); the token request with -Credential has
        its own limit of the same length.
    .PARAMETER WhatIf
        With -OutFile: says which file would be written and runs nothing.
    .PARAMETER Confirm
        With -OutFile: asks before the file is written.
    .EXAMPLE
        # a scheduled script: tickets per team as an Excel workbook, with the view a reader saved
        $view = Get-Content -LiteralPath (Join-Path $Repository 'views' 'tickets-per-team.pivotkit.json') -Raw
        Invoke-UDPivotReport -Engine Node -Data (Invoke-Sqlcmd -Query 'SELECT * FROM Tickets') -View $view -OutFile '/reports/tickets.xlsx'
    .EXAMPLE
        # an endpoint that answers with an HTML report, made by a pivotkit-server
        New-PSUEndpoint -Url '/reports/tickets' -Endpoint {
            Import-Module PowerShellUniversal.Component.Pivot
            $bytes = Invoke-UDPivotReport -Engine Rest -Uri 'https://reports.example.com/api/v1' -Token $Secret:PivotkitToken `
                -Data (Get-Ticket) -Layout @{ rows = 'Team'; values = @{ field = 'Id'; agg = 'count' } } -Format html
            New-PSUApiResponse -Data $bytes -ContentType 'text/html; charset=utf-8'
        }
    .EXAMPLE
        # OAuth client credentials from Authentik; the token is reused until it expires
        Invoke-UDPivotReport -Engine Rest -Uri 'https://reports.example.com/api/v1' -Credential $Secret:PivotkitClient `
            -TokenUri 'https://login.example.com/application/o/token/' -Scope 'pivotkit:rest' -Source 'sales' -View $view -OutFile ./sales.xlsx
    .OUTPUTS
        System.IO.FileInfo with -OutFile, else System.Byte[].
    .LINK
        https://powershell-universal-components.eize.dev/pivot/reports/
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'View')]
    [OutputType([System.IO.FileInfo], [byte[]])]
    param(
        [AllowNull()][object]$Data,
        [ValidateLength(1, 1024)][ValidatePattern('^(?!file:|inline:)')][string]$Source,
        [System.Collections.IDictionary]$Parameter,
        [Parameter(Mandatory, ParameterSetName = 'View')][AllowNull()][object]$View,
        [Parameter(Mandatory, ParameterSetName = 'Layout')][System.Collections.IDictionary]$Layout,
        [ValidateSet('xlsx', 'html', 'csv', 'json', 'svg')][string]$Format,
        [ValidateNotNullOrEmpty()][string]$OutFile,
        [ValidateLength(1, 200)][string]$Title,
        [Parameter(Mandatory)][ValidateSet('Node', 'Rest')][string]$Engine,
        [string]$CliPath,
        [ValidateScript({ $_ -match $Script:LocalePattern }, ErrorMessage = 'Locale "{0}": expected a language tag such as en-US or de-DE.')][string]$Locale,
        [ValidatePattern('^(UTC|[A-Za-z_]+(/[A-Za-z0-9_+-]+){1,2})$')][string]$TimeZone,
        [uri]$Uri,
        [AllowNull()][object]$Token,
        [pscredential]$Credential,
        [uri]$TokenUri,
        [ValidateNotNullOrEmpty()][string[]]$Scope,
        [ValidateNotNullOrEmpty()][string]$Audience,
        [ValidateNotNullOrEmpty()][string]$Resource,
        [ValidateSet('Post', 'Basic')][string]$ClientAuthentication = 'Post',
        [ValidateLength(1, 200)][string]$DataName,
        [Nullable[datetime]]$DataAsOf,
        [ValidateRange(1KB, 64MB)][long]$MaxBytes = 10MB,
        [ValidateRange(1, 3600)][int]$TimeoutSec = $Script:ReportTimeoutSec
    )

    #region What goes with which engine
    # the parameters given of a list, as "-Name" (the function's own bound parameters, not the script block's)
    $bound = $PSBoundParameters
    $given = { param($Names) @($Names | Where-Object { $bound.ContainsKey($_) } | ForEach-Object { "-$_" }) }
    $hasData = $PSBoundParameters.ContainsKey('Data')
    if ($Engine -eq 'Node') {
        $wrong = & $given 'Source', 'Parameter', 'Uri', 'Token', 'Credential', 'TokenUri', 'Scope', 'Audience', 'Resource', 'ClientAuthentication', 'DataName', 'DataAsOf', 'MaxBytes'
        if ($wrong.Count) { throw ('{0}: only with -Engine Rest.' -f ($wrong -join ', ')) }
        if (-not $hasData) { throw '-Engine Node needs -Data: the command line runs over the rows you give.' }
    }
    else {
        $wrong = & $given 'CliPath', 'Locale', 'TimeZone'
        if ($wrong.Count) { throw ('{0}: only with -Engine Node (pivotkit-server uses its own).' -f ($wrong -join ', ')) }
        if (-not $Uri) { throw '-Engine Rest needs -Uri, the REST service''s address (https://reports.example.com/api/v1).' }
        if (-not $Uri.IsAbsoluteUri -or $Uri.UserInfo) { throw '-Uri: an absolute address without a user name or password in it (the token goes in its own header).' }
        # the routes are appended to the path: a query or a fragment would be lost on the way, so it is refused
        if ($Uri.Query -or $Uri.Fragment) { throw '-Uri: the REST service''s address without a query string or fragment (https://reports.example.com/api/v1).' }
        if (-not (Test-UDPivotLoopbackUri -Uri $Uri)) { throw ('-Uri {0}: an https address (http only for this machine), so the token is never sent in clear text.' -f (Get-UDPivotSafeAddress -Uri $Uri)) }
        if ($hasData -eq [bool]$Source) { throw '-Engine Rest needs either -Data (rows sent with the request) or -Source (a source the operator configured).' }
        if ($Parameter -and -not $Source) { throw '-Parameter goes with -Source.' }
        if (($DataName -or $DataAsOf -or $PSBoundParameters.ContainsKey('MaxBytes')) -and -not $hasData) { throw '-DataName, -DataAsOf and -MaxBytes go with -Data.' }
        if ($PSBoundParameters.ContainsKey('Token') -eq [bool]$Credential) { throw '-Engine Rest needs either -Token (a static token) or -Credential with -TokenUri (OAuth client credentials).' }
        if ($Credential -and -not $TokenUri) { throw '-Credential needs -TokenUri, the token endpoint of the OAuth provider.' }
        if ($TokenUri -and (-not $TokenUri.IsAbsoluteUri -or $TokenUri.UserInfo)) { throw '-TokenUri: an absolute address without a user name or password in it.' }
        $oauthOnly = & $given 'TokenUri', 'Scope', 'Audience', 'Resource', 'ClientAuthentication'
        if (-not $Credential -and $oauthOnly.Count) { throw ('{0}: only with -Credential (OAuth client credentials).' -f ($oauthOnly -join ', ')) }
    }
    #endregion

    #region The format, the view and the data
    $target = if ($OutFile) { $PSCmdlet.GetUnresolvedProviderPathFromPSPath($OutFile) }
    $named = if ($target) { $Script:ReportExtensions[[System.IO.Path]::GetExtension($target).ToLowerInvariant()] }
    if ($Format -and $named -and $named -ne $Format) { throw ('-OutFile names a {0} file, -Format {1}: give one or make them agree.' -f $named, $Format) }
    $kind = if ($Format) { $Format } elseif ($named) { $named } else { 'xlsx' }
    $viewFile = $null
    $layoutIn = $null
    if ($PSCmdlet.ParameterSetName -eq 'View') {
        try { $viewFile = ConvertFrom-UDPivotViewFile -InputObject $View -Name 'Pivot report' }
        catch { throw ('-View: {0}' -f $_.Exception.Message) }
    }
    else {
        $layoutIn = ConvertTo-UDPivotReportLayout -Layout $Layout
    }
    $reportTitle = if ($Title) { $Title } elseif ($viewFile -and $viewFile.Name -ne 'Pivot report') { $viewFile.Name }
    #endregion

    if ($target -and -not $PSCmdlet.ShouldProcess($target, ('Write a pivot report ({0})' -f $kind))) { return }

    if ($Engine -eq 'Rest') {
        # splatted: a $(...) around -Data would enumerate a DataTable into its rows
        $bodyArgs = @{ Source = $Source; Parameter = $Parameter; Layout = $layoutIn; Format = $kind; Title = $reportTitle; DataName = $DataName; DataAsOf = $DataAsOf }
        if ($hasData) { $bodyArgs['Data'] = $Data; $bodyArgs['MaxBytes'] = $MaxBytes }
        if ($viewFile) { $bodyArgs['View'] = $viewFile.View }
        $body = New-UDPivotRenderBody @bodyArgs
        $auth = if ($Credential) {
            @{ Credential = $Credential; TokenUri = $TokenUri; Scope = $Scope; Audience = $Audience; Resource = $Resource; ClientAuthentication = $ClientAuthentication; TimeoutSec = $TimeoutSec }
        }
        else { @{ Token = $Token } }
        $bytes = Invoke-UDPivotRestRender -Uri $Uri -Body $body -Auth $auth -TimeoutSec $TimeoutSec
    }
    else {
        $command = Get-UDPivotCliCommand -CliPath $CliPath
        # a folder of its own that only this user may read: the rows are the app's data
        $work = Join-Path ([System.IO.Path]::GetTempPath()) ('pivotkit-' + [guid]::NewGuid().ToString('N'))
        if ($IsWindows) { [void][System.IO.Directory]::CreateDirectory($work) }
        else { [void][System.IO.Directory]::CreateDirectory($work, [System.IO.UnixFileMode]'UserRead, UserWrite, UserExecute') }
        try {
            $dataPath = Join-Path $work 'data.json'
            $outPath = Join-Path $work ('report.{0}' -f $kind)
            # the rows straight into the file, { columns, rows }, as pivotkit's JSON reader takes them
            $file = [System.IO.File]::Create($dataPath)
            try {
                $writer = New-UDPivotJsonWriter -Stream $file
                $writer.WriteStartObject()
                Write-UDPivotReportTable -Writer $writer -Data $Data
                $writer.WriteEndObject()
                $writer.Flush()
                $writer.Dispose()
            }
            finally { $file.Dispose() }
            $arguments = [System.Collections.Generic.List[string]]::new()
            $arguments.Add('render')
            if ($viewFile) {
                $viewPath = Join-Path $work 'view.pivotkit.json'
                $viewJson = ConvertTo-UDPivotViewFile -View $viewFile.View -Name $viewFile.Name -SourceId ([string]$viewFile.Source.id)
                [System.IO.File]::WriteAllText($viewPath, $viewJson, [System.Text.UTF8Encoding]::new($false))
                $arguments.AddRange([string[]]@($viewPath, ('--data=' + $dataPath)))
            }
            else {
                $arguments.Add($dataPath)
                $arguments.AddRange([string[]]@(Get-UDPivotLayoutArgument -Layout $layoutIn))
            }
            # every value as --option=value: a value may start with a dash
            $arguments.AddRange([string[]]@(('--format=' + $kind), ('--output=' + $outPath), '--json', '--quiet', ('--allow-dir=' + $work)))
            if ($reportTitle) { $arguments.Add('--title=' + $reportTitle) }
            if ($Locale) { $arguments.Add('--locale=' + $Locale) }
            if ($TimeZone) { $arguments.Add('--time-zone=' + $TimeZone) }
            $answer = Invoke-UDPivotCli -Command $command -Argument $arguments.ToArray() -TimeoutSec $TimeoutSec
            $findings = @($answer.findings | Where-Object { $_ -and $_.severity -ne 'info' })
            if (-not $answer.ok) {
                $lines = @(Get-UDPivotFindingText -Finding @($findings | Where-Object severity -EQ 'error'))
                if ($answer.error) { $lines += '{0} {1}: {2}' -f $answer.error.kind, $answer.error.code, $answer.error.message }
                $id = if ($answer.exitCode -eq 1) { 'PivotViewHasErrors' } else { 'PivotCliFailed' }
                throw (New-UDPivotError -Id $id -Category InvalidData -Data @{ Code = if ($answer.error) { [string]$answer.error.code } } -Message ('pivotkit''s command line wrote no report (exit {0}):{1}{2}' -f $answer.exitCode, [Environment]::NewLine, ($lines -join [Environment]::NewLine)))
            }
            foreach ($line in @(Get-UDPivotFindingText -Finding @($findings | Where-Object severity -EQ 'warning'))) { Write-Warning ('pivotkit: {0}' -f $line) }
            if (-not (Test-Path -LiteralPath $outPath -PathType Leaf)) { throw (New-UDPivotError -Id PivotCliFailed -Message 'pivotkit''s command line said it wrote the report, but the file is not there.') }
            $bytes = [System.IO.File]::ReadAllBytes($outPath)
        }
        finally {
            # a file the command line still holds open (Windows) must not hide the report's own error
            Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    if ($target) {
        [System.IO.File]::WriteAllBytes($target, $bytes)
        return Get-Item -LiteralPath $target
    }
    , $bytes
}
#endregion

Export-ModuleMember -Function New-UDPivotReport, New-UDPivotReportPlaceholder, ConvertFrom-UDPivotView, ConvertFrom-UDPivotViewFile, ConvertTo-UDPivotViewFile, New-UDPivotFileTemplateStore, New-UDPivotTemplateStore, Invoke-UDPivotTemplateRequest, Get-UDPivotSqlColumnDescription, Invoke-UDPivotReport
