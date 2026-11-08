#Requires -Version 7.4

<#
.SYNOPSIS
    Fetches the snapshots of the live examples again (docs/site/data/).
.DESCRIPTION
    Every JSON file below data/ is the answer of one address: data/<host>/<path> is https://<host>/<path>,
    or the address data/Addresses.psd1 names for the file (an address with a query string).
    The script requests each address, checks that the answer is JSON and only then replaces the file
    with it as it came; a failed request or an answer that is not JSON keeps the old file and is
    reported. At the end it writes the day into the "Fetched on" line of data/SOURCES.md. To add an
    address, create an empty file at its path and run this script. Sources, licences, attribution
    and the API version of each endpoint (endoflife.date: v0, /api/<product>.json): data/SOURCES.md.
.PARAMETER Filter
    Only the files whose path below data/ matches this wildcard (for example 'endoflife.date/*').
.EXAMPLE
    ./docs/site/Update-Data.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Filter = '*'
)

$ErrorActionPreference = 'Stop'
$data = Join-Path $PSScriptRoot 'data'
# addresses with a query string, by file below data/
$addresses = Import-PowerShellDataFile -LiteralPath (Join-Path $data 'Addresses.psd1')
$failed = 0
$updated = 0
foreach ($file in Get-ChildItem -LiteralPath $data -Recurse -File -Filter '*.json') {
    $relative = [System.IO.Path]::GetRelativePath($data, $file.FullName) -replace '\\', '/'
    if ($relative -notlike $Filter) { continue }
    $uri = if ($addresses[$relative]) { $addresses[$relative] } else { "https://$relative" }
    if (-not $PSCmdlet.ShouldProcess($file.FullName, "Fetch $uri")) { continue }
    try {
        $answer = Invoke-WebRequest -Uri $uri -UserAgent 'powershell-universal-components docs'
        # parses, or throws: a page of HTML or an error text never replaces a snapshot
        $null = $answer.Content | ConvertFrom-Json -NoEnumerate
        [System.IO.File]::WriteAllText($file.FullName, $answer.Content)
        $updated++
    }
    catch {
        Write-Warning "${uri}: kept the old file ($($_.Exception.Message))"
        $failed++
    }
    # one request a second: the APIs ask for a low load
    Start-Sleep -Seconds 1
}

if ($updated -and $PSCmdlet.ShouldProcess('data/SOURCES.md', 'Write the fetch date')) {
    $sources = Join-Path $data 'SOURCES.md'
    $today = (Get-Date).ToString('yyyy-MM-dd')
    $text = (Get-Content -LiteralPath $sources -Raw) -replace '(?m)^Fetched on \d{4}-\d{2}-\d{2}', "Fetched on $today"
    Set-Content -LiteralPath $sources -Value $text -NoNewline -Encoding utf8NoBOM
    Write-Output "$updated files fetched on $today; look at the diff before committing."
}
if ($failed) { throw "$failed addresses failed; their old files are kept." }
