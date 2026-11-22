function Reset-UDPivotErrorVariable {
    <#
    .SYNOPSIS
        Cuts the caller's -ErrorVariable back to the mark Get-UDPivotErrorMark took.
    .DESCRIPTION
        Called in a public function's trap, right before it throws the error again: the variable then
        holds what the caller had, followed by the error itself. Never throws.
    .PARAMETER Mark
        The result of Get-UDPivotErrorMark; nothing when the caller gave no -ErrorVariable.
    .EXAMPLE
        trap { Reset-UDPivotErrorVariable -Mark $errorMark; throw $_ }
    #>
    # Changes only the caller's list of errors, which the caller asked for with -ErrorVariable
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param([AllowNull()][object]$Mark)
    if (-not $Mark) { return }
    while ($Mark.List.Count -gt $Mark.Count) { $Mark.List.RemoveAt($Mark.List.Count - 1) }
}
