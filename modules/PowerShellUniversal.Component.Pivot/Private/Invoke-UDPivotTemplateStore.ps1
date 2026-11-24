function Invoke-UDPivotTemplateStore {
    <#
    .SYNOPSIS
        Lists, saves or deletes views in a template store, with the module's checks and limits.
    .DESCRIPTION
        The one place that talks to a store: New-UDPivotReport lists with it, the event handlers save,
        publish and delete with it (Invoke-UDPivotTemplateRequest). Who may do what is decided before:
        this function only checks names, views and limits. Save and Publish are an upsert: a view of the
        name the report lists (the same characters in the same case, as pivotkit compares names; one
        made for this report's data first, else one made for no named data) is replaced where it is
        stored, and a copy of it stored twice goes; Delete removes the views of the name the same way.
    .PARAMETER Store
        A store of New-UDPivotFileTemplateStore or New-UDPivotTemplateStore.
    .PARAMETER Action
        List, Save, Publish or Delete.
    .PARAMETER Scope
        user or shared.
    .PARAMETER UserName
        The signed-in user (scope user; the publisher for Publish).
    .PARAMETER Name
        The view's name (Save, Publish, Delete).
    .PARAMETER View
        The view (Save, Publish).
    .PARAMETER SourceId
        The data the view was made for, written into the view file.
    .PARAMETER SourceName
        Its name for people.
    .PARAMETER SchemaUrl
        The $schema of the view file, as ConvertTo-UDPivotViewFile -SchemaUrl takes it; without it that
        function's default.
    .PARAMETER Headers
        The request's headers, for the origin of a path in -SchemaUrl of an own view:
        ConvertTo-UDPivotViewFile reads $Headers of its caller, which is this parameter. A shared view
        takes no origin from them (Resolve-UDPivotSchemaUrl -WithoutRequest).
    .EXAMPLE
        Invoke-UDPivotTemplateStore -Store $store -Action List -Scope shared
    .OUTPUTS
        System.Management.Automation.PSCustomObject (List: Name and View)
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][object]$Store,
        [Parameter(Mandatory)][ValidateSet('List', 'Save', 'Publish', 'Delete')][string]$Action,
        [Parameter(Mandatory)][ValidateSet('user', 'shared')][string]$Scope,
        [AllowEmptyString()][string]$UserName,
        [AllowNull()][object]$Name,
        [AllowNull()][object]$View,
        [AllowEmptyString()][string]$SourceId,
        [AllowEmptyString()][string]$SourceName,
        [AllowEmptyString()][string]$SchemaUrl,
        [AllowNull()][object]$Headers
    )
    $context = New-UDPivotStoreContext -Store $Store -Action $Action -Scope $Scope -UserName $UserName
    # one store serves several reports: a report lists the views of its data and those made for no
    # named data (as pivotkit's browser store)
    $reportData = [string]$SourceId
    # -SchemaUrl only when given: ConvertTo-UDPivotViewFile picks pivotkit's schema of the format otherwise
    $schemaArgument = @{}
    if ($PSBoundParameters.ContainsKey('SchemaUrl')) { $schemaArgument['SchemaUrl'] = Get-UDPivotSchemaUrl -SchemaUrl $SchemaUrl -Given }
    if ($Action -eq 'List') { return Get-UDPivotStoredView -Context $context | Where-Object { Test-UDPivotListedView -Entry $_ -ReportData $reportData } }

    $checkedName = ConvertTo-UDPivotTemplateName -Name $Name
    $context.Request['Name'] = $checkedName
    # a folder, or a custom store's scope and user: list and write as one step, so two saves of a new
    # name at the same moment neither store it twice nor go over the limit
    $lockName = if ($Store.Kind -eq 'File') { $context.Folder } else { 'store|{0}|{1}|{2}' -f (Get-UDPivotSha256 -Text $Store.Save.ToString()), $context.Scope, $context.UserKey }

    if ($Action -eq 'Delete') {
        Invoke-UDPivotStoreLock -Name $lockName -ScriptBlock {
            $all = @(Get-UDPivotStoredView -Context $context)
            $found = @(Select-UDPivotNamedView -Entries $all -Name $checkedName -ReportData $reportData)
            # none listed (a stored view broken by hand): the file a save of this name gives it
            if ($found.Count) { Clear-UDPivotStoredCopy -Context $context -Found $found -All $all -Name $checkedName -Keep '' -Strict }
            else { Remove-UDPivotStoredFile -Context $context -FileName (Get-UDPivotViewFileName -Name $checkedName -SourceId $reportData) }
        }
        return
    }

    # Save and Publish: the checked view as a view file; what is stored is never the input itself. A view
    # of the name replaces the stored one in place (an upsert: pivotkit's Save sends an existing name)
    $checkedView = ConvertFrom-UDPivotView -InputObject $View
    # everyone reads a shared view: a path takes the origin of an https default, never one of the
    # publisher's request, and without such a default names pivotkit's schema
    if ($Scope -eq 'shared') {
        $address = if ($schemaArgument.ContainsKey('SchemaUrl')) { $schemaArgument['SchemaUrl'] } else { Get-UDPivotSchemaUrl }
        if ($address) { $schemaArgument['SchemaUrl'] = Resolve-UDPivotSchemaUrl -SchemaUrl $address -WithoutRequest }
    }
    Invoke-UDPivotStoreLock -Name $lockName -ScriptBlock {
        $all = @(Get-UDPivotStoredView -Context $context)
        $found = @(Select-UDPivotNamedView -Entries $all -Name $checkedName -ReportData $reportData)
        if ($found.Count) {
            # its file and its data stay (a view made for no named data stays one)
            $fileName = $found[0].File
            $fileSource = [string]$found[0].SourceId
        }
        else {
            $count = if ($Store.Kind -eq 'File') { @(Get-ChildItem -LiteralPath $context.Folder -Filter '*.pivotkit.json' -File -ErrorAction SilentlyContinue).Count } else { $all.Count }
            if ($count -ge $context.Max) { throw ('At most {0} {1} views; delete one first.' -f $context.Max, $(if ($context.Scope -eq 'user') { 'own' } else { 'shared' })) }
            $fileName = Get-UDPivotFreeViewFileName -Context $context -All $all -Name $checkedName -ReportData $reportData
            $fileSource = $reportData
        }
        $json = ConvertTo-UDPivotViewFile -View $checkedView -Name $checkedName -SourceId $fileSource -SourceName $(if ($fileSource) { $SourceName }) -CreatedAt ([datetime]::UtcNow) @schemaArgument
        Write-UDPivotStoredView -Context $context -FileName $fileName -Json $json -View $checkedView -Publish:($Action -eq 'Publish')
        # the same view stored twice before (by hand, under another file name): one is left
        Clear-UDPivotStoredCopy -Context $context -Found $found -All $all -Name $checkedName -Keep $fileName
    }
}
