#Requires -Version 7.4

<#
.SYNOPSIS
    Checks that a built module loads on its own and exports the commands its manifest names.

.DESCRIPTION
    Imports the built module in a new pwsh process, so a module loaded in the calling session does not
    stand in for it. PSU's Endpoint type comes from Add-EndpointType.ps1, as in the Pester tests.
    Throws when the import fails or the exported commands differ from FunctionsToExport.
    A demo module requires its component module, so its folder only loads where that module is
    installed too.

.PARAMETER Path
    The built module's folder, as Build-Module.ps1 returns it (output/<Module>/<Version>).

.EXAMPLE
    ./build/Test-BuiltModule.ps1 -Path (./build/Build-Module.ps1 -Module PowerShellUniversal.Component.Pivot)
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Path)
$ErrorActionPreference = 'Stop'

$manifest = Get-ChildItem -LiteralPath $Path -Filter '*.psd1' -File | Select-Object -First 1
if (-not $manifest) { throw "$Path holds no module manifest." }
$expected = @((Import-PowerShellDataFile -LiteralPath $manifest.FullName).FunctionsToExport | Sort-Object)
$endpoint = Join-Path $PSScriptRoot 'Add-EndpointType.ps1'
$command = ". '{0}'; (Import-Module '{1}' -PassThru).ExportedFunctions.Keys | Sort-Object" -f $endpoint.Replace("'", "''"), $manifest.FullName.Replace("'", "''")
$exported = @(& (Join-Path $PSHOME 'pwsh') -NoProfile -NonInteractive -Command $command)
if ($LASTEXITCODE) { throw "$($manifest.Name) does not load: $($exported -join ' ')" }
$difference = Compare-Object -ReferenceObject $expected -DifferenceObject $exported
if ($difference) {
    throw ('{0} exports other commands than its manifest names: {1}' -f $manifest.Name, (($difference | ForEach-Object { '{0} {1}' -f $_.SideIndicator, $_.InputObject }) -join ', '))
}
