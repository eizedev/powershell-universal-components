#Requires -Version 7.4

<#
.SYNOPSIS
    Prepares a built module for release, or publishes a prepared one to the PowerShell Gallery.
.DESCRIPTION
    Used by the release workflow after Build-Module.ps1, in two steps:
    without -Publish it checks that the tag's version is the manifest's ModuleVersion and that
    CHANGELOG.md has a section for it, writes that section into the built manifest's ReleaseNotes,
    runs Test-ModuleManifest and packs a zip for the GitHub release (no secret needed);
    with -Publish it publishes the prepared folder with Publish-PSResource. The API key comes from the
    environment variable PSGALLERY_API_KEY and is never written out.
.PARAMETER Module
    Module name, e.g. PowerShellUniversal.Component.ECharts.
.PARAMETER Version
    The version to release (from the tag <Module>-v<Version>).
.PARAMETER OutputPath
    Folder Build-Module.ps1 wrote to. Default: output in the repository.
.PARAMETER Publish
    Publish the prepared module instead of preparing it.
.EXAMPLE
    ./build/Publish-Module.ps1 -Module PowerShellUniversal.Component.ECharts -Version 0.1.0
.EXAMPLE
    $env:PSGALLERY_API_KEY = '...'; ./build/Publish-Module.ps1 -Module PowerShellUniversal.Component.ECharts -Version 0.1.0 -Publish
.OUTPUTS
    System.IO.FileInfo of the zip for the GitHub release (prepare step).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Module,
    [Parameter(Mandatory)][ValidatePattern('^\d+\.\d+\.\d+(-[0-9A-Za-z.]+)?$')][string]$Version,
    [string]$OutputPath,
    [switch]$Publish
)

$ErrorActionPreference = 'Stop'
$repo = Resolve-Path (Join-Path $PSScriptRoot '..')
if (-not $OutputPath) { $OutputPath = Join-Path $repo 'output' }
$source = Join-Path $repo 'modules' $Module
$built = Join-Path $OutputPath $Module ($Version -replace '-.*$', '')
if (-not (Test-Path -LiteralPath $built)) { throw ('No built module at {0}; run Build-Module.ps1 first.' -f $built) }

$manifestPath = Join-Path $built "$Module.psd1"
if ($Publish) {
    if (-not $env:PSGALLERY_API_KEY) { throw 'PSGALLERY_API_KEY is not set.' }
    Publish-PSResource -Path $built -Repository PSGallery -ApiKey $env:PSGALLERY_API_KEY
    Write-Information ('Published {0} {1} to the PowerShell Gallery.' -f $Module, $Version) -InformationAction Continue
    return
}

# the version the tag names must be the one in the manifest (prerelease part in PSData.Prerelease)
$data = Import-PowerShellDataFile -LiteralPath $manifestPath
$prerelease = $data.PrivateData.PSData.Prerelease
$manifestVersion = if ($prerelease) { '{0}-{1}' -f $data.ModuleVersion, $prerelease } else { $data.ModuleVersion }
if ($manifestVersion -ne $Version) { throw ('The tag says {0}, the manifest says {1}.' -f $Version, $manifestVersion) }

# release notes: the CHANGELOG section of this version, which must exist
$changelog = Get-Content -LiteralPath (Join-Path $source 'CHANGELOG.md') -Raw
$pattern = '(?ms)^## \[{0}\][^\r\n]*\r?\n(?<notes>.*?)(?=^## \[|\z)' -f [regex]::Escape($Version)
$match = [regex]::Match($changelog, $pattern)
if (-not $match.Success -or -not $match.Groups['notes'].Value.Trim()) {
    throw ('CHANGELOG.md has no section "## [{0}]" with content; move the entries from [Unreleased] there.' -f $Version)
}
$notes = $match.Groups['notes'].Value.Trim()

# the built manifest carries the notes (the gallery shows them); the source keeps its link
$text = Get-Content -LiteralPath $manifestPath -Raw
$link = [regex]::Match($text, "ReleaseNotes\s*=\s*'[^']*'")
if (-not $link.Success) { throw 'The manifest has no ReleaseNotes entry to replace.' }
$escaped = ($notes -replace "'", "''")
$text = $text.Remove($link.Index, $link.Length).Insert($link.Index, "ReleaseNotes = '$escaped'")
Set-Content -LiteralPath $manifestPath -Value $text -Encoding utf8NoBOM -NoNewline

$manifest = Test-ModuleManifest -Path $manifestPath
foreach ($required in 'LicenseUri', 'ProjectUri') {
    if (-not $manifest.PrivateData.PSData[$required]) { throw ('The manifest has no {0}.' -f $required) }
}
if ('PowerShellUniversal' -notin $manifest.Tags) { throw 'The manifest needs the tag PowerShellUniversal (PSU and the Devolutions gallery find modules by it).' }

$zip = Join-Path $OutputPath "$Module-$Version.zip"
Remove-Item -LiteralPath $zip -ErrorAction Ignore
Compress-Archive -Path (Join-Path $OutputPath $Module) -DestinationPath $zip

Write-Information ('{0} {1} checked and packed.' -f $Module, $Version) -InformationAction Continue
Get-Item -LiteralPath $zip
