function Get-UDPivotLinkParameter {
    <#
    .SYNOPSIS
        The values of the page's query string that the server lets a link carry for a source.
    .DESCRIPTION
        Asks GET /sources for the source's linkParams and keeps the query's keys that it lists (names
        compared without case, the server's spelling kept). A source without the list, or one the
        caller does not see, takes none. Anyone can write a URL by hand: the server checks the values
        again with the rights of the person.
    .PARAMETER Uri
        The REST service's address.
    .PARAMETER Source
        The source id.
    .PARAMETER Query
        The page's query string as PSU hands it over ($Query).
    .PARAMETER Auth
        As Invoke-UDPivotRestCall takes it.
    .PARAMETER TimeoutSec
        The longest wait for the answer.
    .EXAMPLE
        Get-UDPivotLinkParameter -Uri $uri -Source 'vms' -Query $Query -Auth @{ Token = $AccessToken }
    .OUTPUTS
        System.Collections.Specialized.OrderedDictionary
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory)][uri]$Uri,
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Query,
        [Parameter(Mandatory)][hashtable]$Auth,
        [int]$TimeoutSec = $Script:ReportTimeoutSec
    )
    $out = [ordered]@{}
    if (-not $Query.Count) { return $out }
    $response = Invoke-UDPivotRestCall -Uri $Uri -Route '/sources' -Auth $Auth -TimeoutSec $TimeoutSec
    try { $answer = ConvertFrom-Json -InputObject ([System.Text.Encoding]::UTF8.GetString($response.Content)) -Depth 16 } catch { $answer = $null }
    $entry = if ($answer -is [System.Management.Automation.PSCustomObject] -and $answer.sources) { @($answer.sources | Where-Object { $_ -and $_.id -ceq $Source }) | Select-Object -First 1 }
    $allowed = if ($entry -and $entry.linkParams) { @($entry.linkParams | Where-Object { $_ -is [string] }) } else { @() }
    foreach ($name in $allowed | Sort-Object) {
        $key = @($Query.Keys | Where-Object { [string]$_ -eq $name }) | Select-Object -First 1
        if ($null -ne $key -and $null -ne $Query[$key]) { $out[$name] = [string]$Query[$key] }
    }
    $out
}
