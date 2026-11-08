function Resolve-ShowcasePath {
    <#
    .SYNOPSIS
        Returns the full path of a file the showcase ships, in the built module or in the source tree.
    .DESCRIPTION
        The built module carries the documentation's examples, the data snapshots and the ticket
        showcase at the paths Build.psd1 names. In the source tree they are at their source; Build.psd1
        maps one to the other, so the module also runs straight from a clone of the repository.
    .PARAMETER Path
        Path below the built module, e.g. Data or Apps/Docs/examples.ps1.
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string]$Path)

    $built = Join-Path $PSScriptRoot $Path
    if (Test-Path -LiteralPath $built) { return $built }
    $buildFile = Join-Path $PSScriptRoot 'Build.psd1'
    if (Test-Path -LiteralPath $buildFile) {
        $include = (Import-PowerShellDataFile -LiteralPath $buildFile).Include
        foreach ($key in $include.Keys) {
            if ($Path -eq $key -or $Path.StartsWith("$key/")) {
                $source = Join-Path $PSScriptRoot '..' '..' $include[$key]
                $rest = $Path.Substring($key.Length).TrimStart('/')
                if ($rest) { $source = Join-Path $source $rest }
                if (Test-Path -LiteralPath $source) { return (Resolve-Path -LiteralPath $source).Path }
            }
        }
    }
    throw ('The showcase misses {0}; build the module with build/Build-Module.ps1.' -f $Path)
}

function Get-UDPivotShowcaseData {
    <#
    .SYNOPSIS
        Answers a public web API call of the showcase from the snapshot shipped with the module, or live.
    .DESCRIPTION
        The showcase's pages call this where an app calls Invoke-RestMethod, so they work without
        internet access. Without -Live the answer comes from the module's Data folder, one file per
        address (https://endoflife.date/api/python.json is Data/endoflife.date/api/python.json; an
        address with a query string is Data/<host>/<path>.json, and Data/Addresses.psd1 holds the
        exact address it was fetched from). With -Live it calls Invoke-RestMethod with a 30 second
        timeout. Sources, licences and the attribution each source asks for: Data/SOURCES.md.
    .PARAMETER Uri
        The https address of the API call.
    .PARAMETER Live
        Fetch the address instead of reading the snapshot.
    .EXAMPLE
        Get-UDPivotShowcaseData 'https://endoflife.date/api/python.json'
    .OUTPUTS
        What Invoke-RestMethod returns for the address (a JSON array is one object in the pipeline).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][uri]$Uri,
        [switch]$Live
    )

    if ($Uri.Scheme -ne 'https') { throw ('Only https addresses: {0}' -f $Uri) }
    if ($Live) { return Invoke-RestMethod -Uri $Uri -TimeoutSec 30 }

    $data = Resolve-ShowcasePath -Path 'Data'
    $relative = '{0}{1}' -f $Uri.Host, $Uri.AbsolutePath
    if (-not [System.IO.Path]::GetExtension($relative)) { $relative += '.json' }
    if ($Uri.Query) {
        # a snapshot stands for exactly the address it was fetched from, query included
        $addresses = Import-PowerShellDataFile -LiteralPath (Join-Path $data 'Addresses.psd1')
        if ($addresses[$relative] -ne $Uri.AbsoluteUri) { throw ('No snapshot of {0} in the module; use -Live.' -f $Uri) }
    }
    $file = Join-Path $data $relative
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw ('No snapshot of {0} in the module; use -Live.' -f $Uri) }
    Get-Content -LiteralPath $file -Raw | ConvertFrom-Json -NoEnumerate
}

function New-UDPivotShowcase {
    <#
    .SYNOPSIS
        Returns the showcase app of PowerShellUniversal.Component.Pivot.
    .DESCRIPTION
        The app shows New-UDPivotReport on public data and on generated data: the three pivot examples
        of the documentation on software release cycles from endoflife.date (one line; start view,
        field names and templates; an app with loading, views per reader and roles), daily weather of
        six cities from Open-Meteo, an upload page for CSV and JSON files, and the ticket showcase of the
        pivot module (5,000 generated tickets, templates, events, field descriptions, page layouts).
        Public data comes from snapshots shipped with the module, so the app works without internet
        access; a switch on each page (or -LiveData) fetches it from the APIs instead. A language switch
        shows the report in English or German.
        Use it as the whole content of an app:
            Import-Module PowerShellUniversal.Component.Pivot.Demo
            New-UDPivotShowcase
    .PARAMETER LiveData
        Start with live data from the public APIs instead of the shipped snapshots (needs internet
        access from the PSU server).
    .PARAMETER Locale
        The language the report starts in: en-GB (default) or de-DE.
    .EXAMPLE
        New-PSUApp -Name 'PivotShowcase' -BaseUrl '/pivot-showcase' -Content { New-UDPivotShowcase }
    .OUTPUTS
        The app PSU renders (New-UDApp).
    #>
    # returns the app for PSU to render; changes no state, so no ShouldProcess (as New-UDPivotReport)
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param(
        [switch]$LiveData,
        [ValidateSet('en-GB', 'de-DE')][string]$Locale = 'en-GB'
    )

    & (Join-Path $PSScriptRoot 'Apps' 'Showcase.ps1') -LiveData:$LiveData -Locale $Locale
}

Export-ModuleMember -Function New-UDPivotShowcase, Get-UDPivotShowcaseData
