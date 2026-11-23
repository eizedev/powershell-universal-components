function ConvertTo-UDPivotTime {
    <#
    .SYNOPSIS
        A time of a server answer as a DateTimeOffset in UTC, or nothing.
    .DESCRIPTION
        ConvertFrom-Json reads an ISO 8601 text as a DateTime already. A time without an offset, as a
        DateTime of an unspecified kind or as text, is read as UTC, never as the server's local time.
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
    if ($Value -is [datetime]) {
        $utc = if ($Value.Kind -eq [System.DateTimeKind]::Unspecified) { [datetime]::SpecifyKind($Value, [System.DateTimeKind]::Utc) } else { $Value.ToUniversalTime() }
        [datetimeoffset]::new($utc)
    }
    elseif ($Value -and [datetimeoffset]::TryParse([string]$Value, [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal, [ref]$parsed)) { $parsed.ToUniversalTime() }
}
