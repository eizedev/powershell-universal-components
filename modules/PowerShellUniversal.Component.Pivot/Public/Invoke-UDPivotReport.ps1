function Invoke-UDPivotReport {
    <#
    .SYNOPSIS
        Renders a pivot report without a browser - an Excel workbook, an HTML report, CSV, JSON or the
        chart as SVG - from data PowerShell already has, with pivotkit's command line (Node) or a
        pivotkit-server (REST).
    .DESCRIPTION
        For endpoints, scheduled scripts and jobs: the same view a reader builds in New-UDPivotReport
        (Views, Download view, or Get-UDElement's .view) runs over the rows and becomes a file.

        -Engine Node runs pivotkit's command line on the PSU server (npm install --global pivotkit-cli,
        Node 22 or later, pivotkit-cli 0.2.1 or later): the rows go into a temporary JSON file in a folder of its own that only this
        user can read, pivotkit reads and writes only there (--allow-dir), and the folder is removed
        afterwards, also on an error.

        -Engine Rest calls a pivotkit-server (POST /api/v1/views/render/file, or /views/render with
        -AsLink). The rows go in the request
        (source "inline:", pivotkit's data in the request): nothing has to be put on the server first.
        The server's operator turns this on per caller (a profile with data: true, or policy.data) and
        caps the body (rest.data.maxBytes, default 10 MiB). With -Source instead of -Data the report
        runs over a source the operator configured (the caller needs results: true). -Data and
        -Parameter need pivotkit-server 0.2.0 or later; pivotkit-server 0.1.1 renders -Source without
        parameters, and the error of its answer to -Data or -Parameter says so. Sign-in: a static
        token (-Token), or OAuth client credentials (-Credential with -TokenUri), the access token kept
        per runspace until shortly before it expires and fetched again once after a 401. Only https, or
        http to this machine; redirects are not followed; neither the token nor the client secret is
        ever written to an error, a log or the output.

        A view with errors writes nothing: the error lists pivotkit's findings (the field it did not
        find, the name it probably meant). Warnings of the command line go to the warning stream.

        Every failure has a fixed error id ($_.FullyQualifiedErrorId): PivotServerUnreachable,
        PivotRedirectRefused, PivotTokenRefused, PivotDataTooLarge (over -MaxBytes, or the server's 413:
        BODY_TOO_LARGE for a request over its cap, also when the server answers it while the request is
        still being sent; LIMIT_EXCEEDED for a report over a limit of the server), PivotViewHasErrors,
        PivotNoLink (-AsLink: the server gave no download link), PivotServerError (any other answer,
        400 and 404 included), PivotCliNotFound, PivotCliFailed. For an answer of the server,
        $_.TargetObject is a PivotServerProblem with Status, Code, Title, Detail, RequestId, Retryable,
        RetryAfter, Type and Findings; $_.Exception.Data holds Status, Code, Title, Detail, RetryAfter,
        Retryable and RequestId where the server sent them. The message says when to try again or that
        trying again may work.
    .PARAMETER Data
        The rows: a DataTable (Invoke-Sqlcmd), DataRows, objects, hashtables or a script block, as
        New-UDPivotReport takes them. Dates are sent as ISO 8601 text and read as dates; DBNull is empty.
    .PARAMETER Source
        -Engine Rest: the id of a source the server's operator configured, instead of -Data.
    .PARAMETER Parameter
        -Engine Rest with -Source: the values of the source's parameters (@{ customer = 'acme' }).
    .PARAMETER View
        The view: a hashtable, JSON text, or a view file (pivotkit's Views, Download view) as JSON text or
        object. Checked like every view (ConvertFrom-UDPivotViewFile); its name is the default title.
    .PARAMETER Layout
        Instead of -View, the view by field names, as pivotkit's layout flags take it:
        @{ rows = 'Team'; cols = 'Priority'; values = @{ field = 'Hours'; agg = 'sum' };
        groups = @{ field = 'Created'; by = 'yearMonth' }; filters = @(...); chart = 'bar';
        map = @{ Revenue = 'Turnover' } }.
    .PARAMETER Format
        xlsx (Excel), html (a report to read or print), csv, json or svg (the chart). Default: the
        extension of -OutFile, else xlsx.
    .PARAMETER OutFile
        Write the file here and return it as a FileInfo. Without it the function returns the file's bytes
        (System.Byte[]), for an endpoint's answer or a mail attachment. A file that is there is replaced,
        and a symbolic link is followed to its target: give a path of your script's, never one from a
        reader, a request or other input.
    .PARAMETER Title
        The report's title in the workbook and the HTML report (default: the view's name).
    .PARAMETER Engine
        Node (pivotkit's command line on this server) or Rest (a pivotkit-server).
    .PARAMETER CliPath
        -Engine Node: the pivotkit program, or pivotkit-cli's bin/pivotkit.js. Default: pivotkit on the
        PATH.
    .PARAMETER Locale
        -Engine Node: numbers, dates and the report's words (de-DE writes German ones). Default en-US.
    .PARAMETER TimeZone
        -Engine Node: the zone of the data's dates (IANA, default UTC).
    .PARAMETER Uri
        -Engine Rest: the REST service's address, https://reports.example.com/api/v1. An address with a user
        name or password, a query string (?...) or a fragment (#...) in it is refused.
    .PARAMETER Token
        -Engine Rest: a static token, as a string or SecureString - a PSU secret ($Secret:PivotkitToken).
    .PARAMETER Credential
        -Engine Rest: OAuth client credentials, the client id as user name and the client secret as
        password - a PSU secret of type PSCredential ($Secret:PivotkitClient). Needs -TokenUri.
    .PARAMETER TokenUri
        The OAuth provider's token endpoint (Authentik: https://<authentik>/application/o/token/).
    .PARAMETER Scope
        Scopes to ask the provider for: the REST scope the operator set (rest.requiredScopes), e.g.
        pivotkit:rest. Without it the server answers 403 INSUFFICIENT_SCOPE (PivotTokenRefused).
    .PARAMETER Audience
        The audience parameter some providers want for the access token (Auth0).
    .PARAMETER Resource
        RFC 8707's resource parameter: the REST service's address, for providers that issue tokens per
        resource.
    .PARAMETER ClientAuthentication
        How the client authenticates at the token endpoint: Post (client_secret_post, the default) or
        Basic (client_secret_basic).
    .PARAMETER DataName
        -Engine Rest with -Data: what the data is, the report's name when it has no title.
    .PARAMETER DataAsOf
        -Engine Rest with -Data: when the data is from, sent as the data's asOf. The server keeps it with
        the request (its answer's suppliedAsOf); the file's own "Data as of" is when the data arrived.
    .PARAMETER MaxBytes
        -Engine Rest with -Data: the most bytes the request may carry, default 10 MiB (pivotkit-server's
        default rest.data.maxBytes; raise it to what the operator set, at most 64 MiB). The rows are
        written into the request one by one and checked every 256 rows: the function stops with
        PivotDataTooLarge at most 255 rows after they pass it, before the rest is converted and before
        anything is sent. Rows that are no DataTable and no list of PSCustomObjects (hashtables, a mix)
        are converted in full first.
    .PARAMETER Template
        -Engine Node with -Format html: a print template for the HTML report (pivotkit's
        {{placeholders}}, at most 262,144 characters). The function copies it into the run's own folder and passes it
        as --template. pivotkit trusts a template like code: give a file of your own, never one from a
        reader. With -Engine Rest the server's source decides the template, so it is refused there.
    .PARAMETER Numbers
        -Engine Node with -Format csv or json: Full writes every number with full precision (the command
        line's default), Shown rounds it to the decimals the view shows, as pivotkit-server writes them.
        Needs pivotkit-cli 0.5.0 or later.
    .PARAMETER FlatHeader
        -Engine Node with -Format csv: one header row instead of one per column field; each column
        names its labels joined with " / ". Needs pivotkit-cli 0.5.0 or later.
    .PARAMETER AsLink
        -Engine Rest: the server saves the report and the function returns its download link instead of
        the file (POST /views/render with save: true): a PivotReportLink with Url, ExpiresAt (UTC; empty
        where the server names no expiry, as for some links of an operator's own store), Rows
        (the rows of the report's table, without the header; empty where the server withholds it),
        RequestId, Format, FileName, Bound (none, once or signIn), DataAsOf and Message. Where the
        server gives no link, PivotNoLink says why. Not with -OutFile.
    .PARAMETER TimeoutSec
        The longest a run may take, in seconds. Default 120. -Engine Node: the command line's run.
        -Engine Rest: each call as a whole, from sending the request to the last byte of the answer
        (the report is read in full before it is returned); the token request with -Credential has
        its own limit of the same length.
    .PARAMETER WhatIf
        With -OutFile: says which file would be written and runs nothing.
    .PARAMETER Confirm
        With -OutFile: asks before the file is written.
    .EXAMPLE
        # a scheduled script: tickets per team as an Excel workbook, with the view a reader saved
        $view = Get-Content -LiteralPath (Join-Path $Repository 'views' 'tickets-per-team.pivotkit.json') -Raw
        Invoke-UDPivotReport -Engine Node -Data (Invoke-Sqlcmd -Query 'SELECT * FROM Tickets') -View $view -OutFile '/reports/tickets.xlsx'
    .EXAMPLE
        # an endpoint that answers with an HTML report, made by a pivotkit-server
        New-PSUEndpoint -Url '/reports/tickets' -Endpoint {
            Import-Module PowerShellUniversal.Component.Pivot
            $bytes = Invoke-UDPivotReport -Engine Rest -Uri 'https://reports.example.com/api/v1' -Token $Secret:PivotkitToken `
                -Data (Get-Ticket) -Layout @{ rows = 'Team'; values = @{ field = 'Id'; agg = 'count' } } -Format html
            New-PSUApiResponse -Data $bytes -ContentType 'text/html; charset=utf-8'
        }
    .EXAMPLE
        # an HTML report in the company's design, from a print template of your own
        Invoke-UDPivotReport -Engine Node -Data $tickets -View $view -Format html -Template (Join-Path $Repository 'templates' 'corporate.template.html') -OutFile '/reports/tickets.html'
    .EXAMPLE
        # a link to the report that expires, for a mail or a page, instead of the file
        $link = Invoke-UDPivotReport -Engine Rest -Uri 'https://reports.example.com/api/v1' -Token $Secret:PivotkitToken -Source 'sales' -View $view -AsLink
        '{0} (until {1:u})' -f $link.Url, $link.ExpiresAt
    .EXAMPLE
        # OAuth client credentials from Authentik; the token is reused until it expires
        Invoke-UDPivotReport -Engine Rest -Uri 'https://reports.example.com/api/v1' -Credential $Secret:PivotkitClient `
            -TokenUri 'https://login.example.com/application/o/token/' -Scope 'pivotkit:rest' -Source 'sales' -View $view -OutFile ./sales.xlsx
    .OUTPUTS
        System.IO.FileInfo with -OutFile, a PivotReportLink with -AsLink, else System.Byte[].
    .LINK
        https://powershell-universal-components.eize.dev/pivot/reports/
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'View')]
    [OutputType([System.IO.FileInfo], [byte[]], [pscustomobject])]
    param(
        [AllowNull()][object]$Data,
        [ValidateLength(1, 1024)][ValidatePattern('^(?!file:|inline:)')][string]$Source,
        [System.Collections.IDictionary]$Parameter,
        [Parameter(Mandatory, ParameterSetName = 'View')][AllowNull()][object]$View,
        [Parameter(Mandatory, ParameterSetName = 'Layout')][System.Collections.IDictionary]$Layout,
        [ValidateSet('xlsx', 'html', 'csv', 'json', 'svg')][string]$Format,
        [ValidateNotNullOrEmpty()][string]$OutFile,
        [ValidateLength(1, 200)][string]$Title,
        [Parameter(Mandatory)][ValidateSet('Node', 'Rest')][string]$Engine,
        [string]$CliPath,
        [ValidateScript({ $_ -match $Script:LocalePattern }, ErrorMessage = 'Locale "{0}": expected a language tag such as en-US or de-DE.')][string]$Locale,
        [ValidatePattern('^(UTC|[A-Za-z_]+(/[A-Za-z0-9_+-]+){1,2})$')][string]$TimeZone,
        [uri]$Uri,
        [AllowNull()][object]$Token,
        [pscredential]$Credential,
        [uri]$TokenUri,
        [ValidateNotNullOrEmpty()][string[]]$Scope,
        [ValidateNotNullOrEmpty()][string]$Audience,
        [ValidateNotNullOrEmpty()][string]$Resource,
        [ValidateSet('Post', 'Basic')][string]$ClientAuthentication = 'Post',
        [ValidateLength(1, 200)][string]$DataName,
        [Nullable[datetime]]$DataAsOf,
        [ValidateRange(1KB, 64MB)][long]$MaxBytes = 10MB,
        [ValidateNotNullOrEmpty()][string]$Template,
        [ValidateSet('Full', 'Shown')][string]$Numbers,
        [switch]$FlatHeader,
        [switch]$AsLink,
        [ValidateRange(1, 3600)][int]$TimeoutSec = $Script:ReportTimeoutSec
    )
    # -ErrorVariable gets the error itself, not each step it took through the module
    $errorMark = Get-UDPivotErrorMark -Cmdlet $PSCmdlet
    trap { Reset-UDPivotErrorVariable -Mark $errorMark; throw $_ }

    Assert-UDPivotReportEngine -Bound $PSBoundParameters -Engine $Engine
    if ($Engine -eq 'Rest') {
        $auth = Resolve-UDPivotRestSignIn -Bound $PSBoundParameters -TimeoutSec $TimeoutSec
        Assert-UDPivotRestInput -Bound $PSBoundParameters
    }
    $output = Resolve-UDPivotReportOutput -Bound $PSBoundParameters -Cmdlet $PSCmdlet
    $report = Get-UDPivotReportInput -Bound $PSBoundParameters -ParameterSetName $PSCmdlet.ParameterSetName
    if ($output.Target -and -not $PSCmdlet.ShouldProcess($output.Target, ('Write a pivot report ({0})' -f $output.Kind))) { return }

    if ($Engine -eq 'Rest') {
        $rest = @{ Bound = $PSBoundParameters; Report = $report; Kind = $output.Kind; Auth = $auth; MaxBytes = $MaxBytes; TimeoutSec = $TimeoutSec }
        # -AsLink: the link to the report the server keeps
        if ($AsLink) { return Invoke-UDPivotRestReport @rest -AsLink }
        $bytes = Invoke-UDPivotRestReport @rest
    }
    else { $bytes = Invoke-UDPivotNodeReport -Bound $PSBoundParameters -Report $report -Output $output -TimeoutSec $TimeoutSec }

    if ($output.Target) {
        [System.IO.File]::WriteAllBytes($output.Target, $bytes)
        return Get-Item -LiteralPath $output.Target
    }
    , $bytes
}
