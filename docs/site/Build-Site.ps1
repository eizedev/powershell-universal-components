#Requires -Version 7.4

<#
.SYNOPSIS
    Prepares the live parts of the documentation site: the examples, the command reference and the
    script that draws the charts. Zensical then builds the site from docs/ (zensical build).
.DESCRIPTION
    Runs every example in examples.ps1 outside PSU (PSU's [Endpoint] type is replaced by a stub) with
    the real New-UDEChart, New-UDPerspective or New-UDPivotReport and writes, all of it generated and not committed:

    - docs/site/generated/examples/<id>.md: the placeholder the chart is drawn into and the example's
      code; the pages in docs/ include it with --8<-- "examples/<id>.md".
    - docs/site/generated/reference/<command>.md: the parameters of every exported command, from the
      comment-based help; included by the reference pages.
    - docs/assets/charts/: charts.js (webpack, the modules' own React components), its lazy
      Perspective and pivot chunks and examples.json (the props of every example).
    - docs/assets/images/: the screenshots from assets/ that the pages show.

    Fails when an example is included by no page, so examples.ps1 and the pages stay in step.
.PARAMETER SkipNpmInstall
    Use the installed node_modules (faster when building repeatedly).
.EXAMPLE
    ./docs/site/Build-Site.ps1; uv run --with zensical zensical serve
#>
[CmdletBinding()]
param(
    [switch]$SkipNpmInstall
)

$ErrorActionPreference = 'Stop'
$site = $PSScriptRoot
$repo = (Resolve-Path (Join-Path $site '..' '..')).Path
$docs = Join-Path $repo 'docs'
$generated = Join-Path $site 'generated'
$charts = Join-Path $docs 'assets' 'charts'
$modulesDir = Join-Path $repo 'modules'
# the modules whose commands the site documents and whose examples it runs
$moduleNames = 'PowerShellUniversal.Component.ECharts', 'PowerShellUniversal.Component.Perspective', 'PowerShellUniversal.Component.Pivot', 'PowerShellUniversal.Component.ECharts.Demo'

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
$manifests = [ordered]@{}
foreach ($name in $moduleNames) {
    $dir = Join-Path $modulesDir $name
    # the demo requires the chart module by name; it is imported above it already
    $module = Import-Module (Join-Path $dir "$name.psm1") -Force -PassThru -DisableNameChecking
    & $module { $Script:AssetId = 'site' }
    $manifests[$name] = Import-PowerShellDataFile -LiteralPath (Join-Path $dir "$name.psd1")
}

function Get-Slug([string]$Text) {
    ($Text.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
}

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

# text for a Markdown table cell
function Format-Cell([string]$Text) {
    (($Text -replace '\r?\n+', ' ') -replace '\|', '\|').Trim()
}

# help text -> Markdown: parameter names and values as code, URLs as links, a blank line before a list
# that follows a paragraph line (comment-based help writes "...they use:" directly above "- line, ...")
function Format-HelpText([string]$Text) {
    $out = [System.Collections.Generic.List[string]]::new()
    $previous = ''
    foreach ($line in ($Text -split '\r?\n')) {
        if ($line -match '^\s*- ' -and $previous.Trim() -and $previous -notmatch '^\s*- |^\s{2,}\S') { $out.Add('') }
        # -Name (a parameter) as code; not inside words like Invoke-RestMethod or ranges like 0-100
        $line = $line -replace '(?<![\w`/-])(-[A-Z][A-Za-z]*)\b', '`$1`'
        $line = $line -replace '(?<![<(\w])(https?://[^\s)]+[^\s).,;])', '<$1>'
        $line = $line -replace '\((https?://[^\s)]+)\)', '(<$1>)'
        $out.Add($line)
        $previous = $line
    }
    $out -join "`n"
}

function Write-Generated([string]$Path, [string]$Content) {
    New-Item -ItemType Directory -Path (Split-Path $Path) -Force | Out-Null
    Set-Content -LiteralPath $Path -Value $Content -Encoding utf8NoBOM
}

if (Test-Path $generated) { Remove-Item $generated -Recurse -Force }

# ---- examples ----------------------------------------------------------------------------------------
$examples = [ordered]@{}
foreach ($example in & (Join-Path $site 'examples.ps1')) {
    $id = Get-Slug $example.Title
    if ($examples.Contains($id)) { throw "Two examples are titled '$($example.Title)'." }
    $props = & $example.Code
    $component = switch ($props.type) { 'ud-perspective' { 'perspective' } 'ud-pivot-report' { 'pivot' } default { 'echarts' } }
    foreach ($key in 'assetId', 'isPlugin', 'type') { $props.Remove($key) }
    # a fixed id per example, so the page is the same on every build
    $props['id'] = "example-$id"
    $examples[$id] = [ordered]@{ title = $example.Title; component = $component; props = ConvertTo-SiteValue $props }
    $text = if ($example.Text) { "$($example.Text)`n`n" } else { '' }
    $snippet = "$text<div class=`"psu-example`" data-example=`"$id`"></div>`n`n``````powershell`n$(Format-ExampleCode $example.Code)`n```````n"
    Write-Generated (Join-Path $generated 'examples' "$id.md") $snippet
}

# every example appears on a page, and only once
$pages = Get-ChildItem -Path $docs -Recurse -Filter '*.md' | Where-Object FullName -NotLike "$site*"
$included = $pages | Select-String -Pattern '--8<-- "examples/([a-z0-9-]+)\.md"' -AllMatches | ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value }
$unused = $examples.Keys | Where-Object { $_ -notin $included }
if ($unused) { throw "Examples on no page (include them with --8<-- `"examples/<id>.md`"): $($unused -join ', ')" }
$twice = $included | Group-Object | Where-Object Count -GT 1 | ForEach-Object Name
if ($twice) { throw "Examples included more than once: $($twice -join ', ')" }

# ---- reference ---------------------------------------------------------------------------------------
foreach ($name in $moduleNames) {
    foreach ($command in $manifests[$name].FunctionsToExport) {
        $help = Get-Help $command -Full
        $lines = [System.Collections.Generic.List[string]]::new()
        $lines.Add(($help.Synopsis | Out-String).Trim())
        $lines.Add('')
        $description = Format-HelpText ((($help.description | ForEach-Object { $_.Text }) -join "`n`n").Trim())
        if ($description) { $lines.Add($description); $lines.Add('') }
        $lines.Add('| Parameter | Type | Description |')
        $lines.Add('| --- | --- | --- |')
        foreach ($p in $help.parameters.parameter) {
            $required = if ($p.required -eq 'true') { ' (required)' } else { '' }
            $text = Format-HelpText (($p.description | ForEach-Object { $_.Text }) -join ' ')
            $lines.Add("| ``-$($p.name)``$required | ``$($p.type.name)`` | $(Format-Cell $text) |")
        }
        Write-Generated (Join-Path $generated 'reference' "$command.md") ($lines -join "`n")
    }
}

# ---- the script that draws the charts ----------------------------------------------------------------
Push-Location $site
try {
    if (-not $SkipNpmInstall) {
        npm ci --no-audit --no-fund --ignore-scripts
        if ($LASTEXITCODE -ne 0) { throw ('npm ci failed ({0})' -f $LASTEXITCODE) }
        # Perspective resolves from its module's node_modules (its pinned versions, see webpack.config.cjs)
        npm ci --no-audit --no-fund --ignore-scripts --prefix (Join-Path $modulesDir 'PowerShellUniversal.Component.Perspective')
        if ($LASTEXITCODE -ne 0) { throw ('npm ci (Perspective) failed ({0})' -f $LASTEXITCODE) }
        # pivotkit the same way, from the pivot module's node_modules
        npm ci --no-audit --no-fund --ignore-scripts --prefix (Join-Path $modulesDir 'PowerShellUniversal.Component.Pivot')
        if ($LASTEXITCODE -ne 0) { throw ('npm ci (Pivot) failed ({0})' -f $LASTEXITCODE) }
    }
    $env:SITE_OUT = $charts
    npx webpack --config webpack.config.cjs
    if ($LASTEXITCODE -ne 0) { throw ('webpack failed ({0})' -f $LASTEXITCODE) }
}
finally {
    Remove-Item Env:SITE_OUT -ErrorAction Ignore
    Pop-Location
}
# the screenshots of the repository's README, for the pages (one copy in assets/, not committed here)
$images = Join-Path $docs 'assets' 'images'
New-Item -ItemType Directory -Path $images -Force | Out-Null
Copy-Item -Path (Join-Path $repo 'assets' 'screenshot-*.png') -Destination $images -Force
# after webpack, which empties its output folder
Write-Generated (Join-Path $charts 'examples.json') ($examples | ConvertTo-Json -Depth 30 -Compress)
Get-Item -LiteralPath $charts
