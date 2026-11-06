#Requires -Version 7.4

<#
.SYNOPSIS
    Builds the documentation site into output/site: examples run with the real New-UDEChart, the
    reference from the comment-based help, the charts drawn by the module's own React component.
.DESCRIPTION
    Runs every example in examples.ps1 outside PSU (PSU's [Endpoint] type is replaced by a stub),
    takes the hashtable New-UDEChart returns as the chart's props and the script block's text as the
    code shown, reads the help of the module's commands, writes index.html with that data and builds
    site.js with webpack (npm ci in this folder). Open output/site/index.html directly or serve the
    folder.
.PARAMETER OutputPath
    Folder for the site. Default: output/site in the repository.
.PARAMETER SkipNpmInstall
    Use the installed node_modules (faster when building repeatedly).
.EXAMPLE
    ./docs/site/Build-Site.ps1
#>
[CmdletBinding()]
param(
    [string]$OutputPath,
    [switch]$SkipNpmInstall
)

$ErrorActionPreference = 'Stop'
$site = $PSScriptRoot
$repo = Resolve-Path (Join-Path $site '..' '..')
if (-not $OutputPath) { $OutputPath = Join-Path $repo 'output' 'site' }
# absolute now: the build changes into this folder later
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath, (Get-Location).Path)
$moduleName = 'PowerShellUniversal.Component.ECharts'
$moduleDir = Join-Path $repo 'modules' $moduleName

# PSU's endpoint type, as in the Pester tests: event script blocks become a marker the page replaces
if (-not ('Endpoint' -as [type])) {
    Add-Type -TypeDefinition @'
public class Endpoint {
    public System.Management.Automation.ScriptBlock ScriptBlock;
    public Endpoint(System.Management.Automation.ScriptBlock scriptBlock) { ScriptBlock = scriptBlock; }
    public void Register(string id, object cmdlet) { }
}
'@
}
$module = Import-Module (Join-Path $moduleDir "$moduleName.psm1") -Force -PassThru
& $module { $Script:AssetId = 'site' }
$manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $moduleDir "$moduleName.psd1")

# the code as written in examples.ps1, without the indentation of the file
function Format-ExampleCode([scriptblock]$Code) {
    $lines = $Code.ToString().Trim("`r", "`n") -split '\r?\n'
    $indent = ($lines | Where-Object { $_.Trim() } | ForEach-Object { $_.Length - $_.TrimStart().Length } | Measure-Object -Minimum).Minimum
    ($lines | ForEach-Object { if ($_.Length -ge $indent) { $_.Substring($indent) } else { $_.TrimStart() } }) -join "`n"
}

# hashtable -> plain data for JSON; endpoints become "__event__"
function ConvertTo-SiteValue([object]$Value) {
    if ($null -eq $Value) { return $null }
    if ($Value -is [Endpoint]) { return '__event__' }
    # strings and numbers first: "-is [pscustomobject]" is true for every object wrapped in a PSObject
    if ($Value -is [string] -or $Value -is [valuetype]) { return $Value }
    if ($Value -is [System.Collections.IDictionary]) {
        $out = [ordered]@{}
        foreach ($key in $Value.Keys) { $out[[string]$key] = ConvertTo-SiteValue $Value[$key] }
        return $out
    }
    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        $out = [ordered]@{}
        foreach ($p in $Value.PSObject.Properties) { $out[$p.Name] = ConvertTo-SiteValue $p.Value }
        return $out
    }
    # the comma keeps a one-element array an array (a function's output is unrolled otherwise)
    if ($Value -is [System.Collections.IEnumerable]) { return , @($Value | ForEach-Object { ConvertTo-SiteValue $_ }) }
    return [string]$Value
}

$examples = foreach ($example in & (Join-Path $site 'examples.ps1')) {
    $props = & $example.Code
    foreach ($key in 'assetId', 'isPlugin', 'type') { $props.Remove($key) }
    # a fixed id per example, so the page is the same on every build
    $props['id'] = 'example-' + ($example.Title.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
    [ordered]@{
        section = $example.Section
        title   = $example.Title
        text    = $example.Text
        code    = Format-ExampleCode $example.Code
        props   = ConvertTo-SiteValue $props
    }
}

$commands = foreach ($name in $manifest.FunctionsToExport) {
    $help = Get-Help $name -Full
    [ordered]@{
        name        = $name
        synopsis    = ($help.Synopsis | Out-String).Trim()
        description = (($help.description | ForEach-Object { $_.Text }) -join "`n").Trim()
        parameters  = @(foreach ($p in $help.parameters.parameter) {
                [ordered]@{
                    name        = $p.name
                    type        = $p.type.name
                    required    = $p.required -eq 'true'
                    description = (($p.description | ForEach-Object { $_.Text }) -join ' ').Trim()
                }
            })
    }
}

$data = [ordered]@{
    title      = 'ECharts for PowerShell Universal'
    version    = $manifest.ModuleVersion
    repository = $manifest.PrivateData.PSData.ProjectUri
    intro      = $manifest.Description
    install    = "Install-PSResource -Name $moduleName"
    examples   = @($examples)
    commands   = @($commands)
}
# "</" would end the script element early
$json = ($data | ConvertTo-Json -Depth 30 -Compress) -replace '</', '<\/'

New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
$template = Get-Content -LiteralPath (Join-Path $site 'index.html') -Raw
Set-Content -LiteralPath (Join-Path $OutputPath 'index.html') -Value ($template.Replace('{{DATA}}', $json).Replace('{{TITLE}}', $data.title)) -Encoding utf8NoBOM -NoNewline

Push-Location $site
try {
    if (-not $SkipNpmInstall) {
        npm ci --no-audit --no-fund --ignore-scripts
        if ($LASTEXITCODE -ne 0) { throw ('npm ci failed ({0})' -f $LASTEXITCODE) }
    }
    $env:SITE_OUT = $OutputPath
    npx webpack --config webpack.config.cjs
    if ($LASTEXITCODE -ne 0) { throw ('webpack failed ({0})' -f $LASTEXITCODE) }
}
finally {
    Remove-Item Env:SITE_OUT -ErrorAction Ignore
    Pop-Location
}
Get-Item -LiteralPath $OutputPath
