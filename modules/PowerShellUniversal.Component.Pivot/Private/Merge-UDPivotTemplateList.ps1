function Merge-UDPivotTemplateList {
    <#
    .SYNOPSIS
        The Views menu of a report: the shipped views, the store's shared views and the reader's own.
    .DESCRIPTION
        A shared view of the store takes the place of a shipped shared view of its name: Publish and
        Save write a name the app ships into the store, and the Views menu must show that change. Names
        match as in pivotkit's Views menu and the store's upsert (same characters, same case).
    .PARAMETER Shipped
        The views of Get-UDPivotShippedTemplate.
    .PARAMETER StoreView
        The views of Get-UDPivotStoreView (shared and user).
    .EXAMPLE
        $list = Merge-UDPivotTemplateList -Shipped $shipped -StoreView $storeViews
    .OUTPUTS
        System.Collections.Generic.List[object]
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[object]])]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$Shipped,
        [Parameter(Mandatory)][hashtable]$StoreView
    )
    $list = [System.Collections.Generic.List[object]]::new()
    $replaced = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($t in $Shipped) {
        $fromStore = if ($t.scope -eq 'shared') { @($StoreView['shared'] | Where-Object { $_.name -ceq $t.name }) } else { @() }
        if (-not $fromStore.Count) { $list.Add($t) }
        elseif ($replaced.Add($t.name)) { $list.AddRange([object[]]$fromStore) }
    }
    foreach ($t in @($StoreView['shared'] | Where-Object { -not $replaced.Contains($_.name) }) + @($StoreView['user'])) { $list.Add($t) }
    , $list
}
