function Invoke-UDPivotRestCall {
    <#
    .SYNOPSIS
        Calls one route of pivotkit-server with the bearer token and returns the answer of a success
        (2xx); any other answer becomes the server's error.
    .DESCRIPTION
        GET (no body) or POST (the body as UTF-8 JSON) to <Uri><Route>. No redirect is followed (the
        token would go along). With a credential, a 401 gets one new token and one more try. Any other
        answer that is no success becomes New-UDPivotServerError's record. Every route of the module
        goes through here, so the sign-in and the errors are the same on each.
    .PARAMETER Uri
        The REST service's address, https://host/api/v1.
    .PARAMETER Route
        The route below it: /sources, /views/render, /views/render/file.
    .PARAMETER Body
        The input as UTF-8 JSON for a POST; none for a GET.
    .PARAMETER Auth
        @{ Token } or @{ Credential; TokenUri; Scope; Audience; Resource; ClientAuthentication }
        (Resolve-UDPivotRestSignIn).
    .PARAMETER TimeoutSec
        The longest wait for the answer.
    .PARAMETER TextMaxBytes
        Read a success as text, at most this many bytes (Invoke-UDPivotHttp's TextMaxBytes).
    .PARAMETER RowsRoute
        The route is POST /sources/records: its codes pick the error id (New-UDPivotServerError).
    .EXAMPLE
        Invoke-UDPivotRestCall -Uri 'https://reports.example.com/api/v1' -Route '/sources' -Auth @{ Token = $Secret:PivotkitToken }
    .OUTPUTS
        PSCustomObject with StatusCode, Headers and Content, or Text (Invoke-UDPivotHttp).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][uri]$Uri,
        [Parameter(Mandatory)][ValidatePattern('^/')][string]$Route,
        [byte[]]$Body,
        [Parameter(Mandatory)][hashtable]$Auth,
        [ValidateRange(1, 3600)][int]$TimeoutSec = $Script:ReportTimeoutSec,
        [long]$TextMaxBytes = 0,
        [switch]$RowsRoute
    )
    $target = [uri]((Get-UDPivotSafeAddress -Uri $Uri).TrimEnd('/') + $Route)
    $where = Get-UDPivotSafeAddress -Uri $target
    $post = $PSBoundParameters.ContainsKey('Body')
    $size = if ($post) { $Body.Length } else { 0 }
    if ($size -gt $Script:ReportDataWarnBytes) { Write-Warning ('The request is {0:N1} MiB; pivotkit-server takes at most 10 MiB unless its operator raised rest.data.maxBytes (up to 64 MiB).' -f ($size / 1MB)) }
    $oauth = $Auth.ContainsKey('Credential')
    $tokenArgs = @{}
    if ($oauth) {
        foreach ($k in 'TokenUri', 'Credential', 'Scope', 'Audience', 'Resource', 'ClientAuthentication', 'TimeoutSec') { if ($null -ne $Auth[$k]) { $tokenArgs[$k] = $Auth[$k] } }
        $tokenArgs['Target'] = $Uri
    }
    # a server that takes less closes the connection while a large body is sent; where its answer is
    # lost on the way (no compiled transport), this is the likely reason
    $unansweredHint = if ($size -gt $Script:ReportDataWarnBytes) { 'The request was {0:N1} MiB: a server that takes less may close the connection while it is sent. Send fewer rows or columns, or let the operator configure a source for the data and use -Source.' -f ($size / 1MB) }
    for ($attempt = 1; ; $attempt++) {
        $token = if ($oauth) { ConvertTo-UDPivotPlainText -Secret (Get-UDPivotAccessToken @tokenArgs -Renew:($attempt -gt 1)) -Name 'The access token' } else { ConvertTo-UDPivotPlainText -Secret $Auth['Token'] -Name '-Token' }
        $request = @{ Uri = $target; Headers = @{ Authorization = 'Bearer ' + $token; Accept = '*/*' }; TimeoutSec = $TimeoutSec; TextMaxBytes = $TextMaxBytes }
        if ($post) { $request['Body'] = $Body; $request['ContentType'] = 'application/json; charset=utf-8' } else { $request['Method'] = 'Get' }
        try {
            $response = Invoke-UDPivotHttp -What ('pivotkit-server {0}' -f $where) -Hint $unansweredHint -Request $request
        }
        finally {
            $token = $null
            $request = $null
        }
        $status = $response.StatusCode
        if ($status -ge 200 -and $status -lt 300) { return $response }
        if ($status -eq 401 -and $oauth -and $attempt -eq 1) { continue }
        if ($status -ge 300 -and $status -lt 400) { throw (New-UDPivotError -Id PivotRedirectRefused -Category SecurityError -Data @{ Status = $status } -Message ('pivotkit-server {0} answered with a redirect ({1}); it is not followed, so the token stays with this server: use the address it names in -Uri.' -f $where, $status)) }
        throw (New-UDPivotServerError -Response $response -Where $where -RowsRoute:$RowsRoute)
    }
}
