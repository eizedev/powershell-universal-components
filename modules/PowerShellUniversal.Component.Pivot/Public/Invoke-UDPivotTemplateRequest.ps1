function Invoke-UDPivotTemplateRequest {
    <#
    .SYNOPSIS
        Saves, publishes or deletes a view for the report's event handlers; decides on the server who
        may do it.
    .DESCRIPTION
        New-UDPivotReport -TemplateStore registers event handlers that call this function with the
        $EventData of the report and the $User and $Roles PSU sets for the event. A reader saves and
        deletes their own views; publishing and deleting shared views needs a role of -AdminRole, checked
        here with the event's $Roles - never with anything the browser sends. Returns nothing on success,
        @{ error = '...' } when it refuses (the report shows the text).
    .PARAMETER Key
        The key of the report's store (Register-UDPivotTemplateStore).
    .PARAMETER Action
        Save, Publish or Delete.
    .PARAMETER EventData
        The report's $EventData: name, view, scope.
    .PARAMETER UserName
        $User of the event.
    .PARAMETER Roles
        $Roles of the event.
    .EXAMPLE
        Invoke-UDPivotTemplateRequest -Key $key -Action Save -EventData $EventData -UserName $User -Roles $Roles
    .OUTPUTS
        System.Collections.Hashtable on refusal.
    .LINK
        https://powershell-universal-components.eize.dev/pivot/templates/
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{32}$')][string]$Key,
        [Parameter(Mandatory)][ValidateSet('Save', 'Publish', 'Delete')][string]$Action,
        [AllowNull()][object]$EventData,
        [AllowNull()][AllowEmptyString()][string]$UserName,
        [AllowNull()][AllowEmptyCollection()][string[]]$Roles
    )
    # -ErrorVariable gets the error itself, not each step it took through the module
    $errorMark = Get-UDPivotErrorMark -Cmdlet $PSCmdlet
    trap { Reset-UDPivotErrorVariable -Mark $errorMark; throw $_ }
    $entry = $null
    if (-not (Get-UDPivotStoreRegistry).TryGetValue($Key, [ref]$entry)) {
        return @{ error = 'This page is out of date (the app was restarted); reload it.' }
    }
    $settings = $entry.Settings
    $data = if ($null -ne $EventData) { $EventData } else { @{} }
    $scope = if ($Action -eq 'Delete' -and (Get-UDPivotEntryValue -InputObject $data -Name 'scope') -eq 'shared') { 'shared' } elseif ($Action -eq 'Publish') { 'shared' } else { 'user' }
    $isAdmin = Test-UDPivotRole -Roles $Roles -AdminRole $settings.AdminRole
    if ($scope -eq 'shared' -and -not $isAdmin) { return @{ error = 'Only admins can change shared views.' } }
    if ($scope -eq 'user' -and [string]::IsNullOrWhiteSpace($UserName)) { return @{ error = 'Sign in to keep your own views.' } }
    try {
        $arguments = @{
            Store      = $settings.Store
            Action     = $Action
            Scope      = $scope
            UserName   = $UserName
            Name       = Get-UDPivotEntryValue -InputObject $data -Name 'name'
            SourceId   = $settings.SourceId
            SourceName = $settings.SourceName
        }
        # $null: the default of ConvertTo-UDPivotViewFile. A path takes the origin of an https default,
        # else of this event's request ($Headers of the handler: PSU sends Origin with an event)
        if ($null -ne $settings.SchemaUrl) { $arguments['SchemaUrl'] = $settings.SchemaUrl }
        $arguments['Headers'] = $PSCmdlet.SessionState.PSVariable.GetValue('Headers')
        if ($Action -ne 'Delete') { $arguments['View'] = Get-UDPivotEntryValue -InputObject $data -Name 'view' }
        Invoke-UDPivotTemplateStore @arguments
    }
    catch {
        @{ error = $_.Exception.Message }
    }
}
