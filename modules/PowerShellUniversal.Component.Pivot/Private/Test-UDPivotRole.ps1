function Test-UDPivotRole {
    <#
    .SYNOPSIS
        True when one of -Roles is one of -AdminRole (case-insensitive).
    .PARAMETER Roles
        The user's roles ($Roles of PSU).
    .PARAMETER AdminRole
        The roles that may change shared views.
    .EXAMPLE
        Test-UDPivotRole -Roles $Roles -AdminRole 'Administrator'
    .OUTPUTS
        System.Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([AllowNull()][AllowEmptyCollection()][string[]]$Roles, [AllowNull()][AllowEmptyCollection()][string[]]$AdminRole)
    foreach ($role in @($Roles)) {
        if (-not [string]::IsNullOrWhiteSpace($role) -and (@($AdminRole) | Where-Object { $_ -and $_ -eq $role.Trim() })) { return $true }
    }
    $false
}
