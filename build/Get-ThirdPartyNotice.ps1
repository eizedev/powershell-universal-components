#Requires -Version 7.4

<#
.SYNOPSIS
    The text of THIRD-PARTY-NOTICES.txt for a component module: the licence and NOTICE files of every
    runtime package in its package-lock.json.

.DESCRIPTION
    Bundled libraries keep their licences: Apache-2.0 and BSD ask for the text and NOTICE with every
    copy. Each runtime package (not dev) contributes a header line and its LICENSE and NOTICE files, or
    the licence its package.json names when it ships none. An optional package that is not installed
    (one for another platform) is not in the bundle and is left out. Any other package that is in the
    lock file but not installed stops the build: run npm ci first.

.PARAMETER Path
    The module's source folder, with package-lock.json and node_modules/.

.EXAMPLE
    ./build/Get-ThirdPartyNotice.ps1 -Path modules/PowerShellUniversal.Component.ECharts

.OUTPUTS
    System.String: the lines of the notices file.
#>
[CmdletBinding()]
[OutputType([string])]
param([Parameter(Mandatory)][string]$Path)
$ErrorActionPreference = 'Stop'

$lock = Get-Content -LiteralPath (Join-Path $Path 'package-lock.json') -Raw | ConvertFrom-Json -AsHashtable
foreach ($entry in $lock.packages.GetEnumerator() | Sort-Object Key) {
    if (-not $entry.Key -or $entry.Value.dev) { continue }
    $dir = Join-Path $Path $entry.Key
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
        # an optional package for another platform is in the lock but not installed, and not in the bundle
        if ($entry.Value.optional) { continue }
        throw ('{0} is in package-lock.json but not installed; run npm ci in {1}.' -f $entry.Key, $Path)
    }
    $files = @(Get-ChildItem -LiteralPath $dir -File -ErrorAction Ignore | Where-Object Name -Match '^(LICEN[CS]E|NOTICE)(\.(md|txt))?$')
    '=' * 78
    '{0} {1} ({2})' -f ($entry.Key -replace '^.*node_modules/', ''), $entry.Value.version, $entry.Value.license
    '=' * 78
    if ($files.Count -eq 0) {
        # some packages ship no licence file; their package.json names the licence
        $pkg = Get-Content -LiteralPath (Join-Path $dir 'package.json') -Raw | ConvertFrom-Json
        'The package ships no licence file. License: {0}; author: {1}.' -f $pkg.license, $(if ($pkg.author -is [string]) { $pkg.author } elseif ($pkg.author) { $pkg.author.name } else { 'not stated' })
    }
    foreach ($file in $files) { Get-Content -LiteralPath $file.FullName -Raw }
}
