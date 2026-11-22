function Get-UDPivotTableWriter {
    <#
    .SYNOPSIS
        The compiled row writer of Write-UDPivotReportTable, compiled on first use; $null when Add-Type
        is not available.
    .EXAMPLE
        $type = Get-UDPivotTableWriter
    .OUTPUTS
        System.Type, or $null.
    #>
    [CmdletBinding()]
    [OutputType([type])]
    param()
    if ($false -eq $Script:ReportWriterCompiled) { return $null }
    $type = $Script:ReportWriterType -as [type]
    if (-not $type) {
        try {
            $references = @('System.Text.Json', 'System.Data.Common', 'System.Collections', 'System.Runtime', 'System.Memory', 'System.ComponentModel.Primitives', 'System.Text.Encodings.Web', ([psobject].Assembly.Location))
            Add-Type -TypeDefinition $Script:ReportWriterSource -ReferencedAssemblies $references -ErrorAction Stop
            $type = $Script:ReportWriterType -as [type]
        }
        catch {
            # another runspace of the process may have compiled the same type a moment before: use it
            $type = $Script:ReportWriterType -as [type]
            if (-not $type) { Write-Verbose ('Invoke-UDPivotReport: no compiled row writer ({0}); PowerShell writes the rows.' -f $_.Exception.Message) }
        }
    }
    $Script:ReportWriterCompiled = $null -ne $type
    $type
}
