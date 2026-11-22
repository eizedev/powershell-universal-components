function Get-UDPivotStoreRegistry {
    <#
    .SYNOPSIS
        The process-wide table of the reports' template stores (see $Script:StoreRegistryName).
    .EXAMPLE
        (Get-UDPivotStoreRegistry)[$key]
    .OUTPUTS
        System.Collections.Concurrent.ConcurrentDictionary[string, object]
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Concurrent.ConcurrentDictionary[string, object]])]
    param()
    $domain = [System.AppDomain]::CurrentDomain
    $registry = $domain.GetData($Script:StoreRegistryName)
    if ($null -eq $registry) {
        [System.Threading.Monitor]::Enter($domain)
        try {
            $registry = $domain.GetData($Script:StoreRegistryName)
            if ($null -eq $registry) {
                $registry = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
                $domain.SetData($Script:StoreRegistryName, $registry)
            }
        }
        finally {
            [System.Threading.Monitor]::Exit($domain)
        }
    }
    , $registry
}
