function Register-UDPivotTemplateStore {
    <#
    .SYNOPSIS
        Keeps a report's store and settings for the event handlers the module registers, and returns
        the key the handlers find them under.
    .PARAMETER Settings
        Store, AdminRole, SourceId, SourceName, SchemaUrl and the app and report it belongs to.
    .EXAMPLE
        $key = Register-UDPivotTemplateStore -Settings $settings
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][hashtable]$Settings)
    # the same report with the same settings gets the same key on every render; the entry is replaced,
    # so the latest store object (its script blocks) is the one the handlers use
    $identity = [ordered]@{
        App        = $Settings.App
        Report     = $Settings.Report
        Kind       = $Settings.Store.Kind
        Path       = $Settings.Store.Path
        Max        = '{0}/{1}' -f $Settings.Store.MaxUserViews, $Settings.Store.MaxSharedViews
        AdminRole  = @($Settings.AdminRole) -join [char]1
        SourceId   = $Settings.SourceId
        SourceName = $Settings.SourceName
        SchemaUrl  = $Settings.SchemaUrl
    }
    $key = Get-UDPivotSha256 -Text (ConvertTo-Json -InputObject $identity -Compress) -Length 32
    $registry = Get-UDPivotStoreRegistry
    $entry = [pscustomobject]@{ Settings = $Settings; Updated = [datetime]::UtcNow }
    $registry[$key] = $entry
    if ($registry.Count -gt $Script:MaxStoreRegistryEntries) {
        # reports with a store created per render (a new key each time): drop the oldest
        $oldest = $registry.GetEnumerator() | Sort-Object { $_.Value.Updated } | Select-Object -First ($registry.Count - $Script:MaxStoreRegistryEntries)
        foreach ($old in $oldest) { $removed = $null; [void]$registry.TryRemove($old.Key, [ref]$removed) }
    }
    $key
}
