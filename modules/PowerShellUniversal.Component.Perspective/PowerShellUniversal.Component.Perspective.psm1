$ErrorActionPreference = 'Stop'

#region Shared code and asset registration
# The build copies the repository's shared/powershell/*.ps1 into Private/; from a source checkout
# they are loaded from there directly.
$private = Join-Path $PSScriptRoot 'Private'
if (-not (Test-Path -LiteralPath $private)) { $private = Join-Path $PSScriptRoot '..' '..' 'shared' 'powershell' }
foreach ($file in Get-ChildItem -LiteralPath $private -Filter '*.ps1' -File) { . $file.FullName }
$Script:AssetId = Register-PSUComponentAsset -Path $PSScriptRoot
#endregion

function New-UDPerspective {
    <#
    .SYNOPSIS
        A FINOS Perspective datagrid, pivot table and chart in one, for PowerShell Universal apps.
    .DESCRIPTION
        Pass the data as it comes - a DataTable from SQL, objects from Invoke-RestMethod or any
        PowerShell command. Readers rearrange the view themselves in the configuration panel: group
        and split by columns (a pivot), filter, sort, aggregate, switch between the datagrid and the
        charts. The parameters set the view it starts with. The data is held by Perspective's
        WebAssembly engine in a Web Worker in the browser, so tens of thousands of rows stay fast.
        Column names are matched without regard to case.
    .PARAMETER Id
        Component id. Default: a new GUID.
    .PARAMETER Data
        Rows: a DataTable, objects, hashtables, or a script block returning them.
    .PARAMETER Plugin
        The view to start with: Datagrid (default), X Bar, Y Bar, Y Line, Y Area, Y Scatter,
        XY Scatter, Treemap, Sunburst, Heatmap.
    .PARAMETER Columns
        Columns to show, in this order. Default: all.
    .PARAMETER GroupBy
        Row groups (pivot rows), e.g. Customer, Team.
    .PARAMETER SplitBy
        Column groups (pivot columns), e.g. Priority.
    .PARAMETER Aggregates
        How grouped values are combined per column: @{ Tickets = 'sum'; LeadHours = 'avg' } (Perspective's
        names: sum, avg, count, distinct count, min, max, median, first, last, ...).
    .PARAMETER Sort
        'Column' (ascending) or 'Column desc', one or more.
    .PARAMETER Filter
        'Column == value', 'Column > 5', 'Column contains text', one or more.
    .PARAMETER Settings
        Open the configuration panel at the start (readers can open it any time).
    .PARAMETER Config
        Perspective's full viewer configuration (as from the viewer's "copy config"), merged over the
        one the parameters built.
    .PARAMETER Height
        Height, e.g. 480px (default) or 70vh.
    .PARAMETER Width
        Width. Default: the container's.
    .PARAMETER Theme
        Auto (follows the app's light/dark switch, default), Light or Dark.
    .PARAMETER ClassName
        CSS class of the outer element.
    .PARAMETER Style
        CSS styles of the outer element.
    .PARAMETER OnClick
        Runs on the server when a cell is clicked. $EventData: row (the values of the clicked row or
        group), columnNames, filter (the group and split values that lead to the cell, as
        [column, operator, value]).
    .EXAMPLE
        New-UDPerspective -Data (Get-Process | Select-Object Name, CPU, WorkingSet64) -Sort 'CPU desc'
    .EXAMPLE
        New-UDPerspective -Data $tickets -GroupBy Team -SplitBy Priority -Columns Id -Aggregates @{ Id = 'count' } -Settings
    .OUTPUTS
        System.Collections.Hashtable
    #>
    # describes a component for PSU to render; changes no state, so no ShouldProcess
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string]$Id = [guid]::NewGuid().ToString(),
        [Parameter(Mandatory)][AllowNull()][object]$Data,
        [ValidateSet('Datagrid', 'X Bar', 'Y Bar', 'Y Line', 'Y Area', 'Y Scatter', 'XY Scatter', 'Treemap', 'Sunburst', 'Heatmap')]
        [string]$Plugin = 'Datagrid',
        [string[]]$Columns,
        [string[]]$GroupBy,
        [string[]]$SplitBy,
        [hashtable]$Aggregates,
        [string[]]$Sort,
        [string[]]$Filter,
        [switch]$Settings,
        [hashtable]$Config,
        [string]$Height = '480px',
        [string]$Width,
        [ValidateSet('Auto', 'Light', 'Dark')][string]$Theme = 'Auto',
        [string]$ClassName,
        [hashtable]$Style,
        [Endpoint]$OnClick
    )

    if (-not $Script:AssetId) {
        throw 'PowerShellUniversal.Component.Perspective: the JavaScript bundle (index.<hash>.bundle.js) was not found next to the module, or the module was imported outside PowerShell Universal.'
    }
    if ($OnClick) { $OnClick.Register($Id, $PSCmdlet) }

    # one array (ConvertTo-PSUComponentData returns it as a single object; @() would nest it)
    $rows = ConvertTo-PSUComponentData -InputObject $Data
    $props = @{
        assetId  = $Script:AssetId
        isPlugin = $true
        type     = 'ud-perspective'
        id       = $Id
        data     = $rows
        # PSU camelCases the keys of the rows on their way to the browser; Perspective shows the names
        # as they are, so the original ones travel along as values (which PSU leaves alone)
        columnNames = @($rows | Select-Object -First 1 | ForEach-Object { $_.PSObject.Properties.Name })
        plugin   = $Plugin
        settings = [bool]$Settings
        height   = $Height
        theme    = $Theme.ToLowerInvariant()
    }
    $map = [ordered]@{ Columns = 'columns'; GroupBy = 'groupBy'; SplitBy = 'splitBy'; Aggregates = 'aggregates'; Sort = 'sort'; Filter = 'filter'; Config = 'config'; Width = 'width'; ClassName = 'className'; Style = 'style' }
    foreach ($name in $map.Keys) {
        if ($PSBoundParameters.ContainsKey($name)) { $props[$map[$name]] = $PSBoundParameters[$name] }
    }
    if ($OnClick) { $props['onClick'] = $OnClick }
    $props
}

Export-ModuleMember -Function New-UDPerspective
