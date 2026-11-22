function Get-UDPivotServerRecord {
    <#
    .SYNOPSIS
        The rows of a pivotkit-server source for New-UDPivotReport -Uri -Source: the token checked, the
        parameters sent, the answer read.
    .PARAMETER Bound
        New-UDPivotReport's $PSBoundParameters: Uri, Source, Token, Parameter and Query.
    .PARAMETER Cmdlet
        New-UDPivotReport's $PSCmdlet: without -Parameter and -Query, $Query of the page that calls it.
    .PARAMETER Auth
        The sign-in of Resolve-UDPivotRestSignIn.
    .PARAMETER ViewName
        The name of a view the server publishes for the source, or nothing.
    .PARAMETER MaxBytes
        The most bytes of the answer to read.
    .PARAMETER TimeoutSec
        How long the server may take.
    .EXAMPLE
        $records = Get-UDPivotServerRecord -Bound $PSBoundParameters -Cmdlet $PSCmdlet -Auth $auth -MaxBytes $MaxBytes -TimeoutSec $TimeoutSec
    .OUTPUTS
        The answer of Get-UDPivotRecordText.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Bound,
        [Parameter(Mandatory)][System.Management.Automation.PSCmdlet]$Cmdlet,
        [Parameter(Mandatory)][hashtable]$Auth,
        [string]$ViewName,
        [Parameter(Mandatory)][long]$MaxBytes,
        [Parameter(Mandatory)][int]$TimeoutSec
    )
    $token = $Bound['Token']
    # no token: a visitor who is not signed in, or PSU's sign-in without SaveTokens. The reader is
    # asked to sign in; nothing is sent
    $empty = $null -eq $token -or ($token -is [string] -and $token -eq '') -or ($token -is [securestring] -and $token.Length -eq 0)
    if ($empty) {
        throw (New-UDPivotError -Id PivotTokenRefused -Category AuthenticationError -Message '-Token is empty: no access token of the signed-in person. Pass $AccessToken on a page of an app with sign-in, and turn on Authentication__OIDC__SaveTokens in PSU, so PSU keeps the token.')
    }
    # a token of another type or with whitespace in it is the app's mistake: a plain error
    $null = ConvertTo-UDPivotPlainText -Secret $token -Name '-Token'
    $sent = if ($Bound.ContainsKey('Parameter')) { $Bound['Parameter'] } else {
        # $Query of the page, as $User; a script block defined in the app script has none
        $pageQuery = if ($Bound.ContainsKey('Query')) { $Bound['Query'] } else { $Cmdlet.SessionState.PSVariable.GetValue('Query') }
        if ($pageQuery -is [System.Collections.IDictionary] -and $pageQuery.Count) { Get-UDPivotLinkParameter -Uri $Bound['Uri'] -Source $Bound['Source'] -Query $pageQuery -Auth $Auth -TimeoutSec $TimeoutSec }
    }
    Get-UDPivotRecordText -Uri $Bound['Uri'] -Source $Bound['Source'] -Parameter $sent -ViewName $ViewName -Auth $Auth -MaxBytes $MaxBytes -TimeoutSec $TimeoutSec
}
