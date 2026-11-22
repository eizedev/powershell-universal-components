$ErrorActionPreference = 'Stop'

# One function per file: Public/ holds the exported commands, Private/ the helpers. A new file in
# Public/ also goes into FunctionsToExport in the .psd1, or PowerShell does not export it.
$public = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -File)
$private = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -File)
# The build copies the repository's shared/powershell/*.ps1 into Private/ and writes SHARED.txt there;
# from a source checkout they are loaded from shared/ directly.
if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Private' 'SHARED.txt'))) {
    $private += Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '..' '..' 'shared' 'powershell') -Filter '*.ps1' -File
}
foreach ($file in $public + $private) { . $file.FullName }

# The module's limits, patterns and state ($Script: variables), one file per topic. They load after
# the functions: the report engine's settings call one.
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'Private' 'Settings') -Filter '*.ps1' -File) { . $file.FullName }

# the bundle's asset id for the hashtable New-UDPivotReport returns (shared/powershell/Register-PSUComponentAsset.ps1)
$Script:AssetId = Register-PSUComponentAsset -Path $PSScriptRoot

Export-ModuleMember -Function $public.BaseName
