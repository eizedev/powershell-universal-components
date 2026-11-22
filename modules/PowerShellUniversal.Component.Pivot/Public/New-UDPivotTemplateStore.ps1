function New-UDPivotTemplateStore {
    <#
    .SYNOPSIS
        A template store on your own storage (a database, Valkey or Redis, S3): you write how a view is
        stored, the module does the rest.
    .DESCRIPTION
        For New-UDPivotReport -TemplateStore. The module decides who may do what (the signed-in user,
        -AdminRole for shared views, checked on the server), checks every name and view, applies the
        limits and writes the view file; the script blocks only store and load. Each gets one argument,
        $Request:

        - Get: Scope ('user' or 'shared'), User (the user name; $null for shared), UserKey (a hash of the
          user name, safe in a key or file name). Return the stored views: view file texts (the Json of
          a save), objects with Json and FileName (where it is stored), or objects with Name and View. The
          module checks each one again.
        - Save: Scope, User, UserKey, Name (checked), FileName, Key ('users/<UserKey>/<FileName>' or
          'shared/<FileName>'), Json (the view file to store) and View (the checked view). Store it under
          FileName, replacing what is there: for a name the scope has (the same characters in the same
          case, as pivotkit compares names) the module passes the FileName of that view, so a save
          replaces it; for a new name <slug>-<hash>.pivotkit.json that no stored view has.
        - Delete: Scope, User, UserKey, Name, FileName, Key.
        - Publish (optional): as Save with Scope 'shared' and User the publisher. Without it, publishing
          calls Save with Scope 'shared'.

        Throw to refuse: the reader sees the message. The script blocks run in the runspace of the app
        script that defined them and do not see $User or $Roles: use $Request. PSU runs event handlers
        in runspaces of their own, so a script block needs every module and variable it uses (Import-Module
        inside it).
    .PARAMETER Get
        Returns the views of one scope (and user).
    .PARAMETER Save
        Stores one view.
    .PARAMETER Delete
        Removes one view.
    .PARAMETER Publish
        Stores a shared view, when that differs from Save with Scope 'shared'.
    .PARAMETER MaxUserViews
        The most views a reader keeps. Default: 50.
    .PARAMETER MaxSharedViews
        The most shared views. Default: 200.
    .EXAMPLE
        # SQL Server: a table PivotViews (Scope, UserKey, FileName, Json)
        $store = New-UDPivotTemplateStore -Get {
            param($Request)
            Invoke-Sqlcmd -ConnectionString $cs -Query 'SELECT Json FROM PivotViews WHERE Scope = @s AND UserKey = @u' -Variable ... | ForEach-Object Json
        } -Save { param($Request) ... } -Delete { param($Request) ... }
    .OUTPUTS
        System.Management.Automation.PSCustomObject (UDPivotTemplateStore)
    .LINK
        https://powershell-universal-components.eize.dev/pivot/templates/
    #>
    # describes a store; changes nothing itself, so no ShouldProcess
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][scriptblock]$Get,
        [Parameter(Mandatory)][scriptblock]$Save,
        [Parameter(Mandatory)][scriptblock]$Delete,
        [scriptblock]$Publish,
        [ValidateRange(1, 500)][int]$MaxUserViews = $Script:DefaultMaxUserViews,
        [ValidateRange(1, 500)][int]$MaxSharedViews = $Script:DefaultMaxSharedViews
    )
    # -ErrorVariable gets the error itself, not each step it took through the module
    $errorMark = Get-UDPivotErrorMark -Cmdlet $PSCmdlet
    trap { Reset-UDPivotErrorVariable -Mark $errorMark; throw $_ }
    [pscustomobject]@{
        PSTypeName     = 'UDPivotTemplateStore'
        Kind           = 'Custom'
        Path           = $null
        Get            = $Get
        Save           = $Save
        Delete         = $Delete
        Publish        = $Publish
        MaxUserViews   = $MaxUserViews
        MaxSharedViews = $MaxSharedViews
    }
}
