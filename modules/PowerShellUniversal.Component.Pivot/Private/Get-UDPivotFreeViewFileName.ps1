function Get-UDPivotFreeViewFileName {
    <#
    .SYNOPSIS
        The file name for a new view: one no other view holds (also one stored by hand). File names are
        compared without case, as on Windows and macOS.
    .PARAMETER Context
        The result of New-UDPivotStoreContext.
    .PARAMETER All
        Every stored view of the scope (Get-UDPivotStoredView).
    .PARAMETER Name
        The view's checked name.
    .PARAMETER ReportData
        The id of the report's data.
    .EXAMPLE
        $fileName = Get-UDPivotFreeViewFileName -Context $context -All $all -Name 'Sales' -ReportData 'tickets'
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][pscustomobject]$Context,
        [AllowEmptyCollection()][object[]]$All,
        [Parameter(Mandatory)][string]$Name,
        [AllowEmptyString()][string]$ReportData
    )
    $attempt = 0
    do {
        $fileName = Get-UDPivotViewFileName -Name $Name -SourceId $ReportData -Attempt $attempt
        $attempt++
        $taken = @($All | Where-Object { $_.Files -contains $fileName }).Count -or ($Context.Store.Kind -eq 'File' -and (Test-Path -LiteralPath (Join-Path $Context.Folder $fileName)))
    } while ($taken)
    $fileName
}
