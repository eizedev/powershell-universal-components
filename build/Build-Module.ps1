#Requires -Version 7.4

<#
.SYNOPSIS
    Builds one component module into output/<Module>/<Version>, ready for a PSU repository's Modules folder.

.DESCRIPTION
    For modules/<Module>: installs the exact npm versions from package-lock.json (npm ci; npm install
    only when no lock file exists yet - commit it), runs webpack (shared/js is compiled into the
    bundle), and assembles a clean folder with the bundle, the manifest, the module, Private/
    (shared/powershell/*.ps1), Apps/ when the module has one, and THIRD-PARTY-NOTICES.txt. A module
    without package.json (PowerShell only, e.g. a demo app) skips the JavaScript steps. The version
    comes from the manifest. Old output is removed first, so a failed build never leaves a stale bundle
    behind.

.PARAMETER Module
    Folder name below modules/, e.g. PowerShellUniversal.Component.ECharts.

.PARAMETER OutputPath
    Root of the output. Default: output/ in the repository.

.PARAMETER SkipNpmInstall
    Use the node_modules that are already there (faster local rebuilds).

.EXAMPLE
    ./build/Build-Module.ps1 -Module PowerShellUniversal.Component.ECharts

.OUTPUTS
    System.IO.DirectoryInfo of the built module folder.
#>
[CmdletBinding()]
[OutputType([System.IO.DirectoryInfo])]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z][A-Za-z0-9.]+$')]
    [string]$Module,

    [string]$OutputPath = (Join-Path $PSScriptRoot '..' 'output'),

    [switch]$SkipNpmInstall
)

$ErrorActionPreference = 'Stop'
$repo = Resolve-Path (Join-Path $PSScriptRoot '..')
$source = Join-Path $repo 'modules' $Module
$manifest = Join-Path $source "$Module.psd1"
if (-not (Test-Path -LiteralPath $manifest)) { throw ('No module {0} (expected {1}).' -f $Module, $manifest) }
$version = (Import-PowerShellDataFile -LiteralPath $manifest).ModuleVersion
$out = Join-Path $OutputPath $Module $version

Remove-Item -LiteralPath (Join-Path $OutputPath $Module) -Recurse -Force -ErrorAction Ignore
# a component has a JavaScript bundle; a PowerShell-only module (a demo app) has no package.json
$component = Test-Path -LiteralPath (Join-Path $source 'package.json')
if ($component) {
    Push-Location $source
    try {
        if (-not $SkipNpmInstall) {
            # no package needs an install script; skipping them keeps a compromised dependency from
            # running code on the build machine (CI installs the same way)
            if (Test-Path -LiteralPath (Join-Path $source 'package-lock.json')) { npm ci --no-audit --no-fund --ignore-scripts } else { npm install --no-audit --no-fund --ignore-scripts }
            if ($LASTEXITCODE -ne 0) { throw ('npm install failed ({0})' -f $LASTEXITCODE) }
        }
        npm run build --silent
        if ($LASTEXITCODE -ne 0) { throw ('webpack build failed ({0})' -f $LASTEXITCODE) }
    }
    finally {
        Pop-Location
    }
}

New-Item -ItemType Directory -Path $out -Force | Out-Null
# the bundle and its licence banner; the source map is for development only (PSU never serves it)
if ($component) { Copy-Item -Path (Join-Path $source 'public' '*') -Exclude '*.map' -Destination $out }
if (Test-Path -LiteralPath (Join-Path $source 'Apps')) { Copy-Item -LiteralPath (Join-Path $source 'Apps') -Destination $out -Recurse }
Copy-Item -LiteralPath $manifest, (Join-Path $source "$Module.psm1") -Destination $out
if ($component) {
    New-Item -ItemType Directory -Path (Join-Path $out 'Private') -Force | Out-Null
    Copy-Item -Path (Join-Path $repo 'shared' 'powershell' '*.ps1') -Destination (Join-Path $out 'Private')
}
# README and CHANGELOG travel with the module (PowerShell Gallery, an installed copy), where links
# relative to the repository lead nowhere: they become links to the same file on the default branch
$projectUri = (Import-PowerShellDataFile -LiteralPath $manifest).PrivateData.PSData.ProjectUri
foreach ($extra in 'README.md', 'CHANGELOG.md') {
    $file = Join-Path $source $extra
    if (-not (Test-Path -LiteralPath $file)) { continue }
    $text = Get-Content -LiteralPath $file -Raw
    if ($projectUri) {
        $text = [regex]::Replace($text, '\]\((?![a-z][a-z0-9+.-]*:|#|/)(?<path>[^)\s]+)\)', {
                param($m)
                # resolve ../ against modules/<Module>/ without touching the file system
                $parts = [System.Collections.Generic.List[string]]@('modules', $Module)
                foreach ($part in $m.Groups['path'].Value -split '/') {
                    if ($part -eq '..') { if ($parts.Count) { $parts.RemoveAt($parts.Count - 1) } }
                    elseif ($part -and $part -ne '.') { $parts.Add($part) }
                }
                '](' + $projectUri.TrimEnd('/') + '/blob/HEAD/' + ($parts -join '/') + ')'
            })
    }
    Set-Content -LiteralPath (Join-Path $out $extra) -Value $text -NoNewline -Encoding utf8NoBOM
}
Copy-Item -LiteralPath (Join-Path $repo 'LICENSE') -Destination $out

if (-not $component) { return Get-Item -LiteralPath $out }

# Bundled libraries keep their licences (Apache-2.0 and BSD ask for the text and NOTICE with every copy):
# every runtime package in the lock file contributes its LICENSE and NOTICE files.
$lock = Get-Content -LiteralPath (Join-Path $source 'package-lock.json') -Raw | ConvertFrom-Json -AsHashtable
$notices = foreach ($entry in $lock.packages.GetEnumerator() | Sort-Object Key) {
    if (-not $entry.Key -or $entry.Value.dev) { continue }
    $dir = Join-Path $source $entry.Key
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
Set-Content -LiteralPath (Join-Path $out 'THIRD-PARTY-NOTICES.txt') -Value ($notices -join [Environment]::NewLine) -Encoding utf8NoBOM
$bundles = @(Get-ChildItem -LiteralPath $out -Filter 'index.*.bundle.js' -File)
if ($bundles.Count -ne 1) { throw ('Expected exactly one bundle in {0}, found {1}.' -f $out, $bundles.Count) }
Get-Item -LiteralPath $out
