function Get-UDPivotCliArgument {
    <#
    .SYNOPSIS
        The arguments of pivotkit's command line for one report, and the files they name in the work
        folder: the view file (or the layout's options), the format and output, the render options and a
        copy of the print template.
    .DESCRIPTION
        Every value goes as --option=value: a value may start with a dash. The command line reads only
        inside the work folder (--allow-dir), so the template is copied there.
    .PARAMETER Work
        The work folder, with data.json in it.
    .PARAMETER Report
        The result of Get-UDPivotReportInput.
    .PARAMETER Output
        The result of Resolve-UDPivotReportOutput.
    .PARAMETER Bound
        Invoke-UDPivotReport's $PSBoundParameters: Locale, TimeZone, Numbers and FlatHeader.
    .EXAMPLE
        $arguments = Get-UDPivotCliArgument -Work $work -Report $report -Output $output -Bound $PSBoundParameters
    .OUTPUTS
        System.String[]
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)][string]$Work,
        [Parameter(Mandatory)][pscustomobject]$Report,
        [Parameter(Mandatory)][pscustomobject]$Output,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Bound
    )
    $dataPath = Join-Path $Work 'data.json'
    $arguments = [System.Collections.Generic.List[string]]::new()
    $arguments.Add('render')
    $viewFile = $Report.ViewFile
    if ($viewFile) {
        $viewPath = Join-Path $Work 'view.pivotkit.json'
        $viewJson = ConvertTo-UDPivotViewFile -View $viewFile.View -Name $viewFile.Name -SourceId ([string]$viewFile.Source.id)
        [System.IO.File]::WriteAllText($viewPath, $viewJson, [System.Text.UTF8Encoding]::new($false))
        $arguments.AddRange([string[]]@($viewPath, ('--data=' + $dataPath)))
    }
    else {
        $arguments.Add($dataPath)
        $arguments.AddRange([string[]]@(Get-UDPivotLayoutArgument -Layout $Report.Layout))
    }
    $arguments.AddRange([string[]]@(('--format=' + $Output.Kind), ('--output=' + (Join-Path $Work ('report.{0}' -f $Output.Kind))), '--json', '--quiet', ('--allow-dir=' + $Work)))
    if ($Report.Title) { $arguments.Add('--title=' + $Report.Title) }
    if ($Bound['Locale']) { $arguments.Add('--locale=' + $Bound['Locale']) }
    if ($Bound['TimeZone']) { $arguments.Add('--time-zone=' + $Bound['TimeZone']) }
    if ($Bound['Numbers']) { $arguments.Add('--numbers=' + ([string]$Bound['Numbers']).ToLowerInvariant()) }
    if ($Bound['FlatHeader']) { $arguments.Add('--flat-header') }
    if ($Output.TemplatePath) {
        $templateCopy = Join-Path $Work 'print.template.html'
        Copy-Item -LiteralPath $Output.TemplatePath -Destination $templateCopy
        $arguments.Add('--template=' + $templateCopy)
    }
    , $arguments.ToArray()
}
