function Remove-UDPivotStoredFile {
    <#
    .SYNOPSIS
        Deletes one stored view by its file name: the file of a file store, or through a custom store's
        Delete.
    .PARAMETER Context
        The result of New-UDPivotStoreContext.
    .PARAMETER FileName
        The view's file name.
    .EXAMPLE
        Remove-UDPivotStoredFile -Context $context -FileName 'sales.pivotkit.json'
    .OUTPUTS
        None.
    #>
    # a step of Invoke-UDPivotTemplateStore, which decided before that the view goes
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType([void])]
    param([Parameter(Mandatory)][pscustomobject]$Context, [Parameter(Mandatory)][string]$FileName)
    if ($Context.Store.Kind -eq 'File') {
        $target = Join-Path $Context.Folder $FileName
        if (Test-Path -LiteralPath $target -PathType Leaf) { Remove-Item -LiteralPath $target -Force }
    }
    else { $null = & $Context.Store.Delete ([pscustomobject](Get-UDPivotStoreRequest -Context $Context -FileName $FileName)) }
}
