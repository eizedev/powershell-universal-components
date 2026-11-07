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
        hint where to start.
    .PARAMETER Templates
        Views offered in the Templates menu (the first three also on the empty report): a list of
        @{ Name = 'Tickets per team'; View = <view>; Deletable = $false }. Deletable entries get a delete
        button when -OnDeleteTemplate is set.
    .PARAMETER FieldDefaults
        Aggregator and format a field gets when the reader puts it into Values, per field name:
        @{ LeadHours = @{ Agg = 'average'; Format = 'number:1' }; Revenue = @{ Format = 'currency:EUR' } }.
        Format names: number, number:2, integer, percent, percent:1, currency:EUR, compact, bytes,
        duration:s, duration:h, date, datetime, time.
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
        [AllowEmptyCollection()][object[]]$Templates,
        [hashtable]$FieldDefaults,
        [hashtable]$Labels,
        [ValidateScript({ $_ -match $Script:LocalePattern }, ErrorMessage = 'Locale "{0}": expected a language tag such as en-US or de-DE.')][string]$Locale = 'en-US',
        [ValidatePattern('^(UTC|[A-Za-z_]+(/[A-Za-z0-9_+-]+){1,2})$')][string]$TimeZone = (Get-UDPivotTimeZone),
        [ValidateSet('Auto', 'Light', 'Dark')][string]$Theme = 'Auto',
        [ValidateScript({ $_ -match $Script:HeightPattern }, ErrorMessage = 'Height "{0}": expected a CSS length such as 640px, 80vh or 640.')][string]$Height,
        [ValidateLength(1, 120)][string]$FileName = 'pivot',
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
    }
    if ($PSBoundParameters.ContainsKey('View') -and $null -ne $View) {
        try { $props['view'] = ConvertFrom-UDPivotView -InputObject $View }
        catch { throw ('-View: {0}' -f $_.Exception.Message) }
    }
    if ($PSBoundParameters.ContainsKey('Templates')) { $props['templates'] = @(ConvertTo-UDPivotTemplate -Template $Templates) }
    if ($FieldDefaults) {
        foreach ($field in $FieldDefaults.Keys) {
            $entry = $FieldDefaults[$field]
            if ($entry -isnot [System.Collections.IDictionary]) { throw ('-FieldDefaults, "{0}": expected @{{ Agg = ...; Format = ... }}.' -f $field) }
            foreach ($key in $entry.Keys) {
                if ([string]$key -notin 'Agg', 'Format' -or $entry[$key] -isnot [string] -or $entry[$key] -notmatch '^[A-Za-z0-9:._%-]{1,64}$') {
                    throw ('-FieldDefaults, "{0}": only Agg and Format, each a name such as average or number:1.' -f $field)
                }
            }
        }
        $props['fieldDefaults'] = $FieldDefaults
    }
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

        The placeholder comes with the page and shows the field list, the toolbar, the four zones and a
        few table rows as grey bars, in the report's colours (light, dark, a corporate design from the
        app's stylesheet) and its layout for the width; the bars pulse unless the reader asked for
        reduced motion. Screen readers hear "Loading report". It also makes the browser load the
        module's code at once, while the server is still working on the data.

        Give it the -Height, -Theme and -Locale of the report, so nothing moves when the report replaces it.
    .PARAMETER Id
        Component id. Default: a new GUID.
    .PARAMETER Height
        Height, as -Height of New-UDPivotReport (e.g. 640px, 80vh or 640). Default: the report's default
        height.
    .PARAMETER Theme
        Auto (follows the app's light/dark switch, default), Light or Dark.
    .PARAMETER Locale
        The language of the text screen readers hear: German for de-*, English otherwise. Default: en-US.
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
    if ($ClassName) { $props['className'] = $ClassName }
    if ($Style) { $props['style'] = $Style }
    $props
}

Export-ModuleMember -Function New-UDPivotReport, New-UDPivotReportPlaceholder, ConvertFrom-UDPivotView
