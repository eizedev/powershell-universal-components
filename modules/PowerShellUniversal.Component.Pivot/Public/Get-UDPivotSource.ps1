function Get-UDPivotSource {
    <#
    .SYNOPSIS
        Lists the sources of a pivotkit-server that the signed-in caller may use.
    .DESCRIPTION
        Calls GET /api/v1/sources with the same sign-in as Invoke-UDPivotReport -Engine Rest: a static
        token (-Token), or OAuth client credentials (-Credential with -TokenUri). Only https, or http to
        this machine; redirects are not followed; the token and the client secret never reach an error,
        a log or the output.

        Returns one PivotSource per source: Id (for Invoke-UDPivotReport -Source), Title, Description,
        Kind (source or file), Link (whether pivotkit's share links of views work for it; not the
        download link of Invoke-UDPivotReport -AsLink), Schedulable,
        Parameters (the values the source takes, as the server describes them: name, type, required,
        description, example, enum and the like), DataMaxBytes (the largest request with -Data this
        caller may send; empty when the caller may not send data; the same on every source), Records
        (whether the caller may read the source's rows: New-UDPivotReport -Uri -Source), LinkParams (the
        parameters a link may carry in the page's query string), Views (the views the operator
        publishes for the source: name, title, description), Rows and DataAsOf (the row count and the
        data's date, where the server has read the data and shows them to the caller) and RequestId.
        A pivotkit-server older than 0.4.0 leaves Records, LinkParams, Views, Rows and DataAsOf
        empty.

        When the server lists no source, nothing is returned and the server's reason (its hint: the
        sign-in lacks the sources' scopes) goes to the warning stream. Errors are those of
        Invoke-UDPivotReport: a fixed error id and the server's answer as a PivotServerProblem in
        $_.TargetObject.
    .PARAMETER Uri
        The REST service's address, https://reports.example.com/api/v1. An address with a user name or
        password, a query string or a fragment in it is refused.
    .PARAMETER Token
        A static token, as a string or SecureString - a PSU secret ($Secret:PivotkitToken).
    .PARAMETER Credential
        OAuth client credentials, the client id as user name and the client secret as password - a PSU
        secret of type PSCredential ($Secret:PivotkitClient). Needs -TokenUri.
    .PARAMETER TokenUri
        The OAuth provider's token endpoint (Authentik: https://<authentik>/application/o/token/).
    .PARAMETER Scope
        Scopes to ask the provider for, e.g. pivotkit:rest.
    .PARAMETER Audience
        The audience parameter some providers want for the access token (Auth0).
    .PARAMETER Resource
        RFC 8707's resource parameter: the REST service's address.
    .PARAMETER ClientAuthentication
        How the client authenticates at the token endpoint: Post (client_secret_post, the default) or
        Basic (client_secret_basic).
    .PARAMETER TimeoutSec
        The longest the call may take, in seconds. Default 120.
    .EXAMPLE
        # a choice of sources on a page
        $sources = Get-UDPivotSource -Uri 'https://reports.example.com/api/v1' -Token $Secret:PivotkitToken
        New-UDSelect -Id 'source' -Option { foreach ($s in $sources) { New-UDSelectOption -Name $s.Title -Value $s.Id } }
    .EXAMPLE
        # the parameters a source takes, signed in with OAuth client credentials
        Get-UDPivotSource -Uri 'https://reports.example.com/api/v1' -Credential $Secret:PivotkitClient `
            -TokenUri 'https://login.example.com/application/o/token/' -Scope 'pivotkit:rest' |
            Where-Object Id -EQ 'vms' | Select-Object -ExpandProperty Parameters
    .OUTPUTS
        System.Management.Automation.PSCustomObject (PivotSource).
    .LINK
        https://powershell-universal-components.eize.dev/pivot/reports-server/
    #>
    [CmdletBinding()]
    [OutputType('PivotSource')]
    param(
        [uri]$Uri,
        [AllowNull()][object]$Token,
        [pscredential]$Credential,
        [uri]$TokenUri,
        [ValidateNotNullOrEmpty()][string[]]$Scope,
        [ValidateNotNullOrEmpty()][string]$Audience,
        [ValidateNotNullOrEmpty()][string]$Resource,
        [ValidateSet('Post', 'Basic')][string]$ClientAuthentication = 'Post',
        [ValidateRange(1, 3600)][int]$TimeoutSec = $Script:ReportTimeoutSec
    )
    # -ErrorVariable gets the error itself, not each step it took through the module
    $errorMark = Get-UDPivotErrorMark -Cmdlet $PSCmdlet
    trap { Reset-UDPivotErrorVariable -Mark $errorMark; throw $_ }
    $auth = Resolve-UDPivotRestSignIn -Bound $PSBoundParameters -TimeoutSec $TimeoutSec
    $response = Invoke-UDPivotRestCall -Uri $Uri -Route '/sources' -Auth $auth -TimeoutSec $TimeoutSec
    try { $answer = ConvertFrom-Json -InputObject ([System.Text.Encoding]::UTF8.GetString($response.Content)) -Depth 16 }
    catch { Remove-UDPivotErrorRecord -ErrorRecord $_; $answer = $null }
    if ($answer -isnot [System.Management.Automation.PSCustomObject] -or $null -eq $answer.PSObject.Properties['sources']) {
        throw (New-UDPivotError -Id PivotServerError -Data @{ Status = $response.StatusCode } -Message ('pivotkit-server {0}: the answer to GET /sources holds no list of sources.' -f (Get-UDPivotSafeAddress -Uri $Uri)))
    }
    $sources = @($answer.sources | Where-Object { $_ })
    if (-not $sources.Count -and $answer.hint) { Write-Warning ('pivotkit-server lists no source: {0}' -f $answer.hint) }
    $maxBytes = if ($answer.data -and $null -ne $answer.data.maxBytes) { [long]$answer.data.maxBytes }
    foreach ($s in $sources) {
        [pscustomobject]@{
            PSTypeName   = 'PivotSource'
            Id           = [string]$s.id
            Title        = [string]$s.title
            Description  = if ($s.description) { [string]$s.description }
            Kind         = [string]$s.kind
            Link         = [bool]$s.link
            Schedulable  = [bool]$s.schedulable
            Parameters   = @($s.params | Where-Object { $_ })
            Records      = $s.records -eq $true
            LinkParams   = [string[]]@($s.linkParams | Where-Object { $_ -is [string] })
            Views        = @($s.views | Where-Object { $_ })
            Rows         = if ($null -ne $s.rows) { [long]$s.rows }
            DataAsOf     = ConvertTo-UDPivotTime -Value $s.dataAsOf
            DataMaxBytes = $maxBytes
            RequestId    = if ($answer.requestId) { [string]$answer.requestId }
        }
    }
}
