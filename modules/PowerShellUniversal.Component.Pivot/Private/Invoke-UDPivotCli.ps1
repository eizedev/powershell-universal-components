function Invoke-UDPivotCli {
    <#
    .SYNOPSIS
        Runs pivotkit's command line with an argument list and returns its --json answer.
    .DESCRIPTION
        Every argument is passed as one (ProcessStartInfo.ArgumentList, no shell, no quoting). stdout is
        read as the JSON object of --json; a run longer than -TimeoutSec is stopped.
    .PARAMETER Command
        Get-UDPivotCliCommand's result.
    .PARAMETER Argument
        pivotkit's arguments.
    .PARAMETER TimeoutSec
        The longest run.
    .EXAMPLE
        Invoke-UDPivotCli -Command (Get-UDPivotCliCommand) -Argument 'render', 'view.json', '--data', 'data.json', '-o', 'out.xlsx', '--json'
    .OUTPUTS
        System.Management.Automation.PSCustomObject (pivotkit's --json object).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][pscustomobject]$Command,
        [Parameter(Mandatory)][string[]]$Argument,
        [ValidateRange(1, 3600)][int]$TimeoutSec = $Script:ReportTimeoutSec
    )
    $info = [System.Diagnostics.ProcessStartInfo]::new($Command.FileName)
    foreach ($a in @($Command.Arguments) + $Argument) { $info.ArgumentList.Add($a) }
    $info.UseShellExecute = $false
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.RedirectStandardInput = $true
    $info.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $info.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $info
    try {
        try { [void]$process.Start() }
        catch { throw (New-UDPivotError -Id PivotCliFailed -Category OpenError -Message ('pivotkit''s command line did not start ({0}): {1}' -f $Command.FileName, $_.Exception.Message)) }
        $process.StandardInput.Close()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSec * 1000)) {
            $process.Kill($true)
            throw (New-UDPivotError -Id PivotCliFailed -Category OperationTimeout -Message ('pivotkit''s command line took longer than {0} seconds and was stopped.' -f $TimeoutSec))
        }
        $process.WaitForExit()
        $text = $stdout.GetAwaiter().GetResult()
        $errText = $stderr.GetAwaiter().GetResult()
        try { $answer = ConvertFrom-Json -InputObject $text -Depth 32 }
        catch { $answer = $null }
        if ($null -eq $answer -or $null -eq $answer.PSObject.Properties['ok']) {
            $line = ($errText -split "`n" | Where-Object { $_.Trim() } | Select-Object -First 1)
            throw (New-UDPivotError -Id PivotCliFailed -Category InvalidResult -Message ('pivotkit''s command line (exit {0}) gave no --json answer: {1} (pivotkit-cli 0.2.1 or later is needed).' -f $process.ExitCode, $(if ($line) { $line.Trim() } else { 'no output' })))
        }
        $answer | Add-Member -NotePropertyName exitCode -NotePropertyValue $process.ExitCode -Force
        $answer
    }
    finally {
        $process.Dispose()
    }
}
