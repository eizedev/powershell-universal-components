function Get-UDPivotStoredView {
    <#
    .SYNOPSIS
        The stored views of a store's scope, each checked again (a store can be changed by hand).
    .DESCRIPTION
        A folder holds the views of every report of the store, so the list is capped by what a report
        takes, not by the store's limit. A custom store's entries are read by ConvertFrom-UDPivotStoreEntry.
    .PARAMETER Context
        The result of New-UDPivotStoreContext.
    .EXAMPLE
        $all = @(Get-UDPivotStoredView -Context $context)
    .OUTPUTS
        PSCustomObject with Name, View, File, Files and SourceId.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)][pscustomobject]$Context)
    if ($Context.Store.Kind -eq 'File') {
        return @(Get-UDPivotTemplateFile -Path $Context.Folder -MaxCount $Script:MaxTemplates | ForEach-Object { $_ | Add-Member -NotePropertyName Files -NotePropertyValue @($_.File) -PassThru })
    }
    $index = 0
    @(foreach ($entry in @(& $Context.Store.Get ([pscustomobject]$Context.Request))) {
            $index++
            if ($null -eq $entry) { continue }
            if ($index -gt $Script:MaxTemplates) { Write-Warning ('Pivot template store: more than {0} {1} views; the rest is left out.' -f $Script:MaxTemplates, $Context.Scope); break }
            try { ConvertFrom-UDPivotStoreEntry -Entry $entry }
            catch { Write-Warning ('Pivot template store: a {0} view skipped: {1}' -f $Context.Scope, $_.Exception.Message) }
        })
}
