function Get-UDPivotReportLink {
    <#
    .SYNOPSIS
        POSTs a render to pivotkit-server's /views/render with save: true and returns the report's
        download link.
    .DESCRIPTION
        The server saves the report in its output directory and answers with JSON. A view with errors
        is a 200 with ok: false: PivotViewHasErrors with the findings. A report the server saved without
        a link (a closed source or data sent with the request without a bound link, a key the server
        cannot read) and a server without an output directory (409 NO_OUTPUT) are PivotNoLink, with the
        server's own words.
    .PARAMETER Uri
        The REST service's address, https://host/api/v1.
    .PARAMETER Body
        The input of render_view as UTF-8 JSON with save: true (New-UDPivotRenderBody -Save).
    .PARAMETER Auth
        As Invoke-UDPivotRestCall takes it.
    .PARAMETER TimeoutSec
        The longest wait for the answer.
    .EXAMPLE
        Get-UDPivotReportLink -Uri 'https://reports.example.com/api/v1' -Body $json -Auth @{ Token = $Secret:PivotkitToken }
    .OUTPUTS
        System.Management.Automation.PSCustomObject (PivotReportLink).
    #>
    [CmdletBinding()]
    [OutputType('PivotReportLink')]
    param(
        [Parameter(Mandatory)][uri]$Uri,
        [Parameter(Mandatory)][byte[]]$Body,
        [Parameter(Mandatory)][hashtable]$Auth,
        [ValidateRange(1, 3600)][int]$TimeoutSec = $Script:ReportTimeoutSec
    )
    $where = Get-UDPivotSafeAddress -Uri ([uri]((Get-UDPivotSafeAddress -Uri $Uri).TrimEnd('/') + '/views/render'))
    $noLink = 'Ask the operator to turn on download links (output.dir, and output.downloads for the server''s own links), or call without -AsLink for the file itself.'
    $idTextOf = { param($Id) if ($Id) { [Environment]::NewLine + ('Request id for the operator: {0}' -f $Id) } }
    try { $response = Invoke-UDPivotRestCall -Uri $Uri -Route '/views/render' -Body $Body -Auth $Auth -TimeoutSec $TimeoutSec }
    catch {
        $p = $_.TargetObject
        if ($p -and $p.Code -eq 'NO_OUTPUT') {
            throw (New-UDPivotError -Id PivotNoLink -Category NotEnabled -TargetObject $p -Data @{ Status = $p.Status; Code = $p.Code; Title = $p.Title; Detail = $p.Detail; RequestId = $p.RequestId } -Message ('pivotkit-server {0} saves no reports, so it gives no download links: {1} ({2}): {3}{4}{5}{6}' -f $where, $p.Code, $p.Status, $p.Detail, [Environment]::NewLine, $noLink, (& $idTextOf $p.RequestId)))
        }
        throw
    }
    try { $answer = ConvertFrom-Json -InputObject ([System.Text.Encoding]::UTF8.GetString($response.Content)) -Depth 16 }
    catch { Remove-UDPivotErrorRecord -ErrorRecord $_; throw (New-UDPivotError -Id PivotServerError -Data @{ Status = $response.StatusCode } -Message ('pivotkit-server {0} answered {1} without JSON.' -f $where, $response.StatusCode)) }
    $p = ConvertTo-UDPivotServerProblem -Response $response -Answer $answer
    $data = @{ Status = $p.Status; Detail = $p.Detail; RequestId = $p.RequestId }
    $idText = & $idTextOf $p.RequestId
    if ($answer.ok -ne $true) {
        $lines = @(Get-UDPivotFindingText -Finding @($p.Findings | Where-Object { $_.severity -eq 'error' }))
        # an answer without findings of its own still says what happened
        if (-not $lines.Count) { $lines = @($(if ($p.Detail) { $p.Detail } else { 'no reason given' })) }
        throw (New-UDPivotError -Id PivotViewHasErrors -Category InvalidData -TargetObject $p -Data $data -Message ('pivotkit-server {0}: the view has errors, no report was made:{1}{2}{3}' -f $where, [Environment]::NewLine, ($lines -join [Environment]::NewLine), $idText))
    }
    $output = $answer.output
    if (-not $output -or -not ($output.url -is [string]) -or -not $output.url) {
        $said = if ($p.Detail) { $p.Detail } else { 'no reason given' }
        throw (New-UDPivotError -Id PivotNoLink -Category NotEnabled -TargetObject $p -Data $data -Message ('pivotkit-server {0} gave no download link for this report. The server said: {1}{2}{3}{4}' -f $where, $said, [Environment]::NewLine, ('A report over a source the operator keeps closed, or over data sent with -Data, gets a link only where the operator binds links to a sign-in or to one download. ' + $noLink), $idText))
    }
    # the link goes onto pages and into mails: an absolute http or https address, nothing else
    $url = $null
    if (-not [uri]::TryCreate($output.url, [UriKind]::Absolute, [ref]$url) -or $url.Scheme -notin 'https', 'http') {
        throw (New-UDPivotError -Id PivotServerError -TargetObject $p -Data $data -Message ('pivotkit-server {0} answered with a download link that is no http or https address (scheme "{1}"); it is not returned.{2}' -f $where, $(if ($url) { $url.Scheme } else { 'none' }), $idText))
    }
    foreach ($finding in @($p.Findings | Where-Object { $_.severity -eq 'warning' })) { Write-Warning ('pivotkit: {0}' -f (Get-UDPivotFindingText -Finding @($finding))) }
    [pscustomobject]@{
        PSTypeName = 'PivotReportLink'
        Url        = $output.url
        ExpiresAt  = ConvertTo-UDPivotTime -Value $output.expiresAt
        Rows       = if ($answer.summary -and $null -ne $answer.summary.rows) { [int]$answer.summary.rows }
        RequestId  = $p.RequestId
        Format     = [string]$(if ($output.format) { $output.format } else { $answer.format })
        FileName   = [string]$output.filename
        Bound      = [string]$output.bound
        DataAsOf   = ConvertTo-UDPivotTime -Value $answer.dataAsOf
        Message    = [string]$answer.message
    }
}
