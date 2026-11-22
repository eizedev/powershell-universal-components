function Get-UDPivotDisplayProp {
    <#
    .SYNOPSIS
        The props of New-UDPivotReport for how the report looks: tips, info buttons, panels, label,
        height, texts, class and style.
    .PARAMETER Bound
        New-UDPivotReport's $PSBoundParameters.
    .EXAMPLE
        $props += Get-UDPivotDisplayProp -Bound $PSBoundParameters
    .OUTPUTS
        System.Collections.Hashtable: the props to add.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Bound)
    $props = @{}
    $tips = $Bound['Tips']
    if ($tips) {
        if ($tips.Count -gt 1 -and ($tips -contains 'On' -or $tips -contains 'Off')) { throw '-Tips: On or Off alone, or a list of tip ids.' }
        # each id in pivotkit's spelling, whatever case it was given in
        $props['tips'] = if ($tips.Count -eq 1 -and $tips[0] -in 'On', 'Off') { $tips[0].ToLowerInvariant() } else { @(foreach ($tip in $tips) { $Script:TipIds | Where-Object { $_ -eq $tip } }) }
    }
    # On/Off and Open/Collapsed/Folded switches, in lower case as pivotkit-react takes them
    foreach ($name in 'FieldInfo', 'ZoneInfo', 'SettingInfo', 'FieldList', 'Zones', 'Grow') {
        if ($Bound[$name]) { $props[$name.Substring(0, 1).ToLowerInvariant() + $name.Substring(1)] = ([string]$Bound[$name]).ToLowerInvariant() }
    }
    if ($Bound['Label']) { $props['label'] = $Bound['Label'] }
    if ($Bound['Height']) { $props['height'] = ConvertTo-UDPivotHeight -Height $Bound['Height'] }
    foreach ($name in 'Labels', 'ClassName', 'Style') {
        if ($Bound[$name]) { $props[$name.Substring(0, 1).ToLowerInvariant() + $name.Substring(1)] = $Bound[$name] }
    }
    $props
}
