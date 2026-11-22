function New-UDPivotStoreContext {
    <#
    .SYNOPSIS
        Where an action of Invoke-UDPivotTemplateStore works: the store, the scope (Publish writes shared
        views), the user's key, the folder of a file store, the most views it may hold and the request a
        custom store's script blocks get.
    .PARAMETER Store
        A store of New-UDPivotFileTemplateStore or New-UDPivotTemplateStore.
    .PARAMETER Action
        List, Save, Publish or Delete.
    .PARAMETER Scope
        user or shared.
    .PARAMETER UserName
        The signed-in user (scope user; the publisher for Publish).
    .EXAMPLE
        $context = New-UDPivotStoreContext -Store $store -Action List -Scope shared
    .OUTPUTS
        PSCustomObject with Store, Scope, UserKey, Folder, Max and Request.
    #>
    # describes where the store works; changes no state, so no ShouldProcess
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][object]$Store,
        [Parameter(Mandatory)][string]$Action,
        [Parameter(Mandatory)][string]$Scope,
        [AllowEmptyString()][string]$UserName
    )
    if (-not (Test-UDPivotTemplateStore -Store $Store)) { throw '-TemplateStore: expected a store of New-UDPivotFileTemplateStore or New-UDPivotTemplateStore.' }
    if ($Action -eq 'Publish') { $Scope = 'shared' }
    if ($Scope -eq 'user' -and [string]::IsNullOrWhiteSpace($UserName)) { throw 'Sign in to keep your own views.' }
    $userKey = if ($Scope -eq 'user') { Get-UDPivotSha256 -Text $UserName.Trim().ToLowerInvariant() -Length 24 }
    [pscustomobject]@{
        Store   = $Store
        Scope   = $Scope
        UserKey = $userKey
        Folder  = if ($Store.Kind -eq 'File') { if ($Scope -eq 'user') { Join-Path $Store.Path 'users' $userKey } else { Join-Path $Store.Path 'shared' } }
        Max     = if ($Scope -eq 'user') { $Store.MaxUserViews } else { $Store.MaxSharedViews }
        Request = [ordered]@{
            Scope   = $Scope
            User    = if ($Scope -eq 'user' -or $Action -eq 'Publish') { $UserName } else { $null }
            UserKey = $userKey
        }
    }
}
