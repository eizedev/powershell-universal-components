function Get-UDPivotStoreView {
    <#
    .SYNOPSIS
        The views a template store holds for a report: the shared ones and the reader's own. A broken
        store must not break the page: its views are left out with a warning.
    .PARAMETER Store
        A store of New-UDPivotFileTemplateStore or New-UDPivotTemplateStore.
    .PARAMETER UserName
        The signed-in reader; without one there are no own views.
    .PARAMETER SourceId
        The id of the report's data.
    .PARAMETER IsAdmin
        The reader may delete shared views.
    .EXAMPLE
        $storeViews = Get-UDPivotStoreView -Store $store -UserName $user -SourceId 'tickets' -IsAdmin:$false
    .OUTPUTS
        System.Collections.Hashtable: shared and user, each a list of templates as the report takes them.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][object]$Store,
        [AllowEmptyString()][AllowNull()][string]$UserName,
        [Parameter(Mandatory)][AllowEmptyString()][string]$SourceId,
        [bool]$IsAdmin
    )
    $views = @{ shared = @(); user = @() }
    foreach ($scope in 'shared', 'user') {
        if ($scope -eq 'user' -and -not $UserName) { continue }
        try {
            $views[$scope] = @(foreach ($t in @(Invoke-UDPivotTemplateStore -Store $Store -Action List -Scope $scope -UserName $UserName -SourceId $SourceId)) {
                    [pscustomobject]@{ name = $t.Name; view = $t.View; scope = $scope; deletable = ($scope -eq 'user' -or $IsAdmin) }
                })
        }
        catch { Write-Warning ('Pivot template store ({0} views) left out: {1}' -f $scope, $_.Exception.Message) }
    }
    $views
}
