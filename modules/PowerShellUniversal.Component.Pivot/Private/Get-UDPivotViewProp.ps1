function Get-UDPivotViewProp {
    <#
    .SYNOPSIS
        The views New-UDPivotReport opens with: -View, and the reader's stored -SavedView.
    .PARAMETER Bound
        New-UDPivotReport's $PSBoundParameters.
    .PARAMETER ViewName
        Set when -View names a view of the server (-Uri): it is no view of its own then.
    .EXAMPLE
        $props += Get-UDPivotViewProp -Bound $PSBoundParameters -ViewName $viewName
    .OUTPUTS
        System.Collections.Hashtable: the props to add.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Bound,
        [string]$ViewName
    )
    $props = @{}
    if ($Bound.ContainsKey('View') -and $null -ne $Bound['View'] -and -not $ViewName) {
        try { $props['view'] = ConvertFrom-UDPivotView -InputObject $Bound['View'] }
        catch { throw ('-View: {0}' -f $_.Exception.Message) }
    }
    if ($Bound.ContainsKey('SavedView') -and $null -ne $Bound['SavedView']) {
        # the reader's stored view is user data: a broken one must not break the page
        try { $props['savedView'] = ConvertFrom-UDPivotView -InputObject $Bound['SavedView'] }
        catch { Write-Warning ('-SavedView left out: {0}' -f $_.Exception.Message) }
    }
    $props
}
