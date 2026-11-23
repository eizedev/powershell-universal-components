function Get-UDPivotAccessToken {
    <#
    .SYNOPSIS
        An OAuth access token by the client credentials grant, from this runspace's cache while it is
        valid.
    .DESCRIPTION
        POSTs grant_type=client_credentials to the token endpoint with the client id and secret (in the
        body, or as HTTP Basic with -ClientAuthentication Basic) and the optional scope, audience and
        resource. The token is kept until a minute before expires_in runs out, per token endpoint, client
        id, SHA-256 of the secret, scope, audience, resource and target server; a token without
        expires_in is not kept. -Renew drops a cached token first (after a 401). The secret and the token
        never reach an error message or a stream.
    .PARAMETER TokenUri
        The token endpoint (https, http only on this machine).
    .PARAMETER Credential
        The client id as the user name, the client secret as the password.
    .PARAMETER Scope
        Scopes to ask for.
    .PARAMETER Audience
        The audience parameter some providers want (Auth0).
    .PARAMETER Resource
        RFC 8707's resource: the REST service's address.
    .PARAMETER ClientAuthentication
        Post (client_secret_post, default) or Basic (client_secret_basic).
    .PARAMETER TimeoutSec
        The longest wait for the token endpoint.
    .PARAMETER Target
        The address the token is for (the REST service): part of the cache key, so a token fetched for one
        server never goes to another.
    .PARAMETER Renew
        Ask for a new token even when one is cached.
    .EXAMPLE
        Get-UDPivotAccessToken -TokenUri 'https://login.example.com/application/o/token/' -Credential $Secret:PivotkitClient -Scope 'pivotkit:rest'
    .OUTPUTS
        System.Security.SecureString
    #>
    [CmdletBinding()]
    [OutputType([securestring])]
    param(
        [Parameter(Mandatory)][uri]$TokenUri,
        [Parameter(Mandatory)][pscredential]$Credential,
        [string[]]$Scope,
        [string]$Audience,
        [string]$Resource,
        [ValidateSet('Post', 'Basic')][string]$ClientAuthentication = 'Post',
        [ValidateRange(1, 3600)][int]$TimeoutSec = 30,
        [Parameter(Mandatory)][uri]$Target,
        [switch]$Renew
    )
    if (-not $TokenUri.IsAbsoluteUri -or $TokenUri.UserInfo) { throw '-TokenUri: an absolute address without a user name or password in it.' }
    $where = Get-UDPivotSafeAddress -Uri $TokenUri
    if (-not (Test-UDPivotLoopbackUri -Uri $TokenUri)) { throw ('-TokenUri {0}: https only (http only for this machine), so the client secret is never sent in clear text.' -f $where) }
    # per token endpoint, client, secret (as its hash), scope, audience, resource and the server the
    # token is for: a changed secret is checked at the endpoint, and a token never goes to another server
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $secretHash = [Convert]::ToHexString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Credential.GetNetworkCredential().Password))) } finally { $sha.Dispose() }
    $key = ($TokenUri.AbsoluteUri, $Credential.UserName, $secretHash, (@($Scope) -join ' '), $Audience, $Resource, (Get-UDPivotSafeAddress -Uri $Target)) -join [char]1
    $entry = $Script:TokenCache[$key]
    if ($Renew) { $Script:TokenCache.Remove($key) }
    elseif ($entry -and $entry.Expires -gt [datetime]::UtcNow.AddSeconds($Script:TokenSkewSec)) { return $entry.Token }

    $body = [ordered]@{ grant_type = 'client_credentials' }
    $headers = @{ Accept = 'application/json' }
    $secret = $Credential.GetNetworkCredential().Password
    if ($ClientAuthentication -eq 'Basic') {
        # RFC 6749 2.3.1: both form-encoded before they are joined
        $pair = '{0}:{1}' -f [uri]::EscapeDataString($Credential.UserName), [uri]::EscapeDataString($secret)
        $headers['Authorization'] = 'Basic ' + [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($pair))
    }
    else {
        $body['client_id'] = $Credential.UserName
        $body['client_secret'] = $secret
    }
    if ($Scope) { $body['scope'] = @($Scope) -join ' ' }
    if ($Audience) { $body['audience'] = $Audience }
    if ($Resource) { $body['resource'] = $Resource }
    $form = ($body.Keys | ForEach-Object { '{0}={1}' -f $_, [uri]::EscapeDataString([string]$body[$_]) }) -join '&'
    try {
        $response = Invoke-UDPivotHttp -What ('Token endpoint {0}' -f $where) -Request @{
            Uri = $TokenUri; Body = $form; ContentType = 'application/x-www-form-urlencoded'; Headers = $headers; TimeoutSec = $TimeoutSec
        }
    }
    finally {
        $secret = $null
        $form = $null
        $headers = $null
    }
    if ([int]$response.StatusCode -ge 300 -and [int]$response.StatusCode -lt 400) { throw (New-UDPivotError -Id PivotRedirectRefused -Category SecurityError -Data @{ Status = [int]$response.StatusCode } -Message ('Token endpoint {0} answered with a redirect ({1}); it is not followed, so the client secret stays with this endpoint: use the address it names in -TokenUri.' -f $where, [int]$response.StatusCode)) }
    $json = $null
    try { $json = ConvertFrom-Json -InputObject ([System.Text.Encoding]::UTF8.GetString($response.Content)) -Depth 8 } catch { Remove-UDPivotErrorRecord -ErrorRecord $_; $json = $null }
    if ($response.StatusCode -ne 200) {
        # RFC 6749 5.2: error and error_description; nothing of the request is repeated
        $reason = if ($json -and $json.error) { '{0}{1}' -f $json.error, $(if ($json.error_description) { ': ' + $json.error_description }) } else { 'no OAuth error in the answer' }
        throw (New-UDPivotError -Id PivotTokenRefused -Category AuthenticationError -Data @{ Status = [int]$response.StatusCode; Code = if ($json -and $json.error) { [string]$json.error } } -Message ('Token endpoint {0} refused the client credentials ({1}): {2}' -f $where, [int]$response.StatusCode, $reason))
    }
    if (-not $json -or -not ($json.access_token -is [string]) -or -not $json.access_token) { throw (New-UDPivotError -Id PivotTokenRefused -Category AuthenticationError -Message ('Token endpoint {0} answered without an access_token.' -f $where)) }
    if ($json.token_type -and $json.token_type -ne 'Bearer' -and $json.token_type -ne 'bearer') { throw (New-UDPivotError -Id PivotTokenRefused -Category AuthenticationError -Message ('Token endpoint {0} gave a token of type "{1}"; pivotkit-server takes Bearer tokens.' -f $where, $json.token_type)) }
    $token = [System.Net.NetworkCredential]::new('', [string]$json.access_token).SecurePassword
    $seconds = 0
    if ($null -ne $json.expires_in -and [int]::TryParse([string]$json.expires_in, [ref]$seconds) -and $seconds -gt $Script:TokenSkewSec) {
        $Script:TokenCache[$key] = @{ Token = $token; Expires = [datetime]::UtcNow.AddSeconds($seconds) }
    }
    $token
}
