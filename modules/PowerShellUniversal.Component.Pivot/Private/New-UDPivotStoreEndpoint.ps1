function New-UDPivotStoreEndpoint {
    <#
    .SYNOPSIS
        Registers a report's template store for the module's event handlers and returns the handlers
        the reader may use: Save and Delete of the own views for a signed-in reader, Delete and Publish
        of shared views for an admin.
    .DESCRIPTION
        Without a signed-in user the server cannot tell readers apart: their own views stay in the
        browser, so a reader without a name gets no Save handler.
    .PARAMETER Settings
        The store's settings for Register-UDPivotTemplateStore.
    .PARAMETER UserName
        The signed-in reader, or nothing.
    .PARAMETER IsAdmin
        The reader may change shared views.
    .EXAMPLE
        $handlers = New-UDPivotStoreEndpoint -Settings $settings -UserName $user -IsAdmin $false
    .OUTPUTS
        System.Collections.Hashtable: event parameter name (OnSaveTemplate, ...) to Endpoint.
    #>
    # creates endpoint objects and registers the store in this process, as New-UDPivotReport does
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][hashtable]$Settings,
        [AllowEmptyString()][AllowNull()][string]$UserName,
        [bool]$IsAdmin
    )
    $key = Register-UDPivotTemplateStore -Settings $Settings
    $handlers = @{}
    if ($UserName) { $handlers['OnSaveTemplate'] = New-UDPivotTemplateEndpoint -Key $key -Action Save }
    if ($UserName -or $IsAdmin) { $handlers['OnDeleteTemplate'] = New-UDPivotTemplateEndpoint -Key $key -Action Delete }
    if ($IsAdmin) { $handlers['OnPublishTemplate'] = New-UDPivotTemplateEndpoint -Key $key -Action Publish }
    $handlers
}
