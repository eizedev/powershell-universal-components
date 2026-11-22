function Get-UDPivotRetryText {
    <#
    .SYNOPSIS
        "Try again in N seconds." or "Try again after <time>." from a Retry-After header; $null when it
        is absent, neither form, or a date in the past.
    .PARAMETER RetryAfter
        The header's value: seconds, or an HTTP date (RFC 9110 10.2.3).
    .EXAMPLE
        Get-UDPivotRetryText -RetryAfter '7'
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowNull()][AllowEmptyString()][string]$RetryAfter)
    if ([string]::IsNullOrWhiteSpace($RetryAfter)) { return $null }
    $seconds = 0
    if ([int]::TryParse($RetryAfter.Trim(), [System.Globalization.NumberStyles]::None, [cultureinfo]::InvariantCulture, [ref]$seconds)) { return 'Try again in {0} seconds.' -f $seconds }
    $when = [datetimeoffset]::MinValue
    # a date in the past (a clock that is off, a cached answer) says nothing about when
    if ([datetimeoffset]::TryParse($RetryAfter, [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal, [ref]$when) -and $when -gt [datetimeoffset]::UtcNow) { return 'Try again after {0}.' -f $when.UtcDateTime.ToString('u', [cultureinfo]::InvariantCulture) }
    $null
}
