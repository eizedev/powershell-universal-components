function New-UDPivotReportPlaceholder {
    <#
    .SYNOPSIS
        A placeholder in the pivot report's own look, for New-UDDynamic -LoadingComponent: it shows the
        report's frame while the server builds the data.
    .DESCRIPTION
        PSU renders a component only once its properties have arrived, and the report's properties hold
        all of its rows: with thousands of rows the page stays empty until the server has converted and
        sent them. Put the report into New-UDDynamic and this placeholder into its -LoadingComponent:

            New-UDDynamic -Id 'tickets-report' -LoadingComponent {
                New-UDPivotReportPlaceholder -Height 640px
            } -Content {
                New-UDPivotReport -Id 'tickets' -Data $tickets -Height 640px
            }

        The placeholder comes with the page and shows pivotkit's own skeleton of the report: the field
        list, the toolbar, the zones and table rows as grey bars, in the report's colours (light, dark, a
        corporate design from the app's stylesheet); the bars pulse unless the reader asked for reduced
        motion. Screen readers hear "Loading the report". It also makes the browser load the module's code at
        once, while the server is still working on the data.

        Give it the -Height, -Theme, -Locale and -Label of the report, so nothing moves when the report
        replaces it.
    .PARAMETER Id
        Component id. Default: a new GUID.
    .PARAMETER Height
        Height, as -Height of New-UDPivotReport (e.g. 640px, 80vh or 640). Default: the report's default
        height.
    .PARAMETER Theme
        Auto (follows the app's light/dark switch, default), Light or Dark.
    .PARAMETER Locale
        The language of the text screen readers hear: German for de-*, English otherwise. Default: en-US.
    .PARAMETER Label
        The name screen readers hear for it, as -Label of the report.
    .PARAMETER ClassName
        CSS class of the outer element.
    .PARAMETER Style
        CSS styles of the outer element, e.g. @{ maxWidth = '1200px' }.
    .EXAMPLE
        New-UDDynamic -Id 'tickets-report' -LoadingComponent { New-UDPivotReportPlaceholder } -Content {
            New-UDPivotReport -Id 'tickets' -Data (Invoke-Sqlcmd -Query 'SELECT * FROM Tickets')
        }
    .EXAMPLE
        New-UDDynamic -LoadingComponent { New-UDPivotReportPlaceholder -Height 560px -Locale de-DE } -Content {
            New-UDPivotReport -Data $tickets -Height 560px -Locale de-DE
        }
    .OUTPUTS
        System.Collections.Hashtable
    .LINK
        https://powershell-universal-components.eize.dev/pivot/
    #>
    # describes a component for PSU to render; changes no state, so no ShouldProcess
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string]$Id = [guid]::NewGuid().ToString(),
        [ValidateScript({ $_ -match $Script:HeightPattern }, ErrorMessage = 'Height "{0}": expected a CSS length such as 640px, 80vh or 640.')][string]$Height,
        [ValidateSet('Auto', 'Light', 'Dark')][string]$Theme = 'Auto',
        [ValidateScript({ $_ -match $Script:LocalePattern }, ErrorMessage = 'Locale "{0}": expected a language tag such as en-US or de-DE.')][string]$Locale = 'en-US',
        [ValidateLength(1, 120)][string]$Label,
        [string]$ClassName,
        [hashtable]$Style
    )
    # -ErrorVariable gets the error itself, not each step it took through the module
    $errorMark = Get-UDPivotErrorMark -Cmdlet $PSCmdlet
    trap { Reset-UDPivotErrorVariable -Mark $errorMark; throw $_ }

    if (-not $Script:AssetId) { throw $Script:MissingAssetMessage }
    $props = @{
        assetId  = $Script:AssetId
        isPlugin = $true
        type     = 'ud-pivot-placeholder'
        id       = $Id
        theme    = $Theme.ToLowerInvariant()
        locale   = $Locale
    }
    if ($Height) { $props['height'] = ConvertTo-UDPivotHeight -Height $Height }
    if ($Label) { $props['label'] = $Label }
    if ($ClassName) { $props['className'] = $ClassName }
    if ($Style) { $props['style'] = $Style }
    $props
}
