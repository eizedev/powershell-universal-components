function Get-UDPivotReportTemplate {
    <#
    .SYNOPSIS
        The templates of New-UDPivotReport, its template store and who may change shared views.
    .DESCRIPTION
        Checks the template parameters, finds the reader and whether one of -AdminRole is theirs, lists
        the store's views and the shipped ones, registers the store's event handlers and builds the
        props the report gets for them.
    .PARAMETER Bound
        New-UDPivotReport's $PSBoundParameters.
    .PARAMETER Cmdlet
        New-UDPivotReport's $PSCmdlet: $User, $Roles and $DashboardName of the page that calls it, where
        -UserName and -Roles are not given. A script block defined in the app script has neither
        (measured), so -UserName and -Roles can be passed.
    .PARAMETER Source
        The report's data source (id and name).
    .PARAMETER SchemaUrl
        The $schema the store writes into view files.
    .PARAMETER StorageKey
        The key of the report.
    .EXAMPLE
        $templates = Get-UDPivotReportTemplate -Bound $PSBoundParameters -Cmdlet $PSCmdlet -Source $dataSource -SchemaUrl $schemaAddress -StorageKey $storageKey
    .OUTPUTS
        PSCustomObject with Props (hashtable), Handlers (event parameter name to Endpoint), IsAdmin,
        Count (templates) and StoreKind.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Bound,
        [Parameter(Mandatory)][System.Management.Automation.PSCmdlet]$Cmdlet,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Source,
        [AllowNull()][object]$SchemaUrl,
        [Parameter(Mandatory)][AllowEmptyString()][string]$StorageKey
    )
    $store = if (Test-UDPivotTemplateStore -Store $Bound['TemplateStore']) { $Bound['TemplateStore'] }
    $customEvents = @('OnSaveTemplate', 'OnDeleteTemplate', 'OnPublishTemplate') | Where-Object { $Bound[$_] }
    if ($store -and $customEvents) { throw ('-TemplateStore with a store does the saving itself; leave out {0}, or use them without a store.' -f (($customEvents | ForEach-Object { "-$_" }) -join ', ')) }
    if ($Bound['OnPublishTemplate'] -and -not $Bound['AdminRole']) { throw '-OnPublishTemplate needs -AdminRole: only readers with one of its roles may publish.' }
    $isAdmin = $false
    $user = $null
    if ($store -or $Bound['AdminRole']) {
        $user = if ($Bound.ContainsKey('UserName')) { $Bound['UserName'] } else { [string]$Cmdlet.SessionState.PSVariable.GetValue('User') }
        $userRoles = if ($Bound.ContainsKey('Roles')) { $Bound['Roles'] } else { @($Cmdlet.SessionState.PSVariable.GetValue('Roles')) }
        $isAdmin = Test-UDPivotRole -Roles $userRoles -AdminRole $Bound['AdminRole']
    }
    $storeViews = if ($store) { Get-UDPivotStoreView -Store $store -UserName $user -SourceId $Source.id -IsAdmin $isAdmin } else { @{ shared = @(); user = @() } }
    $list = Merge-UDPivotTemplateList -Shipped (Get-UDPivotShippedTemplate -Bound $Bound -SourceId $Source.id) -StoreView $storeViews
    $props = @{}
    $handlers = @{}
    if ($store) {
        $settings = @{
            App        = [string]$Cmdlet.SessionState.PSVariable.GetValue('DashboardName')
            Report     = $StorageKey
            Store      = $store
            AdminRole  = @($Bound['AdminRole'])
            SourceId   = $Source.id
            SourceName = [string]$Source['name']
            SchemaUrl  = $SchemaUrl
        }
        $handlers = New-UDPivotStoreEndpoint -Settings $settings -UserName $user -IsAdmin $isAdmin
        if (-not $user) { $props['templateStore'] = 'browser' }
    }
    elseif ($Bound['TemplateStore'] -eq 'Browser') { $props['templateStore'] = 'browser' }
    Limit-UDPivotTemplateList -List $list
    if ($Bound.ContainsKey('Templates') -or $Bound['TemplatePath'] -or $store) { $props['templates'] = $list.ToArray() }
    if ($isAdmin -and ($handlers['OnPublishTemplate'] -or $Bound['OnPublishTemplate'])) { $props['canPublish'] = $true }
    [pscustomobject]@{
        Props     = $props
        Handlers  = $handlers
        IsAdmin   = $isAdmin
        Count     = $list.Count
        StoreKind = if ($store) { $store.Kind } elseif ($props['templateStore']) { 'Browser' } else { $null }
    }
}
