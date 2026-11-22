function Read-UDPivotAnswerText {
    <#
    .SYNOPSIS
        Reads an answer's body as UTF-8 text in pieces, at most -MaxBytes bytes, without a copy of the
        whole body as bytes.
    .DESCRIPTION
        Decodes each piece as it arrives (a character split between two pieces included) into one
        StringBuilder: the text is the only copy of the body this process keeps. Past -MaxBytes it stops
        with PivotDataTooLarge before the rest is read. An answer that ends early (the connection is
        closed, the server cut a slow reader off) or takes longer than -TimeoutSec is PivotServerError.
    .PARAMETER Content
        The answer's HttpContent.
    .PARAMETER MaxBytes
        The most bytes of the body.
    .PARAMETER TimeoutSec
        The longest the body may take to read.
    .PARAMETER What
        What is called, for the message.
    .EXAMPLE
        Read-UDPivotAnswerText -Content $response.Content -MaxBytes 32MB -TimeoutSec 120 -What 'pivotkit-server'
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][System.Net.Http.HttpContent]$Content,
        [Parameter(Mandatory)][long]$MaxBytes,
        [Parameter(Mandatory)][int]$TimeoutSec,
        [Parameter(Mandatory)][string]$What
    )
    $declared = $Content.Headers.ContentLength
    if ($null -ne $declared -and $declared -gt $MaxBytes) {
        throw (New-UDPivotError -Id PivotDataTooLarge -Category LimitsExceeded -Data @{ MaxBytes = $MaxBytes } -Message ('{0}: the answer is {1:N0} bytes, more than {2} bytes (-MaxBytes); nothing was read. Filter the rows with a parameter, or raise -MaxBytes.' -f $What, $declared, $MaxBytes))
    }
    $cancel = [System.Threading.CancellationTokenSource]::new([timespan]::FromSeconds($TimeoutSec))
    $stream = $null
    try {
        $stream = $Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $decoder = [System.Text.UTF8Encoding]::new($false, $false).GetDecoder()
        $bytes = [byte[]]::new(65536)
        $chars = [char[]]::new(65537)
        $text = [System.Text.StringBuilder]::new()
        $total = [long]0
        while ($true) {
            try { $n = $stream.ReadAsync($bytes, 0, $bytes.Length, $cancel.Token).GetAwaiter().GetResult() }
            catch {
                $e = $_.Exception
                while ($e -is [System.Management.Automation.MethodInvocationException] -and $e.InnerException) { $e = $e.InnerException }
                if ($global:Error.Count -and [object]::ReferenceEquals($global:Error[0].Exception, $_.Exception)) { $global:Error.RemoveAt(0) }
                $why = if ($cancel.IsCancellationRequested) { 'took longer than {0} seconds' -f $TimeoutSec } else { $e.Message }
                throw (New-UDPivotError -Id PivotServerError -Message ('{0}: the answer was cut off after {1:N0} bytes ({2}). Ask again.' -f $What, $total, $why))
            }
            if ($n -le 0) { break }
            $total += $n
            if ($total -gt $MaxBytes) {
                throw (New-UDPivotError -Id PivotDataTooLarge -Category LimitsExceeded -Data @{ MaxBytes = $MaxBytes } -Message ('{0}: the answer is more than {1} bytes (-MaxBytes); the rest was not read. Filter the rows with a parameter, or raise -MaxBytes.' -f $What, $MaxBytes))
            }
            $count = $decoder.GetChars($bytes, 0, $n, $chars, 0, $false)
            $null = $text.Append($chars, 0, $count)
        }
        $count = $decoder.GetChars($bytes, 0, 0, $chars, 0, $true)
        if ($count) { $null = $text.Append($chars, 0, $count) }
        $text.ToString()
    }
    finally {
        if ($stream) { $stream.Dispose() }
        $cancel.Dispose()
    }
}
