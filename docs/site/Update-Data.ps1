#Requires -Version 7.4

<#
.SYNOPSIS
    Fetches the snapshots of the live examples again (docs/site/data/).
.DESCRIPTION
    Every JSON file below data/ is the answer of one address: data/<host>/<path> is https://<host>/<path>.
    The script requests each address and writes the answer as it came. To add one, run the example's
    Invoke-RestMethod once with -OutFile into the matching path, or create an empty file there and run
    this script. Sources, licences, attribution and the API version of each endpoint (endoflife.date:
    v0, /api/<product>.json): data/SOURCES.md.
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
foreach ($file in Get-ChildItem -LiteralPath $data -Recurse -File -Filter '*.json') {
    $relative = [System.IO.Path]::GetRelativePath($data, $file.FullName) -replace '\\', '/'
    if ($relative -notlike $Filter) { continue }
    $uri = "https://$relative"
    if ($PSCmdlet.ShouldProcess($file.FullName, "Fetch $uri")) {
        Invoke-WebRequest -Uri $uri -OutFile $file.FullName -UserAgent 'powershell-universal-components docs'
        # one request a second: the APIs ask for a low load
        Start-Sleep -Seconds 1
    }
}
