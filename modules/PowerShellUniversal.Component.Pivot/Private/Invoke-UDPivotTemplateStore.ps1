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
        The request's headers, for the origin of a path in -SchemaUrl: ConvertTo-UDPivotViewFile reads
        $Headers of its caller, which is this parameter.
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
    if (-not (Test-UDPivotTemplateStore -Store $Store)) { throw '-TemplateStore: expected a store of New-UDPivotFileTemplateStore or New-UDPivotTemplateStore.' }
    if ($Action -eq 'Publish') { $Scope = 'shared' }
    if ($Scope -eq 'user' -and [string]::IsNullOrWhiteSpace($UserName)) { throw 'Sign in to keep your own views.' }
    $userKey = if ($Scope -eq 'user') { Get-UDPivotSha256 -Text $UserName.Trim().ToLowerInvariant() -Length 24 }
    $max = if ($Scope -eq 'user') { $Store.MaxUserViews } else { $Store.MaxSharedViews }
    $folder = if ($Store.Kind -eq 'File') {
        if ($Scope -eq 'user') { Join-Path $Store.Path 'users' $userKey } else { Join-Path $Store.Path 'shared' }
    }
    $request = [ordered]@{
        Scope   = $Scope
        User    = if ($Scope -eq 'user' -or $Action -eq 'Publish') { $UserName } else { $null }
        UserKey = $userKey
    }

    # the stored views of this scope, each checked again (a store can be changed by hand); a folder holds
    # the views of every report of the store, so the list is capped by what a report takes, not by $max.
    # File: where a view is stored (its file; for a custom store the FileName Get returns, else the one a
    # save gives it), so a save over it replaces it in place. Files: every place it may be stored: for a
    # custom store without FileName also the one version 0.1.0 gave it (a hash of the name in lower case,
    # which "Sales" and "sales" share), unless the stored file says this module wrote it from 0.2.0 on,
    # which never uses that place: so a view saved now never claims the place of an old one.
    $list = {
        if ($Store.Kind -eq 'File') { return @(Get-UDPivotTemplateFile -Path $folder -MaxCount $Script:MaxTemplates | ForEach-Object { $_ | Add-Member -NotePropertyName Files -NotePropertyValue @($_.File) -PassThru }) }
        $index = 0
        @(foreach ($entry in @(& $Store.Get ([pscustomobject]$request))) {
                $index++
                if ($null -eq $entry) { continue }
                if ($index -gt $Script:MaxTemplates) { Write-Warning ('Pivot template store: more than {0} {1} views; the rest is left out.' -f $Script:MaxTemplates, $Scope); break }
                try {
                    $source = if ($entry -is [string]) { $entry } else {
                        $json = Get-UDPivotEntryValue -InputObject $entry -Name 'Json'
                        if ($json -is [string]) { $json } else { $entry }
                    }
                    $read = ConvertFrom-UDPivotViewFile -InputObject $source
                    $sourceId = if ($read.Source) { $read.Source.id }
                    $stored = if ($entry -isnot [string]) { Get-UDPivotEntryValue -InputObject $entry -Name 'FileName' }
                    $writtenBy = $read.Generator
                    $version = $null
                    $current = $writtenBy -and $writtenBy.name -ceq 'PowerShellUniversal.Component.Pivot' -and [version]::TryParse([string]$writtenBy.version, [ref]$version) -and $version -ge [version]'0.2.0'
                    $files = @(if ($stored -is [string] -and $stored -match '^[^\\/\p{Cc}]{1,255}$' -and $stored -notin '.', '..') { $stored } else {
                            Get-UDPivotViewFileName -Name $read.Name -SourceId $sourceId
                            if (-not $current) { Get-UDPivotViewFileName -Name $read.Name -SourceId $sourceId -Legacy }
                        }) | Select-Object -Unique
                    $files = @($files)
                    [pscustomobject]@{ Name = $read.Name; View = $read.View; File = $files[0]; Files = @($files); SourceId = $sourceId }
                }
                catch { Write-Warning ('Pivot template store: a {0} view skipped: {1}' -f $Scope, $_.Exception.Message) }
            })
    }

    # one store serves several reports: a report lists the views of its data and those made for no
    # named data (as pivotkit's browser store)
    $reportData = [string]$SourceId
    # -SchemaUrl only when given: ConvertTo-UDPivotViewFile picks pivotkit's schema of the format otherwise
    $viewFile = @{ SourceName = $SourceName; Schema = @{} }
    if ($PSBoundParameters.ContainsKey('SchemaUrl')) { $viewFile.Schema['SchemaUrl'] = Get-UDPivotSchemaUrl -SchemaUrl $SchemaUrl -Given }
    $listed = { param($Entry) -not $reportData -or -not $Entry.SourceId -or $Entry.SourceId -ceq $reportData }
    if ($Action -eq 'List') { return & $list | Where-Object { & $listed $_ } }

    $checkedName = ConvertTo-UDPivotTemplateName -Name $Name
    $request['Name'] = $checkedName
    # the views of this name the report lists, by pivotkit's rule (its Views menu compares names with
    # ===: the same characters in the same case): those made for this data, else those made for no named
    # data, as pivotkit's browser store replaces them
    $named = {
        param($Entries)
        $all = @($Entries | Where-Object { $_.Name -ceq $checkedName -and (& $listed $_) })
        $same = @($all | Where-Object { [string]$_.SourceId -ceq [string]$reportData })
        if ($same.Count) { $same } else { @($all | Where-Object { -not $_.SourceId }) }
    }
    $requestFor = {
        param([string]$FileName)
        $out = [ordered]@{}
        foreach ($k in $request.Keys) { $out[$k] = $request[$k] }
        $out['FileName'] = $FileName
        $out['Key'] = if ($Scope -eq 'user') { 'users/{0}/{1}' -f $userKey, $FileName } else { 'shared/{0}' -f $FileName }
        $out
    }
    $remove = {
        param([string]$FileName)
        if ($Store.Kind -eq 'File') {
            $target = Join-Path $folder $FileName
            if (Test-Path -LiteralPath $target -PathType Leaf) { Remove-Item -LiteralPath $target -Force }
        }
        else { $null = & $Store.Delete ([pscustomobject](& $requestFor $FileName)) }
    }
    # takes the view of this name out of every place it may be stored but -Keep (a copy; the place version
    # 0.1.0 gave it), never out of a place another view may be in. Some of these places are guesses (a
    # custom store without FileName), so a failed delete there is a warning; with -Strict (Delete) a view
    # of which no place could be deleted is an error the reader sees.
    $clear = {
        param([object[]]$Found, [object[]]$All, [string]$Keep, [switch]$Strict)
        $claimed = @($All | Where-Object { $Found -notcontains $_ } | ForEach-Object { $_.Files })
        $done = @{}
        foreach ($entry in $Found) {
            $failed = $null
            $removed = 0
            foreach ($file in @($entry.Files | Where-Object { $_ -ne $Keep -and $claimed -notcontains $_ })) {
                if ($done.ContainsKey($file)) { $removed++; continue }
                try { & $remove $file; $done[$file] = $true; $removed++ }
                catch { if (-not $failed) { $failed = $_ } }
            }
            if ($failed) {
                if ($Strict -and -not $removed) { throw $failed }
                Write-Warning ('Pivot template store: "{0}" could not be removed from one place: {1}' -f $checkedName, $failed.Exception.Message)
            }
        }
    }
    # a folder, or a custom store's scope and user: list and write as one step, so two saves of a new
    # name at the same moment neither store it twice nor go over the limit
    $lockName = if ($Store.Kind -eq 'File') { $folder } else { 'store|{0}|{1}|{2}' -f (Get-UDPivotSha256 -Text $Store.Save.ToString()), $Scope, $userKey }

    if ($Action -eq 'Delete') {
        Invoke-UDPivotStoreLock -Name $lockName -ScriptBlock {
            $all = @(& $list)
            $found = @(& $named $all)
            # none listed (a stored view broken by hand): the file a save of this name gives it
            if ($found.Count) { & $clear $found $all '' -Strict }
            else { & $remove (Get-UDPivotViewFileName -Name $checkedName -SourceId $reportData) }
        }
        return
    }

    # Save and Publish: the checked view as a view file; what is stored is never the input itself. A view
    # of the name replaces the stored one in place (an upsert: pivotkit's Save sends an existing name)
    $checkedView = ConvertFrom-UDPivotView -InputObject $View
    $full = { ('At most {0} {1} views; delete one first.' -f $max, $(if ($Scope -eq 'user') { 'own' } else { 'shared' })) }

    Invoke-UDPivotStoreLock -Name $lockName -ScriptBlock {
        $all = @(& $list)
        $found = @(& $named $all)
        if ($found.Count) {
            # its file and its data stay (a view made for no named data stays one)
            $fileName = $found[0].File
            $fileSource = [string]$found[0].SourceId
        }
        else {
            $count = if ($Store.Kind -eq 'File') { @(Get-ChildItem -LiteralPath $folder -Filter '*.pivotkit.json' -File -ErrorAction SilentlyContinue).Count } else { $all.Count }
            if ($count -ge $max) { throw (& $full) }
            # a file name no other view holds (one stored by hand); file names compared without case, as
            # on Windows and macOS
            $attempt = 0
            do {
                $fileName = Get-UDPivotViewFileName -Name $checkedName -SourceId $reportData -Attempt $attempt
                $attempt++
                $taken = @($all | Where-Object { $_.Files -contains $fileName }).Count -or ($Store.Kind -eq 'File' -and (Test-Path -LiteralPath (Join-Path $folder $fileName)))
            } while ($taken)
            $fileSource = $reportData
        }
        $schemaArgument = $viewFile.Schema
        $json = ConvertTo-UDPivotViewFile -View $checkedView -Name $checkedName -SourceId $fileSource -SourceName $(if ($fileSource) { $viewFile.SourceName }) -CreatedAt ([datetime]::UtcNow) @schemaArgument

        if ($Store.Kind -eq 'File') {
            try { $null = New-Item -ItemType Directory -Path $folder -Force }
            catch { throw ('The view store cannot create its folder ({0}).' -f $_.Exception.Message) }
            # a new file, then replace: a reader never sees half a file
            $target = Join-Path $folder $fileName
            $temp = Join-Path $folder ('.{0}.{1}.tmp' -f $fileName, [guid]::NewGuid().ToString('n'))
            try {
                [System.IO.File]::WriteAllText($temp, $json, [System.Text.UTF8Encoding]::new($false))
                [System.IO.File]::Move($temp, $target, $true)
            }
            finally {
                if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
            }
        }
        else {
            $save = & $requestFor $fileName
            $save['Json'] = $json
            $save['View'] = $checkedView
            if ($Action -eq 'Publish' -and $Store.Publish) { $null = & $Store.Publish ([pscustomobject]$save) }
            else { $null = & $Store.Save ([pscustomobject]$save) }
        }
        # the same view stored twice before (by hand, under another file name): one is left
        & $clear $found $all $fileName
    }
}
