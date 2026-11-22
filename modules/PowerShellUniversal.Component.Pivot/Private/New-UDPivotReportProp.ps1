function New-UDPivotReportProp {
    <#
    .SYNOPSIS
        The props every report has: what PSU renders, the report's keys, its data and its basic options.
    .PARAMETER Id
        The report's -Id.
    .PARAMETER StorageKey
        The key the browser keeps the reader's view under.
    .PARAMETER ColumnName
        The names of the report's columns.
    .PARAMETER Rows
        The rows of -Data (ConvertTo-PSUComponentData), for a report without a server.
    .PARAMETER Server
        The result of Resolve-UDPivotReportRecord, for a report on a server source.
    .PARAMETER Locale
        The report's language.
    .PARAMETER TimeZone
        The time zone dates are shown in.
    .PARAMETER Theme
        Auto, Light or Dark.
    .PARAMETER FileName
        The name of exported files.
    .PARAMETER NoDrillDown
        No drill-down panel.
    .PARAMETER NoAddressBar
        The view is not kept in the address.
    .EXAMPLE
        $props = New-UDPivotReportProp -Id 'tickets' -StorageKey 'tickets' -ColumnName 'Team' -Rows $rows -Locale 'en-US' -TimeZone 'UTC' -Theme 'Auto' -FileName 'pivot'
    .OUTPUTS
        System.Collections.Hashtable
    #>
    # describes a component for PSU to render; changes no state, so no ShouldProcess
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Id,
        [Parameter(Mandatory)][AllowEmptyString()][string]$StorageKey,
        [AllowEmptyCollection()][object[]]$ColumnName,
        [AllowNull()][object]$Rows,
        [AllowNull()][object]$Server,
        [Parameter(Mandatory)][string]$Locale,
        [Parameter(Mandatory)][string]$TimeZone,
        [Parameter(Mandatory)][string]$Theme,
        [Parameter(Mandatory)][string]$FileName,
        [switch]$NoDrillDown,
        [switch]$NoAddressBar
    )
    $props = @{
        assetId     = $Script:AssetId
        isPlugin    = $true
        type        = 'ud-pivot-report'
        id          = $Id
        storageKey  = $StorageKey
        # PSU camelCases the keys of the rows on their way to the browser; the report shows the field
        # names as they are, so the original ones travel along as values (which PSU leaves alone)
        columnNames = $ColumnName
        locale      = $Locale
        timeZone    = $TimeZone
        theme       = $Theme.ToLowerInvariant()
        fileName    = $FileName
        drillDown   = -not $NoDrillDown
        addressBar  = -not $NoAddressBar
    }
    # the server's answer as it came: PSU passes a string on as it is, and the report parses it
    if ($Server.Records) { $props['records'] = $Server.Records.Text }
    elseif ($Server.Problem) { $props['problem'] = $Server.Problem }
    else { $props['data'] = $Rows }
    $props
}
