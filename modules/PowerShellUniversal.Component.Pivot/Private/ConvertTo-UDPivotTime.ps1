function ConvertTo-UDPivotTime {
    <#
    .SYNOPSIS
        A time of a server answer as a DateTimeOffset in UTC, or nothing.
    .DESCRIPTION
        ConvertFrom-Json reads an ISO 8601 text as a DateTime already; any other text is parsed as UTC.
    .PARAMETER Value
        The value of the answer.
    .EXAMPLE
        ConvertTo-UDPivotTime -Value $answer.dataAsOf
    .OUTPUTS
        System.DateTimeOffset
    #>
    [CmdletBinding()]
    [OutputType([datetimeoffset])]
    param([AllowNull()][object]$Value)
    $parsed = [datetimeoffset]::MinValue
    if ($Value -is [datetime]) { [datetimeoffset]::new($Value.ToUniversalTime()) }
    elseif ($Value -and [datetimeoffset]::TryParse([string]$Value, [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal, [ref]$parsed)) { $parsed.ToUniversalTime() }
}
