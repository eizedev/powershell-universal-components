function Invoke-UDPivotHttp {
    <#
    .SYNOPSIS
        One request (a POST, or a GET without a body) without redirects whose errors carry no request:
        the answer, or an error with the message alone.
    .DESCRIPTION
        Sends with HttpClient over New-UDPivotHttpHandler: a redirect is returned as it is, not followed,
        and an answer the server sends while the body is still being sent (a 413 for a body over its
        cap, after which it closes the connection) is returned like any other. A request that gets no
        answer becomes PivotServerUnreachable with the exception's message alone; the record PowerShell
        keeps of the failed call is removed from $Error. Nothing is written to the verbose or debug
        stream, so no token or secret reaches one.
    .PARAMETER Request
        Uri, Method (Post, the default, or Get), Body (bytes or a string, sent as UTF-8; none with Get),
        ContentType (with a body), Headers, TimeoutSec, and TextMaxBytes: a success (2xx) is read as
        UTF-8 text in pieces, at most this many bytes (Read-UDPivotAnswerText), into Text instead of
        Content.
    .PARAMETER What
        What is called, for the message ("pivotkit-server https://...").
    .PARAMETER Hint
        A line added to the message when there is no answer.
    .EXAMPLE
        Invoke-UDPivotHttp -Request @{ Uri = $uri; Body = $bytes; ContentType = 'application/json'; Headers = $headers; TimeoutSec = 30 } -What 'pivotkit-server'
    .OUTPUTS
        PSCustomObject with StatusCode (int), Headers (a case-insensitive hashtable of the answer's
        headers, the values of a repeated header joined by a comma) and Content (the body's bytes), or
        Text with TextMaxBytes on a success.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)][hashtable]$Request, [Parameter(Mandatory)][string]$What, [string]$Hint)
    $get = $Request['Method'] -eq 'Get'
    # assigned in each branch: the value of an if goes through the pipeline, which would send a body of
    # megabytes byte by byte and make an object[] of it (#204)
    $body = $null
    if (-not $get) {
        $body = $Request['Body']
        if ($body -isnot [byte[]]) { $body = [System.Text.Encoding]::UTF8.GetBytes([string]$body) }
    }
    # every header value as visible ASCII or a tab (RFC 9110 5.5): HttpClient sends other characters as
    # they are (a line break would start another header) or fails with a message that looks like an
    # unreachable server. The error names the header (without line breaks), never its value (a token)
    $headers = [ordered]@{
        # a client name, as Invoke-WebRequest sends one: some proxies and firewalls refuse a request without
        'User-Agent' = 'PowerShellUniversal.Component.Pivot/{0} PowerShell/{1}' -f $ExecutionContext.SessionState.Module.Version, $PSVersionTable.PSVersion
    }
    if ($Request['Headers']) { foreach ($k in $Request['Headers'].Keys) { $headers[$k] = [string]$Request['Headers'][$k] } }
    foreach ($k in @($headers.Keys) + @(if (-not $get) { 'Content-Type' })) {
        $value = if ($k -eq 'Content-Type') { [string]$Request['ContentType'] } else { $headers[$k] }
        if ($value -cnotmatch '^[\x20-\x7E\t]*$') { throw ('{0}: the request header {1} holds a character a header cannot carry (a control character other than tab, or one outside ASCII); nothing was sent.' -f $What, ($k -replace '[\r\n]', '')) }
    }
    $client = $null
    $message = $null
    $response = $null
    $failure = $null
    try {
        $client = [System.Net.Http.HttpClient]::new((New-UDPivotHttpHandler), $true)
        $message = [System.Net.Http.HttpRequestMessage]::new($(if ($get) { [System.Net.Http.HttpMethod]::Get } else { [System.Net.Http.HttpMethod]::Post }), [uri]$Request['Uri'])
        if ($Request['TimeoutSec']) { $client.Timeout = [timespan]::FromSeconds($Request['TimeoutSec']) }
        if (-not $get) {
            $message.Content = [System.Net.Http.ByteArrayContent]::new($body)
            if (-not $message.Content.Headers.TryAddWithoutValidation('Content-Type', [string]$Request['ContentType'])) { throw ('{0}: the request header Content-Type could not be set; nothing was sent.' -f $What) }
        }
        foreach ($k in $headers.Keys) {
            if (-not $message.Headers.TryAddWithoutValidation($k, $headers[$k])) { throw ('{0}: the request header {1} could not be set; nothing was sent.' -f $What, ($k -replace '[\r\n]', '')) }
        }
        $textMax = [long]$Request['TextMaxBytes']
        try {
            # with a text cap the body is read in pieces after the headers: the rows route sends no
            # Content-Length, and HttpClient would otherwise buffer all of it first
            $completion = if ($textMax -gt 0) { [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead } else { [System.Net.Http.HttpCompletionOption]::ResponseContentRead }
            $response = $client.SendAsync($message, $completion).GetAwaiter().GetResult()
            $headers = [hashtable]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($pair in @($response.Headers) + @($response.Content.Headers)) { $headers[$pair.Key] = @($pair.Value) -join ', ' }
            $status = [int]$response.StatusCode
            if ($textMax -gt 0 -and $status -ge 200 -and $status -lt 300) {
                return [pscustomobject]@{
                    StatusCode = $status
                    Headers    = $headers
                    Text       = Read-UDPivotAnswerText -Content $response.Content -MaxBytes $textMax -TimeoutSec $(if ($Request['TimeoutSec']) { [int]$Request['TimeoutSec'] } else { 100 }) -What $What
                }
            }
            # an answer that is no success holds a problem document of a few hundred bytes: in the text
            # mode its body is read with the same cap and time limit, so a stalled or huge error body
            # cannot hold the page
            # assigned in each branch: the value of an if goes through the pipeline, which turns a byte[]
            # into an object[] of single bytes, byte by byte (#204)
            if ($textMax -gt 0) {
                $errorText = try { Read-UDPivotAnswerText -Content $response.Content -MaxBytes $Script:ErrorBodyMaxBytes -TimeoutSec $(if ($Request['TimeoutSec']) { [int]$Request['TimeoutSec'] } else { 100 }) -What $What }
                catch {
                    # the status says enough; keep no record of the cut body in $Error
                    Remove-UDPivotErrorRecord -ErrorRecord $_
                    ''
                }
                $content = [System.Text.Encoding]::UTF8.GetBytes([string]$errorText)
            }
            else { $content = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult() }
            return [pscustomobject]@{
                StatusCode = $status
                Headers    = $headers
                Content    = $content
            }
        }
        catch {
            # an error of this module (the cap, an answer cut off) goes out as it is
            if ($_.FullyQualifiedErrorId -match '^Pivot[A-Za-z]+$') { throw }
            # the innermost exception that says what went wrong (a method call wraps it once)
            $e = $_.Exception
            while ($e -is [System.Management.Automation.MethodInvocationException] -and $e.InnerException) { $e = $e.InnerException }
            $failure = $e.Message
            if ($e.InnerException -and $e.InnerException.Message -and $e.InnerException.Message -ne $failure) { $failure = '{0} ({1})' -f $failure, $e.InnerException.Message }
            # keep no record of the call (with its request and headers) in $Error
            Remove-UDPivotErrorRecord -ErrorRecord $_
        }
    }
    finally {
        if ($response) { $response.Dispose() }
        if ($message) { $message.Dispose() }
        if ($client) { $client.Dispose() }
    }
    $text = '{0} did not answer: {1}' -f $What, $(if ($failure) { $failure } else { 'no response' })
    if ($Hint) { $text += [Environment]::NewLine + $Hint }
    throw (New-UDPivotError -Id PivotServerUnreachable -Category ConnectionError -Message $text)
}
