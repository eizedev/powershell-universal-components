function New-UDPivotFileTemplateStore {
    <#
    .SYNOPSIS
        A template store that keeps the readers' views as view files in a folder on the server.
    .DESCRIPTION
        For New-UDPivotReport -TemplateStore. Every signed-in reader saves views under "My views" and sees
        them on every device; views in the shared folder are listed for everyone under "Shared views",
        and only readers with a role of New-UDPivotReport -AdminRole publish or delete them.

        Layout below -Path: users/<hash of the user name>/ holds a reader's own views, shared/ the shared
        ones, each view a pivotkit view file <slug>-<hash>.pivotkit.json (the files Download view in the
        Views menu writes; shared/ also works as a -TemplatePath). Writes go to a new file that then
        replaces the old one, under a lock per folder, so two saves at the same moment never leave half a
        file or lose the count. -MaxUserViews and -MaxSharedViews cap the number of views per folder.

        Without -Path the store lies next to the PSU repository ($Repository), never inside it: a
        repository synced with git would pick the files up. On several PSU nodes (high availability) a
        local folder is per node: use a shared folder, or a store on a database
        (New-UDPivotTemplateStore).
    .PARAMETER Path
        The folder. Default: pivot-views next to the repository folder ($Repository of the app, else
        $env:Data__RepositoryPath).
    .PARAMETER MaxUserViews
        The most views a reader keeps. Default: 50.
    .PARAMETER MaxSharedViews
        The most shared views. Default: 200.
    .EXAMPLE
        $store = New-UDPivotFileTemplateStore
        New-UDPivotReport -Id 'tickets' -Data $tickets -TemplateStore $store -AdminRole 'Administrator'
    .EXAMPLE
        New-UDPivotFileTemplateStore -Path 'D:\PSUData\pivot-views' -MaxUserViews 20
    .OUTPUTS
        System.Management.Automation.PSCustomObject (UDPivotTemplateStore)
    .LINK
        https://powershell-universal-components.eize.dev/pivot/stores/
    #>
    # describes a store; creates nothing until the first save, so no ShouldProcess
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [ValidateNotNullOrEmpty()][string]$Path,
        [ValidateRange(1, 500)][int]$MaxUserViews = $Script:DefaultMaxUserViews,
        [ValidateRange(1, 500)][int]$MaxSharedViews = $Script:DefaultMaxSharedViews
    )
    # -ErrorVariable gets the error itself, not each step it took through the module
    $errorMark = Get-UDPivotErrorMark -Cmdlet $PSCmdlet
    trap { Reset-UDPivotErrorVariable -Mark $errorMark; throw $_ }
    if (-not $Path) {
        # $Repository of the app script that calls this (PSU's documented global variable)
        $repository = $PSCmdlet.SessionState.PSVariable.GetValue('Repository')
        if (-not $repository) { $repository = $env:Data__RepositoryPath }
        if (-not $repository) { throw 'New-UDPivotFileTemplateStore: no $Repository to put the store next to; pass -Path.' }
        $Path = Join-Path (Split-Path -Parent ([string]$repository)) 'pivot-views'
    }
    [pscustomobject]@{
        PSTypeName     = 'UDPivotTemplateStore'
        Kind           = 'File'
        Path           = [System.IO.Path]::GetFullPath($Path)
        Get            = $null
        Save           = $null
        Delete         = $null
        Publish        = $null
        MaxUserViews   = $MaxUserViews
        MaxSharedViews = $MaxSharedViews
    }
}
