function Resolve-UDPivotRestSignIn {
    <#
    .SYNOPSIS
        Checks the REST service's address and the sign-in parameters, and returns the sign-in as
        Invoke-UDPivotRestCall takes it.
    .DESCRIPTION
        One place for the checks of every command that calls pivotkit-server: -Uri absolute, without a
        user name, password, query or fragment, https (http only for this machine); either -Token or
        -Credential with -TokenUri; -TokenUri, -Scope, -Audience, -Resource and -ClientAuthentication
        only with -Credential. Wrong combinations are plain errors before anything is sent.
    .PARAMETER Bound
        The calling command's $PSBoundParameters.
    .PARAMETER TimeoutSec
        The token request's limit.
    .EXAMPLE
        $auth = Resolve-UDPivotRestSignIn -Bound $PSBoundParameters -TimeoutSec $TimeoutSec
    .OUTPUTS
        System.Collections.Hashtable: @{ Token } or @{ Credential; TokenUri; Scope; Audience; Resource; ClientAuthentication; TimeoutSec }.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Bound, [int]$TimeoutSec = $Script:ReportTimeoutSec)
    $uri = [uri]$Bound['Uri']
    if (-not $uri) { throw 'This needs -Uri, the REST service''s address (https://reports.example.com/api/v1).' }
    if (-not $uri.IsAbsoluteUri -or $uri.UserInfo) { throw '-Uri: an absolute address without a user name or password in it (the token goes in its own header).' }
    # the routes are appended to the path: a query or a fragment would be lost on the way, so it is refused
    if ($uri.Query -or $uri.Fragment) { throw '-Uri: the REST service''s address without a query string or fragment (https://reports.example.com/api/v1).' }
    if (-not (Test-UDPivotLoopbackUri -Uri $uri)) { throw ('-Uri {0}: an https address (http only for this machine), so the token is never sent in clear text.' -f (Get-UDPivotSafeAddress -Uri $uri)) }
    $credential = $Bound['Credential']
    $tokenUri = [uri]$Bound['TokenUri']
    if (($Bound.Keys -contains 'Token') -eq [bool]$credential) { throw 'This needs either -Token (a static token) or -Credential with -TokenUri (OAuth client credentials).' }
    if ($credential -and -not $tokenUri) { throw '-Credential needs -TokenUri, the token endpoint of the OAuth provider.' }
    if ($tokenUri -and (-not $tokenUri.IsAbsoluteUri -or $tokenUri.UserInfo)) { throw '-TokenUri: an absolute address without a user name or password in it.' }
    $oauthOnly = @('TokenUri', 'Scope', 'Audience', 'Resource', 'ClientAuthentication' | Where-Object { $Bound.Keys -contains $_ } | ForEach-Object { "-$_" })
    if (-not $credential -and $oauthOnly.Count) { throw ('{0}: only with -Credential (OAuth client credentials).' -f ($oauthOnly -join ', ')) }
    if (-not $credential) { return @{ Token = $Bound['Token'] } }
    @{
        Credential           = $credential
        TokenUri             = $tokenUri
        Scope                = $Bound['Scope']
        Audience             = $Bound['Audience']
        Resource             = $Bound['Resource']
        ClientAuthentication = if ($Bound.Keys -contains 'ClientAuthentication') { $Bound['ClientAuthentication'] } else { 'Post' }
        TimeoutSec           = $TimeoutSec
    }
}
