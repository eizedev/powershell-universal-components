function Get-UDPivotLayoutArgument {
    <#
    .SYNOPSIS
        A layout as the layout flags of pivotkit's command line (--rows, --cols, --values, --group,
        --filter, --chart-type, --map).
    .DESCRIPTION
        Each value is one argument of its own, written as --option=value, so a field name may hold commas,
        spaces and colons and may start with a dash ("--rows -x" would read -x as an option).
    .PARAMETER Layout
        The layout of ConvertTo-UDPivotReportLayout.
    .EXAMPLE
        Get-UDPivotLayoutArgument -Layout ([ordered]@{ rows = @('Team'); values = @(@{ field = 'Hours'; agg = 'sum' }) })
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Layout)
    $get = { param($Item, $Key) if ($Item -is [System.Collections.IDictionary]) { $Item[$Key] } else { $Item.$Key } }
    foreach ($field in @($Layout['rows'])) { if ($field) { '--rows=' + $field } }
    foreach ($field in @($Layout['cols'])) { if ($field) { '--cols=' + $field } }
    foreach ($v in @($Layout['values'])) {
        if (-not $v) { continue }
        $field = [string](& $get $v 'field')
        $agg = [string](& $get $v 'agg')
        '--values=' + $(if ($agg -and $field) { '{0}:{1}' -f $agg, $field } elseif ($field) { $field } else { $agg })
    }
    foreach ($g in @($Layout['groups'])) {
        if (-not $g) { continue }
        $size = & $get $g 'size'
        $text = if ($null -ne $size) { [string]::Format([cultureinfo]::InvariantCulture, '{0}:{1}:{2}', (& $get $g 'field'), (& $get $g 'by'), $size) } else { '{0}:{1}' -f (& $get $g 'field'), (& $get $g 'by') }
        '--group=' + $text
    }
    foreach ($f in @($Layout['filters'])) { if ($f) { '--filter=' + (ConvertTo-Json -InputObject $f -Depth 8 -Compress) } }
    if ($Layout['chart']) { '--chart-type=' + $Layout['chart'] }
    if ($Layout['map']) { foreach ($k in $Layout['map'].Keys) { '--map={0}={1}' -f $k, $Layout['map'][$k] } }
}
