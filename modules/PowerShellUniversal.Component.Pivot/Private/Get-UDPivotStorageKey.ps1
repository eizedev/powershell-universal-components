function Get-UDPivotStorageKey {
    <#
    .SYNOPSIS
        The key the browser keeps the reader's view under when New-UDPivotReport has no -Id: the place
        of the call in the app script and the columns, hashed (no server path reaches the browser).
    .PARAMETER Invocation
        New-UDPivotReport's $MyInvocation: script, line and column of the call.
    .PARAMETER ColumnName
        The names of the report's columns.
    .EXAMPLE
        Get-UDPivotStorageKey -Invocation $MyInvocation -ColumnName 'Team', 'Hours'
    .OUTPUTS
        System.String: auto- and 16 hex digits.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][System.Management.Automation.InvocationInfo]$Invocation,
        [AllowEmptyCollection()][string[]]$ColumnName
    )
    $site = '{0}|{1}|{2}|{3}' -f $Invocation.ScriptName, $Invocation.ScriptLineNumber, $Invocation.OffsetInLine, ($ColumnName -join [char]1)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $hash = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($site)) } finally { $sha.Dispose() }
    'auto-' + (-join ($hash[0..7] | ForEach-Object { $_.ToString('x2') }))
}
