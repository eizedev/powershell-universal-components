function Resolve-UDPivotReportOutput {
    <#
    .SYNOPSIS
        Where Invoke-UDPivotReport writes and in which format: -OutFile as a full path, the format from
        -Format or the file's extension (xlsx without either), and the print template, each checked
        against the format.
    .PARAMETER Bound
        Invoke-UDPivotReport's $PSBoundParameters: OutFile, Format, Numbers, FlatHeader and Template.
    .PARAMETER Cmdlet
        Invoke-UDPivotReport's $PSCmdlet, which resolves paths against the caller's location.
    .EXAMPLE
        $output = Resolve-UDPivotReportOutput -Bound $PSBoundParameters -Cmdlet $PSCmdlet
    .OUTPUTS
        PSCustomObject with Target (or $null), Kind and TemplatePath (or $null).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Bound, [Parameter(Mandatory)][System.Management.Automation.PSCmdlet]$Cmdlet)
    $format = [string]$Bound['Format']
    $target = if ($Bound['OutFile']) { $Cmdlet.GetUnresolvedProviderPathFromPSPath($Bound['OutFile']) }
    $named = if ($target) { $Script:ReportExtensions[[System.IO.Path]::GetExtension($target).ToLowerInvariant()] }
    if ($format -and $named -and $named -ne $format) { throw ('-OutFile names a {0} file, -Format {1}: give one or make them agree.' -f $named, $format) }
    $kind = if ($format) { $format } elseif ($named) { $named } else { 'xlsx' }
    # pivotkit-cli's render options and the formats they work in (its option table: numbers csv, json;
    # flat-header csv); the command line only warns about one that does nothing, so refuse it here
    if ($Bound['Numbers'] -and $kind -notin 'csv', 'json') { throw ('-Numbers goes with -Format csv or json, not {0}.' -f $kind) }
    if ($Bound['FlatHeader'] -and $kind -ne 'csv') { throw ('-FlatHeader goes with -Format csv, not {0}.' -f $kind) }
    $templatePath = $null
    if ($Bound['Template']) {
        if ($kind -ne 'html') { throw ('-Template goes with -Format html (a print template for the HTML report), not {0}.' -f $kind) }
        $templatePath = $Cmdlet.GetUnresolvedProviderPathFromPSPath($Bound['Template'])
        if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) { throw ('-Template "{0}": no such file.' -f $Bound['Template']) }
    }
    [pscustomobject]@{ Target = $target; Kind = $kind; TemplatePath = $templatePath }
}
