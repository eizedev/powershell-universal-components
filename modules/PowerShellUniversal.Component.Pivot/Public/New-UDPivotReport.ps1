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
        table or chart (bars, lines, area, pie, heatmap, bars and lines, treemap), a click on a value opens the rows behind it,
        undo and redo, templates, Excel (XLSX), CSV, PNG, SVG and HTML export and print. All of it runs in the browser
        (pivotkit); the server is only asked for what the event parameters do.

        A view - what the report shows - is plain JSON that pivotkit checks against the data; it never
        runs as code. -View sets the start view, -Templates the views offered in the Views menu,
        -TemplatePath reads view files from folders, and -TemplateStore keeps readers' own views and the
        shared ones (New-UDPivotFileTemplateStore, New-UDPivotTemplateStore) with -AdminRole for who may
        change shared views; -OnSaveTemplate and -OnDeleteTemplate stay for full control. Field names are
        matched without regard to case.

        Instead of -Data, -Uri -Source -Token show the rows of a pivotkit-server source for the signed-in
        person: PowerShell fetches them from the server's rows route (POST /sources/records) with the
        person's token, $AccessToken of PSU's OpenID Connect sign-in, and hands the server's answer to the
        report as text, never as PowerShell objects; the browser makes no request to the server. A link
        opens with its parameters from the page's query string, as far as the server lists them in the
        source's linkParams. An answer the server refuses is an error with a fixed id (PivotTokenRefused,
        PivotRowsNotAllowed, PivotNoData, PivotDataTooLarge, PivotServerBusy, PivotServerError): the report
        tells the reader in plain words, and the operator's message with the id goes to the warning
        stream, the app's log (PSU would show an error to the reader as a toast). With -ErrorAction or
        -ErrorVariable the error itself goes to the error stream; -ErrorAction Stop throws it. https://powershell-universal-components.eize.dev/pivot/server-rows/
    .PARAMETER Id
        Component id. Default: a new GUID. Get-UDElement -Id returns the current view as .view (and
        the id, not the rows);
        Set-UDElement -Id -Properties @{ view = ... } shows another view (one undo step). The browser
        tab keeps the reader's view under this id; without -Id the report is identified by its page,
        its place in the app script (line and column of the call) and its column names. Set -Id when
        one call builds several reports (a loop) or reports are added or removed at run time.
    .PARAMETER Data
        Rows: a DataTable (Invoke-Sqlcmd, SqlClient, ODBC), DataRows, PSCustomObjects, hashtables or a
        script block returning them. DBNull becomes an empty value, dates stay dates, TimeSpans become
        seconds. The column names are the field names the reader sees.
    .PARAMETER Uri
        Instead of -Data: the REST service of a pivotkit-server, https://reports.example.com/api/v1 (https;
        http only on this machine). Needs -Source and -Token.
    .PARAMETER Source
        With -Uri: the id of the server's source (Get-UDPivotSource lists them; Records says whether the
        person may read its rows). It is also the report's -SourceId unless that is given, so a link the
        server made for the source opens here.
    .PARAMETER Token
        With -Uri: the signed-in person's access token, $AccessToken of PSU's OpenID Connect sign-in
        (Authentication__OIDC__SaveTokens=true; on app pages and in New-UDDynamic, not in API endpoints).
        The server hands rows only to a person: a static token or OAuth client credentials get no rows.
        Never sent to the browser.
    .PARAMETER Parameter
        With -Uri: the source's parameters, @{ customer = 'acme' }, sent as they are. Without it the
        report takes the values of the page's query string (-Query) whose names the server lists in the
        source's linkParams.
    .PARAMETER Query
        With -Uri: the page's query string. Default: $Query of the page. Pass $Query where the call runs
        in a script block or function defined in the app script.
    .PARAMETER MaxBytes
        With -Uri: the most bytes of the server's answer the report takes, default 32 MB, at most 64 MB
        (the largest text measured through PSU to the browser). A larger answer stops with
        PivotDataTooLarge before the rest is read.
    .PARAMETER TimeoutSec
        With -Uri: the longest the server may take to answer, in seconds. Default 120.
    .PARAMETER View
        The view the report starts with (and goes back to with Reset): a hashtable or JSON, e.g.
        @{ rows = @('Team'); cols = @('Priority'); values = @(@{ field = 'Id'; agg = 'count' }) }.
        Keys: version (2), rows, cols (field names), values (field, agg: sum, count, average, min, max,
        ...; format: a format name), filters (e.g. @{ field = 'Status'; type = 'in'; items = @('Open');
        blanks = 'exclude' }; a view without version is read as version 1 and migrated), sort, totals,
        display (table, chart or both), fieldLabels (names of the report's own for fields, e.g.
        @{ Cust = 'Customer' }), chart (type: bar, line, area, pie, donut, heatmap, combo, treemap). A saved template's view
        goes in as it is. Default: an empty report with the hint where to start. A view in the address bar (#pivot-<id>=..., written by the report on every
        change unless -NoAddressBar, so a copied link opens the same layout) wins over it. With -Uri also
        the name of a view the server publishes for the source, such as 'by-region': only the fields it
        uses leave the server, and the report starts with the view of a link, else empty (the server
        lists its views' names, not the views).
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
        The $schema of the view files the report writes: an https address of your own copy, a path on
        PSU such as /assets/pivot/schema/view-file-2.json, or '' to leave it out. The browser writes a
        path with the address the reader used; the template store with the origin of an https default,
        else of the event's request (ConvertTo-UDPivotViewFile). Default: the
        environment variable PSU_COMPONENT_PIVOT_SCHEMA_URL, else pivotkit's published schema. Loading
        never depends on it.
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
        The tips above the result: On (default), Off (none, and no switch in More, Help), or the ids of the
        tips allowed (showAs, colSubtotals, chartOverTime, pieSlices, stackedTotal, pieColumns, chartDates, chartTrend, chartSeries,
        textValue, dateUngrouped, manyColumns, afterDrag, values, saveTemplate, menus, cells; the
        notices filterEmpty, top and chartCapped always show). Dismissed tips are remembered per report
        in the browser's localStorage.
    .PARAMETER FieldInfo
        On or Off: the "i" with the field descriptions. Without it the reader switches it ("Show
        explanations" in More, Help).
    .PARAMETER ZoneInfo
        On or Off: the "i" next to the zone titles that explains each zone. Without it the reader
        switches it ("Show explanations" in More, Help).
    .PARAMETER SettingInfo
        On or Off: the "i" next to settings that need explaining (totals, Show as, export formats, chart
        labels). Without it the reader switches it ("Show explanations" in More, Help).
    .PARAMETER FieldList
        Open or Collapsed: how the field list starts on a wide report (collapsed: a rail of about 40
        pixels). Without it the reader's last choice decides.
    .PARAMETER Zones
        Open or Folded: how the zones (Rows, Columns, Values, Filters under "Fields in the report")
        start. Without it the report's height decides: below 600 pixels (820 in the narrow layout) they
        start folded into one line, and a report with no field placed starts with them open. Readers
        can still fold and open them. Open keeps them open in a low box too, where the table then gets
        little room: use it with a -Height of about 700 pixels or more.
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
        No panel with the source rows when a value is clicked or Show the rows is picked in a chart point's
        menu (-OnCellClick still runs; without it, Show the rows does nothing).
    .PARAMETER DrillDownExport
        Keeps the drill-down panel's Export menu (copy, Copy as JSON, CSV and Excel of the rows behind a
        clicked value, with every column) without -ExportData. Off by default: without -ExportData the
        panel shows the rows but has no Export menu. With -ExportData the menu is there anyway. The
        rows are in the browser either way; this only decides whether readers get a button to take
        them. Not with -NoDrillDown.
    .PARAMETER ExportData
        Adds Source data to the Export menu: every row of the data, before filters, grouping and totals,
        as a CSV or JSON file (pivotkit's exportData). Off by default. The report and its drill-down
        hand out different things: the report's own exports (Excel, Table as CSV, HTML, Print) hold the
        result the reader sees; the drill-down panel's Export menu, there with -ExportData (or
        -DrillDownExport alone), hands out up to 1,000 rows behind a clicked value, with every column;
        Source data hands out every row and every column of -Data,
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
        Runs on the server when the reader clicks a value in the table, or picks Show the rows in a chart
        point's menu (or double-clicks the point; a pie slice or a treemap tile never runs it). $EventData: row, col (the
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
        # the rows of a pivotkit-server source for the signed-in person; a link such as
        # /reports/vms?customer=acme#pivot-vms=1.... opens on that customer's rows
        New-UDPivotReport -Id 'vms' -Uri 'https://reports.example.com/api/v1' -Source 'vms' -Token $AccessToken
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
    [CmdletBinding(DefaultParameterSetName = 'Data')]
    [OutputType([hashtable])]
    param(
        [string]$Id = [guid]::NewGuid().ToString(),
        [Parameter(Mandatory, ParameterSetName = 'Data')][AllowNull()][object]$Data,
        [Parameter(Mandatory, ParameterSetName = 'Server')][uri]$Uri,
        [Parameter(Mandatory, ParameterSetName = 'Server')][ValidateLength(1, 256)][string]$Source,
        [Parameter(Mandatory, ParameterSetName = 'Server')][AllowNull()][AllowEmptyString()][object]$Token,
        [Parameter(ParameterSetName = 'Server')][Alias('Params')][System.Collections.IDictionary]$Parameter,
        [Parameter(ParameterSetName = 'Server')][AllowNull()][System.Collections.IDictionary]$Query,
        [Parameter(ParameterSetName = 'Server')][ValidateScript({ $_ -ge 1 -and $_ -le $Script:RecordsMaxBytesLimit }, ErrorMessage = '-MaxBytes {0}: from 1 to 64 MB (67108864), the largest text measured through PSU to the browser.')][long]$MaxBytes = $Script:RecordsMaxBytes,
        [Parameter(ParameterSetName = 'Server')][ValidateRange(1, 3600)][int]$TimeoutSec = $Script:ReportTimeoutSec,
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
        [AllowEmptyString()][string]$SchemaUrl,
        [System.Collections.IDictionary]$FieldDefaults,
        [System.Collections.IDictionary]$FieldDescriptions,
        [object]$Schema,
        [ValidateLength(1, 200)][string]$SchemaName,
        [object]$ChartOptions,
        [ValidateScript({ ($_ -in (@('On', 'Off') + $Script:TipIds)) -or $(throw ('Tips "{0}": expected On, Off or tip ids ({1}).' -f $_, ($Script:TipIds -join ', '))) })][string[]]$Tips,
        [ValidateSet('On', 'Off')][string]$FieldInfo,
        [ValidateSet('On', 'Off')][string]$ZoneInfo,
        [ValidateSet('On', 'Off')][string]$SettingInfo,
        [ValidateSet('Open', 'Collapsed')][string]$FieldList,
        [ValidateSet('Open', 'Folded')][string]$Zones,
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
        [switch]$DrillDownExport,
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
    # -ErrorVariable gets the error itself, not each step it took through the module
    $errorMark = Get-UDPivotErrorMark -Cmdlet $PSCmdlet
    trap { Reset-UDPivotErrorVariable -Mark $errorMark; throw $_ }

    if (-not $Script:AssetId) { throw $Script:MissingAssetMessage }
    if ($OnDataLoad -and -not $AllowImport) { throw '-OnDataLoad needs -AllowImport: without it the data shown never changes.' }
    if ($PSBoundParameters.ContainsKey('ImportLimit') -and -not $AllowImport) { throw '-ImportLimit needs -AllowImport: without it no file is loaded.' }
    if ($DrillDownExport -and $NoDrillDown) { throw '-DrillDownExport needs the drill-down: -NoDrillDown leaves no panel to copy or download from.' }
    if ($ExportDataColumn -and -not $ExportData) { throw '-ExportDataColumn needs -ExportData: naming columns never turns an export on by itself.' }
    $timer = [System.Diagnostics.Stopwatch]::StartNew()

    $fromServer = $PSCmdlet.ParameterSetName -eq 'Server'
    # with -Uri, a -View that is a name goes to the server; it is no view of its own
    $viewName = if ($fromServer -and $View -is [string] -and $View -match $Script:ViewNamePattern) { $View }
    $rows = $null
    $records = $null
    $problem = $null
    if ($fromServer) {
        $auth = Resolve-UDPivotRestSignIn -Bound @{ Uri = $Uri; Token = $Token } -TimeoutSec $TimeoutSec
        try {
            # no token: a visitor who is not signed in, or PSU's sign-in without SaveTokens. The reader is
            # asked to sign in; nothing is sent
            $empty = $null -eq $Token -or ($Token -is [string] -and $Token -eq '') -or ($Token -is [securestring] -and $Token.Length -eq 0)
            if ($empty) {
                throw (New-UDPivotError -Id PivotTokenRefused -Category AuthenticationError -Message '-Token is empty: no access token of the signed-in person. Pass $AccessToken on a page of an app with sign-in, and turn on Authentication__OIDC__SaveTokens in PSU, so PSU keeps the token.')
            }
            # a token of another type or with whitespace in it is the app's mistake: a plain error
            $null = ConvertTo-UDPivotPlainText -Secret $Token -Name '-Token'
            $sent = if ($PSBoundParameters.ContainsKey('Parameter')) { $Parameter } else {
                # $Query of the page, as $User below; a script block defined in the app script has none
                $pageQuery = if ($PSBoundParameters.ContainsKey('Query')) { $Query } else { $PSCmdlet.SessionState.PSVariable.GetValue('Query') }
                if ($pageQuery -is [System.Collections.IDictionary] -and $pageQuery.Count) { Get-UDPivotLinkParameter -Uri $Uri -Source $Source -Query $pageQuery -Auth $auth -TimeoutSec $TimeoutSec }
            }
            $records = Get-UDPivotRecordText -Uri $Uri -Source $Source -Parameter $sent -ViewName $viewName -Auth $auth -MaxBytes $MaxBytes -TimeoutSec $TimeoutSec
        }
        catch {
            if ($_.FullyQualifiedErrorId -notmatch '^Pivot[A-Za-z]+$') { throw }
            # the page still gets a report that tells the reader what happened. The operator's message
            # (the server's address and answer) goes to the warning stream, the app's log: PSU shows an
            # error of a page to the reader as a toast (measured on 2026.2.5 and 2026.3.4). A caller that
            # asks for the error (-ErrorAction, -ErrorVariable) gets it with its id; with Stop it throws
            # (the module's own preference is Stop, so the caller's choice decides here)
            $problem = ConvertTo-UDPivotReaderProblem -ErrorRecord $_
            Write-Warning ('{0}: {1}' -f ($_.FullyQualifiedErrorId -split ',')[0], $_.Exception.Message)
            if ($PSBoundParameters.ContainsKey('ErrorAction') -or $PSBoundParameters.ContainsKey('ErrorVariable')) {
                # -ErrorVariable holds this error once, not the module's steps on the way (#153)
                Reset-UDPivotErrorVariable -Mark $errorMark
                if ([string]$PSBoundParameters['ErrorAction'] -eq 'Stop') { throw $_ }
                if (-not $PSBoundParameters.ContainsKey('ErrorAction')) { $ErrorActionPreference = 'Continue' }
                $PSCmdlet.WriteError($_)
            }
        }
    }
    else {
        # one array (ConvertTo-PSUComponentData returns it as a single object; @() would nest it)
        $rows = ConvertTo-PSUComponentData -InputObject $Data
    }
    $convertMs = $timer.Elapsed.TotalMilliseconds
    $columnNames = if ($fromServer) { @(if ($records) { $records.Columns }) } else { @($rows | Select-Object -First 1 | ForEach-Object { $_.PSObject.Properties.Name }) }
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
    if ($records) {
        # the server's answer as it came: PSU passes a string on as it is, and the report parses it
        $props['records'] = $records.Text
    }
    elseif ($problem) { $props['problem'] = $problem }
    else { $props['data'] = $rows }
    if ($DrillDownExport) { $props['drillDownExport'] = $true }
    if ($ExportData) { $props['exportData'] = ConvertTo-UDPivotExportData -Column $ExportDataColumn -ColumnName $columnNames }
    if ($AllowImport) { $props['allowImport'] = $true }
    if ($PSBoundParameters.ContainsKey('ImportLimit') -and $null -ne $ImportLimit) {
        $limits = ConvertTo-UDPivotImportLimit -ImportLimit $ImportLimit
        if (@($limits.PSObject.Properties).Count) { $props['importLimits'] = $limits }
    }
    if ($PSBoundParameters.ContainsKey('View') -and $null -ne $View -and -not $viewName) {
        try { $props['view'] = ConvertFrom-UDPivotView -InputObject $View }
        catch { throw ('-View: {0}' -f $_.Exception.Message) }
    }
    if ($PSBoundParameters.ContainsKey('SavedView') -and $null -ne $SavedView) {
        # the reader's stored view is user data: a broken one must not break the page
        try { $props['savedView'] = ConvertFrom-UDPivotView -InputObject $SavedView }
        catch { Write-Warning ('-SavedView left out: {0}' -f $_.Exception.Message) }
    }
    # the data the view files and links name; a view made for another id asks before it is loaded
    $dataSource = [ordered]@{ id = if ($SourceId) { $SourceId } elseif ($fromServer) { $Source } else { $storageKey } }
    if ($SourceName) { $dataSource['name'] = $SourceName } elseif ($Label) { $dataSource['name'] = $Label }
    $props['source'] = [pscustomobject]$dataSource
    # -SchemaUrl, else the module-wide default; a path goes as it is, the browser adds its origin
    $schemaAddress = Get-UDPivotSchemaUrl -SchemaUrl $SchemaUrl -Given:$PSBoundParameters.ContainsKey('SchemaUrl')
    if ($null -ne $schemaAddress) { $props['schemaUrl'] = $schemaAddress }

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
                $storeViews[$scope] = @(foreach ($t in @(Invoke-UDPivotTemplateStore -Store $store -Action List -Scope $scope -UserName $user -SourceId $dataSource.id)) {
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
            if ($t.SourceId -and $t.SourceId -cne $dataSource.id) { continue }
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
            SourceId   = $dataSource.id
            SourceName = [string]$dataSource['name']
            SchemaUrl  = $schemaAddress
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
        # each id in pivotkit's spelling, whatever case it was given in
        $props['tips'] = if ($Tips.Count -eq 1 -and $Tips[0] -in 'On', 'Off') { $Tips[0].ToLowerInvariant() } else { @(foreach ($tip in $Tips) { $Script:TipIds | Where-Object { $_ -eq $tip } }) }
    }
    if ($FieldInfo) { $props['fieldInfo'] = $FieldInfo.ToLowerInvariant() }
    if ($ZoneInfo) { $props['zoneInfo'] = $ZoneInfo.ToLowerInvariant() }
    if ($SettingInfo) { $props['settingInfo'] = $SettingInfo.ToLowerInvariant() }
    if ($FieldList) { $props['fieldList'] = $FieldList.ToLowerInvariant() }
    if ($Zones) { $props['zones'] = $Zones.ToLowerInvariant() }
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
            rows      = if ($fromServer) { if ($records) { $records.RowCount } else { 0 } } else { @($rows).Count }
            columns   = $columnNames.Count
            convertMs = [math]::Round($convertMs, 1)
            serverMs  = [math]::Round($timer.Elapsed.TotalMilliseconds, 1)
            templates = $templateList.Count
            store     = if ($store) { $store.Kind } elseif ($props['templateStore']) { 'Browser' } else { $null }
        }
    }
    $props
}
