function Get-UDPivotErrorMark {
    <#
    .SYNOPSIS
        Where the caller's -ErrorVariable stands when a public function starts, so
        Reset-UDPivotErrorVariable can take the module's own steps out of it again.
    .DESCRIPTION
        PowerShell adds every error that passes a statement of the function to the caller's
        -ErrorVariable: an error thrown three calls deep arrives there five times or more, mixed with
        the .NET exception it came from. Each public function marks the list when it starts and, in its
        trap, cuts the list back to the mark before it throws the error again; the throw then adds that
        one record. Entries the caller had before (-ErrorVariable +name) stay.
    .PARAMETER Cmdlet
        The public function's $PSCmdlet. Its SessionState finds the variable in the caller's scope.
    .EXAMPLE
        $errorMark = Get-UDPivotErrorMark -Cmdlet $PSCmdlet
        trap { Reset-UDPivotErrorVariable -Mark $errorMark; throw $_ }
    .OUTPUTS
        PSCustomObject with List and Count, or nothing without -ErrorVariable.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)][System.Management.Automation.PSCmdlet]$Cmdlet)
    $name = [string]$Cmdlet.MyInvocation.BoundParameters['ErrorVariable']
    if (-not $name) { return }
    $variable = $Cmdlet.SessionState.PSVariable.Get($name.TrimStart('+'))
    if ($variable -and $variable.Value -is [System.Collections.IList] -and -not $variable.Value.IsFixedSize) {
        [pscustomobject]@{ List = $variable.Value; Count = $variable.Value.Count }
    }
}
