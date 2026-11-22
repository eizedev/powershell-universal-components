function Test-UDPivotLoopbackUri {
    <#
    .SYNOPSIS
        Whether an address is https, or http on this machine (localhost, 127.0.0.0/8, ::1).
    .DESCRIPTION
        A bearer token and a client secret go only over https; plain http only to a server on the same
        machine (a pivotkit-server next to PSU, a test), as pivotkit's command line allows it.
    .PARAMETER Uri
        The address.
    .EXAMPLE
        Test-UDPivotLoopbackUri -Uri ([uri]'http://127.0.0.1:3333/api/v1')
    .OUTPUTS
        System.Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][uri]$Uri)
    if ($Uri.Scheme -eq 'https') { return $true }
    if ($Uri.Scheme -ne 'http') { return $false }
    if ($Uri.IsLoopback) { return $true }
    $address = $null
    [System.Net.IPAddress]::TryParse($Uri.DnsSafeHost, [ref]$address) -and [System.Net.IPAddress]::IsLoopback($address)
}
