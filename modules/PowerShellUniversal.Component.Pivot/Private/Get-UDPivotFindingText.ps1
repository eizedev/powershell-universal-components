function Get-UDPivotFindingText {
    <#
    .SYNOPSIS
        pivotkit's findings as lines: "error unknownField at rows[0]: unknown field "Regoin" (did you mean Region?)".
    .PARAMETER Finding
        The findings of a --json answer or a problem document.
    .EXAMPLE
        Get-UDPivotFindingText -Finding $answer.findings
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowNull()][object[]]$Finding)
    foreach ($f in @($Finding | Where-Object { $_ })) {
        $text = '{0} {1}' -f $f.severity, $f.code
        if ($f.path) { $text += ' at {0}' -f $f.path }
        $text += ': {0}' -f $f.message
        if ($f.suggestion) { $text += ' (did you mean {0}?)' -f $f.suggestion }
        $text
    }
}
