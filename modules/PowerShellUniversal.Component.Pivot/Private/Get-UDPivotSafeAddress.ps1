function Get-UDPivotSafeAddress {
    <#
    .SYNOPSIS
        An address as messages may show it: scheme, host, port and path, never user info or a query.
    .PARAMETER Uri
        The address.
    .EXAMPLE
        Get-UDPivotSafeAddress -Uri ([uri]'https://reports.example.com/api/v1/views/render/file')
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][uri]$Uri)
    '{0}://{1}{2}' -f $Uri.Scheme, $Uri.Authority, $Uri.AbsolutePath
}
