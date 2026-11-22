function Invoke-UDPivotNodeReport {
    <#
    .SYNOPSIS
        Renders a report with pivotkit's command line (Invoke-UDPivotReport -Engine Node) and returns the
        file's bytes.
    .DESCRIPTION
        The rows, the view and the report go into a folder of its own that only this user may read (the
        rows are the app's data); it is removed afterwards, also when the command line fails.
    .PARAMETER Bound
        Invoke-UDPivotReport's $PSBoundParameters: Data, CliPath and the render options.
    .PARAMETER Report
        The result of Get-UDPivotReportInput.
    .PARAMETER Output
        The result of Resolve-UDPivotReportOutput.
    .PARAMETER TimeoutSec
        How long the command line may take.
    .EXAMPLE
        $bytes = Invoke-UDPivotNodeReport -Bound $PSBoundParameters -Report $report -Output $output -TimeoutSec 120
    .OUTPUTS
        System.Byte[]
    #>
    [CmdletBinding()]
    [OutputType([byte[]])]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Bound,
        [Parameter(Mandatory)][pscustomobject]$Report,
        [Parameter(Mandatory)][pscustomobject]$Output,
        [Parameter(Mandatory)][int]$TimeoutSec
    )
    $command = Get-UDPivotCliCommand -CliPath ([string]$Bound['CliPath'])
    $work = Join-Path ([System.IO.Path]::GetTempPath()) ('pivotkit-' + [guid]::NewGuid().ToString('N'))
    if ($IsWindows) { [void][System.IO.Directory]::CreateDirectory($work) }
    else { [void][System.IO.Directory]::CreateDirectory($work, [System.IO.UnixFileMode]'UserRead, UserWrite, UserExecute') }
    try {
        Write-UDPivotDataFile -Path (Join-Path $work 'data.json') -Data $Bound['Data']
        $arguments = Get-UDPivotCliArgument -Work $work -Report $Report -Output $Output -Bound $Bound
        $answer = Invoke-UDPivotCli -Command $command -Argument $arguments -TimeoutSec $TimeoutSec
        $outPath = Join-Path $work ('report.{0}' -f $Output.Kind)
        Assert-UDPivotCliAnswer -Answer $answer -OutPath $outPath
        , [System.IO.File]::ReadAllBytes($outPath)
    }
    finally {
        # a file the command line still holds open (Windows) must not hide the report's own error
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}
