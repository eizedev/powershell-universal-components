function Get-UDPivotRequestOrigin {
    <#
    .SYNOPSIS
        The origin (https://host:port) of the address the reader's browser used, from the request's
        headers, or $null.
    .DESCRIPTION
        Reads Origin, then windowLocation (the page address PSU's client sends), then Referer, with any
        case of the header name: PSU gives an app a case-sensitive Dictionary and an API a hashtable.
        Only an http or https address with a plain host and port counts; a header with a user name, a
        space or another scheme is passed over. The headers come from the browser: the origin names the
        address the reader used, behind a proxy too, as long as the proxy passes them on.
    .PARAMETER Headers
        $Headers of the page, the event or the API endpoint.
    .EXAMPLE
        Get-UDPivotRequestOrigin -Headers $Headers
    .OUTPUTS
        System.String, or $null.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowNull()][object]$Headers)
    if ($Headers -isnot [System.Collections.IDictionary]) { return $null }
    foreach ($wanted in $Script:RequestAddressHeaders) {
        foreach ($key in @($Headers.Keys)) {
            if ([string]$key -ne $wanted) { continue }
            $value = [string]$Headers[$key]
            $address = $null
            if ($value -cmatch $Script:RequestAddressPattern -and [uri]::TryCreate($value, [System.UriKind]::Absolute, [ref]$address) -and -not $address.UserInfo) {
                return $address.GetLeftPart([System.UriPartial]::Authority)
            }
        }
    }
    $null
}
