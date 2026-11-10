<#
    Showcase app of PowerShellUniversal.Component.Pivot, run by New-UDPivotShowcase.

    Nothing here is written twice: the pages on endoflife.date are the pivot examples of the
    documentation site (docs/site/examples.ps1), the ticket pages are the pivot module's
    examples/showcase.ps1, and the public data comes from the documentation's snapshots
    (docs/site/data); the built module carries copies of these files (Build.psd1). The examples call
    Invoke-RestMethod; here the call goes to Get-UDPivotShowcaseData, which answers from the snapshot
    or, with the page's "Live data" switch, from the API.

    The pages are built as text (one template for the language switch, the live switch and the
    attribution), since PSU runs a page's content as its own script block on the server.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Used in the page templates')]
param(
    [switch]$LiveData,
    [string]$Locale = 'en-GB'
)

$projectUri = (Import-PowerShellDataFile -LiteralPath (Join-Path $PSScriptRoot '..' 'PowerShellUniversal.Component.Pivot.Demo.psd1')).PrivateData.PSData.ProjectUri
$dataPath = Resolve-ShowcasePath -Path 'Data'
# the day of the snapshots, as Update-Data.ps1 writes it into SOURCES.md
$snapshotDay = [regex]::Match((Get-Content -LiteralPath (Join-Path $dataPath 'SOURCES.md') -Raw), '(?m)^Fetched on (\d{4}-\d{2}-\d{2})').Groups[1].Value
$sourcesLink = '[sources and licences]({0}/blob/HEAD/docs/site/data/SOURCES.md)' -f $projectUri

# text for a single-quoted PowerShell string
function ConvertTo-Quoted([string]$Text) { "'" + ($Text -replace "'", "''") + "'" }

# the attribution each source asks for (SOURCES.md), under the data it belongs to
$attribution = @{
    endoflife = 'Release data by [endoflife.date](https://endoflife.date/), MIT licence, Copyright 2020 endoflife.date contributors.'
    weather   = 'Weather data by [Open-Meteo.com](https://open-meteo.com/), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/); changed: daily values mapped to rows, sunshine in hours, city, season and rain day added. Contains modified Copernicus Climate Change Service information 2026. Neither the European Commission nor ECMWF is responsible for any use that may be made of the Copernicus information or data it contains. ERA5: [doi:10.24381/cds.adbb2d47](https://doi.org/10.24381/cds.adbb2d47), ERA5-Land: [doi:10.24381/cds.e2161bac](https://doi.org/10.24381/cds.e2161bac).'
}

#region Page template
# Placeholders: ID (element ids), TITLE, TEXT, LIVE (the page has public data), CODE (the report),
# ABOVE (elements between text and report), SOURCE (attribution), SHOWCODE (the example's code, or nothing). $locale and $live are set where
# the code runs; the inner New-UDDynamic is synchronised when the reader changes them.
$pageTemplate = @'
$locale = if ($Session:PivotShowcaseLocale) { $Session:PivotShowcaseLocale } else { <<LOCALE>> }
$live = if ($null -ne $Session:PivotShowcaseLive) { $Session:PivotShowcaseLive } else { $<<LIVEDEFAULT>> }
New-UDElement -Tag 'div' -Attributes @{ style = @{ display = 'flex'; flexWrap = 'wrap'; alignItems = 'center'; gap = '8px 16px'; marginBottom = '8px' } } -Content {
    New-UDTypography -Variant h5 -Text <<TITLE>> -Style @{ flex = '1 1 260px' }
    New-UDSelect -Id '<<ID>>-locale' -Label 'Language' -DefaultValue $locale -Option {
        New-UDSelectOption -Name 'English' -Value 'en-GB'
        New-UDSelectOption -Name 'Deutsch' -Value 'de-DE'
    } -OnChange {
        $Session:PivotShowcaseLocale = $EventData
        Sync-UDElement -Id '<<ID>>-content'
    }
    if ($<<LIVE>>) {
        # New-UDSwitch draws its label as a full-width grid: the wrapper keeps it as wide as the
        # switch and its text, so a click beside them does not toggle it
        New-UDElement -Tag 'div' -Attributes @{ style = @{ flex = '0 0 auto' } } -Content {
            New-UDSwitch -Id '<<ID>>-live' -Label 'Live data' -Checked $live -OnChange {
                $Session:PivotShowcaseLive = [bool]::Parse("$EventData")
                Sync-UDElement -Id '<<ID>>-content'
            }
        }
    }
}
New-UDTypography -Variant body2 -Text <<TEXT>> -Style @{ marginBottom = '12px' }
<<ABOVE>>
New-UDDynamic -Id '<<ID>>-content' -LoadingComponent {
    # the report's frame at once while the server reads the data (pages with public data)
    if ($<<LIVE>>) { New-UDPivotReportPlaceholder -Locale $(if ($Session:PivotShowcaseLocale) { $Session:PivotShowcaseLocale } else { <<LOCALE>> }) }
} -Content {
    $locale = if ($Session:PivotShowcaseLocale) { $Session:PivotShowcaseLocale } else { <<LOCALE>> }
    $live = if ($null -ne $Session:PivotShowcaseLive) { $Session:PivotShowcaseLive } else { $<<LIVEDEFAULT>> }
    try {
<<CODE>>
    }
    catch {
        # the details (addresses, paths) go to the server's log, never to the browser
        Write-Warning ('Pivot showcase, page <<ID>>: {0}' -f $_)
        New-UDAlert -Severity error -Text 'The data could not be loaded. The server log has the details.'
    }
    if (<<SOURCE>>) {
        $from = if (-not $<<LIVE>>) { '' } elseif ($live) { ' Fetched live from the API.' } else { <<SNAPSHOT>> }
        New-UDElement -Tag 'small' -Attributes @{ style = @{ display = 'block'; marginTop = '12px'; opacity = 0.8 } } -Content { New-UDMarkdown -Children (<<SOURCE>> + $from) }
    }
}
if (<<SHOWCODE>>) {
    New-UDExpansionPanelGroup -Children {
        New-UDExpansionPanel -Title 'Code of this example' -Children { New-UDMarkdown -Children ("``````powershell`n" + <<SHOWCODE>> + "`n``````") }
    }
}
'@

function New-ShowcasePage {
    # builds a page object for New-UDApp; changes no state
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param(
        [string]$Name, [string]$Url, [string]$Title, [string]$Text, [string]$Code,
        [string]$Source = '', [string]$ShowCode = '', [string]$Above = '', [switch]$PublicData
    )
    $id = $Url.Trim('/')
    $snapshot = ' Snapshot of {0} shipped with the module, {1}; switch on "Live data" to fetch it from the API.' -f $snapshotDay, $sourcesLink
    $text = $pageTemplate.Replace('<<CODE>>', $Code).Replace('<<ABOVE>>', $Above).Replace('<<ID>>', $id).Replace('<<TITLE>>', (ConvertTo-Quoted $Title)).
    Replace('<<TEXT>>', (ConvertTo-Quoted $Text)).Replace('<<LOCALE>>', (ConvertTo-Quoted $Locale)).Replace('<<LIVEDEFAULT>>', [string][bool]$LiveData).
    Replace('<<LIVE>>', [string][bool]$PublicData).Replace('<<SOURCE>>', (ConvertTo-Quoted $Source)).Replace('<<SNAPSHOT>>', (ConvertTo-Quoted $snapshot)).
    Replace('<<SHOWCODE>>', (ConvertTo-Quoted $ShowCode))
    New-UDPage -Name $Name -Url $Url -Content ([scriptblock]::Create($text))
}

# an example's code without the indentation of the file it is written in
function Format-Code([scriptblock]$Code) {
    $lines = $Code.ToString().TrimEnd().Trim("`r", "`n") -split '\r?\n'
    $indent = ($lines | Where-Object { $_.Trim() } | ForEach-Object { $_.Length - $_.TrimStart().Length } | Measure-Object -Minimum).Minimum
    ($lines | ForEach-Object { if ($_.Length -ge $indent) { $_.Substring($indent) } else { $_.TrimStart() } }) -join "`n"
}
#endregion

#region Pages from the documentation's examples (endoflife.date)
# the documentation's text marks parameters as code (`-View`); the page shows plain text
$docsPages = foreach ($example in & (Resolve-ShowcasePath -Path 'Apps/Docs/examples.ps1') | Where-Object { $_.Section -eq 'Pivot' -and $_.Source -and $_.App }) {
    $code = Format-Code $example.Code
    # the API call goes to the snapshot unless the reader switched on live data; the language follows the switch
    $run = ($code -replace '\bInvoke-RestMethod\b', 'Get-UDPivotShowcaseData -Live:$live') -replace '-Locale en-GB\b', '-Locale $locale'
    # the first example names no language: the switch sets it for New-UDPivotReport
    $run = '$PSDefaultParameterValues[''New-UDPivotReport:Locale''] = $locale' + "`n" + $run
    # the documentation's last sentence about its own page ("On this page ...") does not hold in PSU
    $text = $example.Text -replace '\s*On this page\b.*$', ''
    New-ShowcasePage -Name $example.App -Url ('/' + ($example.App.ToLowerInvariant() -replace '[^a-z0-9]+', '-')) -Title $example.Title `
        -Text $text -Code $run -Source $attribution.endoflife -ShowCode $code -PublicData
}
#endregion

#region Weather (Open-Meteo)
$weatherCode = @'
# daily weather of six cities, 2024 and 2025, in one call (one answer per city, in this order)
$cities = @(
    @{ City = 'Berlin'; Country = 'Germany'; Continent = 'Europe'; South = $false }
    @{ City = 'London'; Country = 'United Kingdom'; Continent = 'Europe'; South = $false }
    @{ City = 'Madrid'; Country = 'Spain'; Continent = 'Europe'; South = $false }
    @{ City = 'New York'; Country = 'United States'; Continent = 'North America'; South = $false }
    @{ City = 'Tokyo'; Country = 'Japan'; Continent = 'Asia'; South = $false }
    @{ City = 'Sydney'; Country = 'Australia'; Continent = 'Oceania'; South = $true }
)
$uri = 'https://archive-api.open-meteo.com/v1/archive?latitude=52.52,51.51,40.42,40.71,35.69,-33.87&longitude=13.41,-0.13,-3.70,-74.01,139.69,151.21&start_date=2024-01-01&end_date=2025-12-31&daily=temperature_2m_max,temperature_2m_min,temperature_2m_mean,precipitation_sum,sunshine_duration&timezone=auto'
$answers = Get-UDPivotShowcaseData -Live:$live $uri
$degree = [char]0x00B0
$seasons = 'Winter', 'Winter', 'Spring', 'Spring', 'Spring', 'Summer', 'Summer', 'Summer', 'Autumn', 'Autumn', 'Autumn', 'Winter'
$weather = for ($c = 0; $c -lt $cities.Count; $c++) {
    $city = $cities[$c]
    $daily = $answers[$c].daily
    for ($d = 0; $d -lt $daily.time.Count; $d++) {
        $date = [datetime]::ParseExact($daily.time[$d], 'yyyy-MM-dd', [cultureinfo]::InvariantCulture)
        # meteorological seasons, swapped south of the equator
        $month = if ($city.South) { ($date.Month + 5) % 12 } else { $date.Month - 1 }
        $rain = $daily.precipitation_sum[$d]
        [pscustomobject]@{
            City             = $city.City
            Country          = $city.Country
            Continent        = $city.Continent
            Date             = $date
            Season           = $seasons[$month]
            "Max $($degree)C"  = $daily.temperature_2m_max[$d]
            "Min $($degree)C"  = $daily.temperature_2m_min[$d]
            "Mean $($degree)C" = $daily.temperature_2m_mean[$d]
            'Rain mm'        = $rain
            'Rain day'       = [int]($rain -ge 1)
            'Sunshine h'     = if ($null -ne $daily.sunshine_duration[$d]) { [math]::Round($daily.sunshine_duration[$d] / 3600, 1) }
        }
    }
}
$monthly = @{
    derived = @(@{ name = 'Month'; field = 'Date'; by = 'month' })
    rows    = @('City'); cols = @('Month')
    values  = @(@{ field = "Mean $($degree)C"; agg = 'average'; format = 'number:1'; conditional = @{ type = 'colorScale'; colors = @('#5a8dee', '#e8554e') } })
}
New-UDPivotReport -Id 'weather' -Data $weather -Label 'Weather of six cities' -SourceName 'Weather' -Locale $locale -View $monthly -FieldDefaults @{
    "Max $($degree)C"  = @{ Agg = 'average'; Format = 'number:1' }
    "Min $($degree)C"  = @{ Agg = 'average'; Format = 'number:1' }
    "Mean $($degree)C" = @{ Agg = 'average'; Format = 'number:1' }
    'Sunshine h'     = @{ Agg = 'average'; Format = 'number:1'; Description = 'Hours of sunshine on the day.' }
    'Rain mm'        = @{ Agg = 'sum'; Format = 'number:0' }
    'Rain day'       = @{ Agg = 'sum'; Description = '1 for a day with at least 1 mm of rain.' }
    Season           = @{ Order = @('Spring', 'Summer', 'Autumn', 'Winter'); Description = 'Meteorological season; swapped south of the equator.' }
} -Templates @(
    @{ Name = 'How warm is each city, month by month?'; View = $monthly }
    @{ Name = 'Which city is the sunniest?'; View = @{
            rows = @('City'); values = @(@{ field = 'Sunshine h'; agg = 'average'; format = 'number:1' })
            sort = @(@{ field = 'City'; by = 'value'; order = 'desc' }); display = 'chart'; chart = @{ type = 'bar' }
        }
    }
    @{ Name = 'Rain days per season'; View = @{
            rows = @('City'); cols = @('Season'); values = @(@{ field = 'Rain day'; agg = 'sum' })
        }
    }
    @{ Name = 'Rain per month (line)'; View = @{
            derived = @(@{ name = 'Month'; field = 'Date'; by = 'yearMonth' })
            rows = @('Month'); cols = @('City'); values = @(@{ field = 'Rain mm'; agg = 'sum'; format = 'number:0' })
            display = 'chart'; chart = @{ type = 'line' }
        }
    }
)
'@
$weatherPage = New-ShowcasePage -Name 'Weather' -Url '/weather' -Title 'Weather of six cities, 2024 and 2025' -PublicData `
    -Text 'Daily weather from the Open-Meteo archive: one row per city and day. The start view averages the mean temperature per month; the Views menu has more questions to ask the data.' `
    -Code $weatherCode -Source $attribution.weather -ShowCode $weatherCode
#endregion

#region Upload (CSV and JSON, kept in memory for the session)
$uploadCode = @'
$upload = $Session:PivotShowcaseUpload
if ($Session:PivotShowcaseUploadError) {
    New-UDAlert -Severity error -Text $Session:PivotShowcaseUploadError
}
if ($upload) {
    New-UDTypography -Variant body2 -Text ('{0}: {1} rows, {2} columns' -f $upload.Name, $upload.Rows.Count, $upload.Columns) -Style @{ marginBottom = '8px' }
    New-UDPivotReport -Id 'upload' -Data $upload.Rows -Label $upload.Name -SourceId $upload.SourceId -SourceName $upload.Name -Locale $locale -NoAddressBar
}
'@
$uploadHandler = {
    # PSU writes the uploaded file to a temporary file on the server: read it, then delete it at once.
    # The limits are checked before the expensive steps, so a dense file cannot keep the runspace busy.
    # A refusal of the file is an InvalidDataException whose text the reader sees; anything else shows
    # a general message, and its details (paths on the server) go to the server's log only.
    $file = $EventData.FileName
    $Session:PivotShowcaseUploadError = $null
    try {
        $maxBytes = 5MB
        $maxRows = 100000
        $maxColumns = 200
        $maxCells = 2000000
        $name = [System.IO.Path]::GetFileName([string]$EventData.Name)
        $extension = [System.IO.Path]::GetExtension($name).ToLowerInvariant()
        if ($extension -notin '.csv', '.json') { throw [System.IO.InvalidDataException]::new(('{0}: the showcase reads .csv and .json files.' -f $name)) }
        $size = (Get-Item -LiteralPath $file).Length
        if ($size -gt $maxBytes) { throw [System.IO.InvalidDataException]::new(('{0} has {1:N1} MB; the showcase reads files up to {2} MB.' -f $name, ($size / 1MB), ($maxBytes / 1MB))) }
        if ($size -eq 0) { throw [System.IO.InvalidDataException]::new(('{0} is empty.' -f $name)) }
        $text = Get-Content -LiteralPath $file -Raw -Encoding utf8
        if ($extension -eq '.csv') {
            # rows and columns from the text before parsing it (a quoted line break counts as a row)
            $lines = $text.TrimEnd("`r", "`n").Split("`n").Count
            $header = ($text -split '\r?\n', 2)[0]
            # the separator that splits the header line most: comma, semicolon (German Excel) or tab
            $delimiter = ',', ';', "`t" | Sort-Object { $header.Split($_).Count } -Descending | Select-Object -First 1
            $columnCount = $header.Split($delimiter).Count
            if ($lines - 1 -gt $maxRows) { throw [System.IO.InvalidDataException]::new(('{0} has {1:N0} rows; the showcase reads up to {2:N0}.' -f $name, ($lines - 1), $maxRows)) }
            if ($columnCount -gt $maxColumns) { throw [System.IO.InvalidDataException]::new(('{0} has {1:N0} columns; the showcase reads up to {2:N0}.' -f $name, $columnCount, $maxColumns)) }
            if (($lines - 1) * $columnCount -gt $maxCells) { throw [System.IO.InvalidDataException]::new(('{0} has {1:N0} cells; the showcase reads up to {2:N0}.' -f $name, (($lines - 1) * $columnCount), $maxCells)) }
            $rows = @($text | ConvertFrom-Csv -Delimiter $delimiter)
            # numbers arrive as text: a column whose every value is a number becomes numbers
            # (decimal comma with a semicolon separator, as German Excel writes it)
            $culture = if ($delimiter -eq ';') { [cultureinfo]'de-DE' } else { [cultureinfo]::InvariantCulture }
            $style = [System.Globalization.NumberStyles]::Float -bor [System.Globalization.NumberStyles]::AllowThousands
            $columns = if ($rows.Count) { $rows[0].PSObject.Properties.Name } else { @() }
            foreach ($column in $columns) {
                $number = 0.0
                $allNumbers = $false
                foreach ($row in $rows) {
                    $value = $row.$column
                    if ($value -eq '') { continue }
                    if (-not [double]::TryParse($value, $style, $culture, [ref]$number)) { $allNumbers = $false; break }
                    $allNumbers = $true
                }
                if ($allNumbers) {
                    foreach ($row in $rows) { $row.$column = if ($row.$column -ne '') { [double]::Parse($row.$column, $style, $culture) } }
                }
            }
        }
        else {
            try { $json = $text | ConvertFrom-Json -NoEnumerate -Depth 20 }
            catch { throw [System.IO.InvalidDataException]::new(('{0} is not valid JSON, or nested deeper than 20 levels.' -f $name)) }
            # an array of objects, or an object with one array of objects in it (as many APIs answer)
            if ($json -isnot [array]) {
                $arrays = @($json.PSObject.Properties | Where-Object { $_.Value -is [array] })
                if ($arrays.Count -ne 1) { throw [System.IO.InvalidDataException]::new(('{0}: expected an array of objects, or an object with exactly one array in it.' -f $name)) }
                $json = $arrays[0].Value
            }
            if ($json.Count -gt $maxRows) { throw [System.IO.InvalidDataException]::new(('{0} has {1:N0} rows; the showcase reads up to {2:N0}.' -f $name, $json.Count, $maxRows)) }
            if (@($json | Where-Object { $_ -isnot [System.Management.Automation.PSCustomObject] }).Count) { throw [System.IO.InvalidDataException]::new(('{0}: every entry of the array must be an object (one row).' -f $name)) }
            $columnCount = if ($json.Count) { @($json[0].PSObject.Properties).Count } else { 0 }
            if ($columnCount -gt $maxColumns) { throw [System.IO.InvalidDataException]::new(('{0} has {1:N0} columns; the showcase reads up to {2:N0}.' -f $name, $columnCount, $maxColumns)) }
            $rows = @($json)
        }
        if ($rows.Count -eq 0) { throw [System.IO.InvalidDataException]::new(('{0} has no rows.' -f $name)) }
        # the name the page shows, within the 120 characters of the report's -Label
        $shown = if ($name.Length -le 120) { $name } else { $name.Substring(0, 117) + '...' }
        # the report's -SourceId: the file name and a hash of its column names. pivotkit offers only the
        # browser views made for this id, so every file keeps its own views (the report's -Id is the same
        # for every upload) and the same file uploaded again finds them. No server path is in it.
        $columnHash = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes((@($rows[0].PSObject.Properties.Name) -join [char]0)))
        $sourceId = '{0}#{1}' -f $shown, [System.Convert]::ToHexString($columnHash, 0, 8).ToLowerInvariant()
        $Session:PivotShowcaseUpload = @{ Name = $shown; Rows = $rows; Columns = @($rows[0].PSObject.Properties).Count; SourceId = $sourceId }
    }
    catch [System.IO.InvalidDataException] {
        $Session:PivotShowcaseUploadError = $_.Exception.Message
    }
    catch {
        Write-Warning ('Pivot showcase upload: {0}' -f $_)
        $Session:PivotShowcaseUploadError = 'The file could not be read. The server log has the details.'
    }
    finally {
        if ($file) { Remove-Item -LiteralPath $file -Force -ErrorAction Ignore }
    }
    Sync-UDElement -Id 'upload-content'
}
$uploadPage = New-ShowcasePage -Name 'Your data' -Url '/upload' -Title 'Pivot your own data' `
    -Text 'Upload a CSV (comma, semicolon or tab separated) or JSON file (an array of objects) of up to 5 MB and 100,000 rows. The file is read on the server and deleted at once; its rows stay in the memory of your session only, until you upload another file or the session ends.' `
    -Code $uploadCode -Above "New-UDUpload -Id 'upload-file' -Text 'Upload CSV or JSON' -HideUploadedFileName -Accept '.csv,.json,text/csv,application/json' -OnUpload {$uploadHandler}"
#endregion

#region Ticket showcase of the pivot module (generated data)
# examples/showcase.ps1 is an app script; its pages are taken over by answering its New-UDApp call
$ticketPages = & {
    function New-UDApp {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Title')]
        param([string]$Title, [object[]]$Pages)
        $Pages
    }
    & (Resolve-ShowcasePath -Path 'Apps/Tickets/showcase.ps1')
}
#endregion

New-UDApp -Title 'Pivot reports for PowerShell Universal' -Pages @(
    $docsPages
    $weatherPage
    $uploadPage
    $ticketPages
)
