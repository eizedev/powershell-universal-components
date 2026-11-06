function Register-PSUComponentAsset {
    <#
    .SYNOPSIS
        Registers a component module's JavaScript files with PSU and returns the asset id of its bundle.
    .DESCRIPTION
        PSU serves every registered file; the component's hashtable points at the main bundle by its
        asset id. Only index.<hash>.bundle.js counts (never a ._index... file macOS may leave behind).
        Outside PSU (tests, a plain pwsh) there is nothing to register and the result is $null.
    .PARAMETER Path
        The module folder ($PSScriptRoot of the psm1).
    .OUTPUTS
        System.String - the asset id, or $null.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string]$Path)

    if (-not ('UniversalDashboard.Services.AssetService' -as [type])) { return $null }
    $id = $null
    foreach ($file in Get-ChildItem -Path $Path -Filter '*.js' -File) {
        $asset = [UniversalDashboard.Services.AssetService]::Instance.RegisterAsset($file.FullName)
        if ($file.Name -match '^index\.[0-9a-f]+\.bundle\.js$') { $id = $asset }
    }
    $id
}
