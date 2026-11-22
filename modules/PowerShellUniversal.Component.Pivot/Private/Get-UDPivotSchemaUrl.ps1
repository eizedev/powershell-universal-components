function Get-UDPivotSchemaUrl {
    <#
    .SYNOPSIS
        The checked -SchemaUrl of a command, else the module-wide default, else $null (pivotkit's own).
    .DESCRIPTION
        The one check of -SchemaUrl for every command: '' (no $schema), an https address without user
        name or password, or a path on the instance that starts with a single "/"; no spaces or control
        characters, at most 2000 characters. Without -Given the value of the environment variable
        PSU_COMPONENT_PIVOT_SCHEMA_URL is checked the same way and returned; unset or empty, the result is
        $null. A value that does not pass stops with the name it came from.
    .PARAMETER SchemaUrl
        The value of -SchemaUrl.
    .PARAMETER Given
        -SchemaUrl was passed: it wins over the default, also when it is ''.
    .EXAMPLE
        Get-UDPivotSchemaUrl -SchemaUrl '/assets/pivot/schema/view-file-2.json' -Given
    .OUTPUTS
        System.String, or $null.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowNull()][AllowEmptyString()][string]$SchemaUrl, [switch]$Given)
    $name = '-SchemaUrl'
    if (-not $Given) {
        $SchemaUrl = [Environment]::GetEnvironmentVariable($Script:SchemaUrlDefaultVariable)
        if ([string]::IsNullOrWhiteSpace($SchemaUrl)) { return $null }
        $name = $Script:SchemaUrlDefaultVariable
    }
    if ($SchemaUrl -eq '') { return '' }
    if ($SchemaUrl.Length -gt $Script:MaxSchemaUrlLength -or $SchemaUrl -match '\p{Cc}' -or $SchemaUrl -cnotmatch $Script:SchemaUrlPattern) {
        $shown = if ($SchemaUrl.Length -gt 100) { $SchemaUrl.Substring(0, 100) + '...' } else { $SchemaUrl }
        throw ('{0} "{1}": expected an https address, a path such as {2}, or an empty string (no spaces, at most {3} characters).' -f $name, ($shown -replace '\p{Cc}', ' '), $Script:SchemaUrlExample, $Script:MaxSchemaUrlLength)
    }
    $SchemaUrl
}
