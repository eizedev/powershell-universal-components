function Get-UDPivotRecordText {
    <#
    .SYNOPSIS
        The rows of a server source for the signed-in person, as the JSON text the server sent.
    .DESCRIPTION
        POSTs { source, params, view } to /sources/records with the person's token and reads the answer
        as text in pieces, at most -MaxBytes bytes (Read-UDPivotAnswerText). The text is checked to be
        a whole JSON object with the columnar rows (columns and data), read with System.Text.Json and
        never turned into PowerShell objects. Errors by the rows route's codes: PivotTokenRefused,
        PivotRowsNotAllowed, PivotNoData, PivotDataTooLarge, PivotServerBusy, PivotServerError.
    .PARAMETER Uri
        The REST service's address.
    .PARAMETER Source
        The source id.
    .PARAMETER Parameter
        The source's parameters.
    .PARAMETER ViewName
        The name of a view the server publishes for the source: only the fields it uses leave.
    .PARAMETER Auth
        @{ Token }.
    .PARAMETER MaxBytes
        The most bytes of the answer.
    .PARAMETER TimeoutSec
        The longest wait for the answer.
    .EXAMPLE
        Get-UDPivotRecordText -Uri $uri -Source 'vms' -Auth @{ Token = $AccessToken } -MaxBytes 32MB
    .OUTPUTS
        PSCustomObject with Text, Columns, RowCount and RequestId.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][uri]$Uri,
        [Parameter(Mandatory)][string]$Source,
        [System.Collections.IDictionary]$Parameter,
        [string]$ViewName,
        [Parameter(Mandatory)][hashtable]$Auth,
        [Parameter(Mandatory)][long]$MaxBytes,
        [int]$TimeoutSec = $Script:ReportTimeoutSec
    )
    $body = [ordered]@{ source = $Source }
    if ($Parameter -and $Parameter.Count) {
        $params = [ordered]@{}
        # a value the page does not have ($Query.customer of a page opened without it) is left out, so the
        # server says which parameter is missing instead of refusing a null
        foreach ($k in @($Parameter.Keys | Sort-Object { [string]$_ })) { if ($null -ne $Parameter[$k]) { $params[[string]$k] = $Parameter[$k] } }
        if ($params.Count) { $body['params'] = $params }
    }
    if ($ViewName) { $body['view'] = $ViewName }
    $json = ConvertTo-Json -InputObject $body -Depth 4 -Compress
    $where = Get-UDPivotSafeAddress -Uri ([uri]((Get-UDPivotSafeAddress -Uri $Uri).TrimEnd('/') + '/sources/records'))
    $response = Invoke-UDPivotRestCall -Uri $Uri -Route '/sources/records' -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) -Auth $Auth -TimeoutSec $TimeoutSec -TextMaxBytes $MaxBytes -RowsRoute
    $text = $response.Text
    $document = $null
    try { $document = [System.Text.Json.JsonDocument]::Parse($text) }
    catch {
        if ($global:Error.Count -and [object]::ReferenceEquals($global:Error[0].Exception, $_.Exception)) { $global:Error.RemoveAt(0) }
        $why = if ($text.TrimStart().StartsWith('{')) { 'it was cut off on the way (a slow or idle reader, the server''s time limit). Ask again.' } else { 'it is no JSON at all (a proxy''s page, another service at this address). Check -Uri.' }
        throw (New-UDPivotError -Id PivotServerError -Data @{ Status = $response.StatusCode } -Message ('pivotkit-server {0}: the answer is no whole JSON text; {1}' -f $where, $why))
    }
    try {
        $root = $document.RootElement
        # the top-level keys, read once; the rows (data) are only checked to be a list
        $keys = @{}
        if ($root.ValueKind -eq 'Object') { foreach ($property in $root.EnumerateObject()) { $keys[$property.Name] = $property.Value } }
        $isTable = $keys.ContainsKey('columns') -and $keys['columns'].ValueKind -eq 'Array' -and $keys.ContainsKey('data') -and $keys['data'].ValueKind -eq 'Array'
        if (-not $isTable) { throw (New-UDPivotError -Id PivotServerError -Data @{ Status = $response.StatusCode } -Message ('pivotkit-server {0}: the answer holds no columnar rows (columns and data).' -f $where)) }
        $names = { param($Element) if ($null -ne $Element -and $Element.ValueKind -eq 'Array') { [string[]]@(foreach ($e in $Element.EnumerateArray()) { if ($e.ValueKind -eq 'String') { $e.GetString() } }) } else { [string[]]@() } }
        $rowCount = $keys['rowCount']
        $requestId = $keys['requestId']
        $count = [long]0
        [pscustomobject]@{
            Text      = $text
            Columns   = & $names $keys['columns']
            RowCount  = if ($null -ne $rowCount -and $rowCount.ValueKind -eq 'Number' -and $rowCount.TryGetInt64([ref]$count)) { $count } else { $null }
            RequestId = if ($null -ne $requestId -and $requestId.ValueKind -eq 'String') { $requestId.GetString() } elseif ($response.Headers['X-Request-Id']) { [string]$response.Headers['X-Request-Id'] } else { $null }
        }
    }
    finally { $document.Dispose() }
}
