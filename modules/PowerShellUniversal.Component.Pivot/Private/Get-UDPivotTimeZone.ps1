function Get-UDPivotTimeZone {
    <#
    .SYNOPSIS
        The server's time zone as an IANA name (Europe/Berlin), the default of -TimeZone.
    .DESCRIPTION
        Browsers know IANA names only; on Windows the zone id (W. Europe Standard Time) is converted.
        On Linux and macOS the name comes from TZ or the /etc/localtime link first: .NET may name the
        zone by another entry with the same rules (Atlantic/Jan_Mayen for Europe/Berlin, measured on
        macOS), which shows the same times but reads oddly. UTC when there is no IANA name.
    .EXAMPLE
        Get-UDPivotTimeZone
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    $pattern = '^(UTC|[A-Za-z_]+(/[A-Za-z0-9_+-]+){1,2})$'
    if ($env:TZ -and $env:TZ.TrimStart(':') -match $pattern) { return $env:TZ.TrimStart(':') }
    if (-not $IsWindows) {
        $link = Get-Item -LiteralPath '/etc/localtime' -ErrorAction Ignore
        $name = if ($link -and $link.LinkTarget -match 'zoneinfo/(?<zone>.+)$') { $Matches.zone }
        if ($name -and $name -match $pattern) { return $name }
    }
    $zone = [System.TimeZoneInfo]::Local
    if ($zone.HasIanaId) { return $zone.Id }
    $iana = $null
    if ([System.TimeZoneInfo]::TryConvertWindowsIdToIanaId($zone.Id, [ref]$iana)) { return $iana }
    'UTC'
}
