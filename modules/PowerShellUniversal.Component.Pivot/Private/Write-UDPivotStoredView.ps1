function Write-UDPivotStoredView {
    <#
    .SYNOPSIS
        Stores a view file: a file store writes a new file and then replaces the old one, so a reader
        never sees half a file; a custom store gets it through Publish (when it has one and the action is
        Publish) or Save.
    .PARAMETER Context
        The result of New-UDPivotStoreContext.
    .PARAMETER FileName
        The view's file name.
    .PARAMETER Json
        The view file.
    .PARAMETER View
        The checked view, for a custom store.
    .PARAMETER Publish
        The action is Publish.
    .EXAMPLE
        Write-UDPivotStoredView -Context $context -FileName 'sales.pivotkit.json' -Json $json -View $view
    .OUTPUTS
        None.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)][pscustomobject]$Context,
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string]$Json,
        [Parameter(Mandatory)][object]$View,
        [switch]$Publish
    )
    if ($Context.Store.Kind -eq 'File') {
        try { $null = New-Item -ItemType Directory -Path $Context.Folder -Force }
        catch {
            # the folder's path stays in the log; the reader gets the general text
            Write-Warning ('Pivot template store: the view store cannot create its folder: {0}' -f $_.Exception.Message)
            throw $Script:StoreFailedText
        }
        $target = Join-Path $Context.Folder $FileName
        $temp = Join-Path $Context.Folder ('.{0}.{1}.tmp' -f $FileName, [guid]::NewGuid().ToString('n'))
        try {
            [System.IO.File]::WriteAllText($temp, $Json, [System.Text.UTF8Encoding]::new($false))
            [System.IO.File]::Move($temp, $target, $true)
        }
        finally {
            if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
        }
        return
    }
    $save = Get-UDPivotStoreRequest -Context $Context -FileName $FileName
    $save['Json'] = $Json
    $save['View'] = $View
    if ($Publish -and $Context.Store.Publish) { $null = & $Context.Store.Publish ([pscustomobject]$save) }
    else { $null = & $Context.Store.Save ([pscustomobject]$save) }
}
