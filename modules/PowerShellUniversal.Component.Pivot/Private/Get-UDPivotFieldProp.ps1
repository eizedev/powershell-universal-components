function Get-UDPivotFieldProp {
    <#
    .SYNOPSIS
        The props of New-UDPivotReport that describe the fields and the chart: field defaults and
        descriptions, a schema and the chart options, each as JSON text.
    .PARAMETER Bound
        New-UDPivotReport's $PSBoundParameters.
    .EXAMPLE
        $props += Get-UDPivotFieldProp -Bound $PSBoundParameters
    .OUTPUTS
        System.Collections.Hashtable: the props to add.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Bound)
    $props = @{}
    if ($Bound['FieldDefaults'] -or $Bound['FieldDescriptions']) {
        $defaults = ConvertTo-UDPivotFieldDefault -FieldDefaults $Bound['FieldDefaults'] -FieldDescriptions $Bound['FieldDescriptions']
        # as JSON text: PSU would camelCase the field names of an object prop
        if ($defaults.Count) {
            $props['fieldDefaults'] = ConvertTo-UDPivotJsonText -InputObject $defaults -Name '-FieldDefaults' -MaxLength $Script:MaxSchemaLength -MaxDepth 4
        }
    }
    if ($Bound.ContainsKey('Schema') -and $null -ne $Bound['Schema']) {
        $props['schema'] = Get-UDPivotSchemaText -Schema $Bound['Schema']
        if ($Bound['SchemaName']) { $props['schemaName'] = $Bound['SchemaName'] }
    }
    elseif ($Bound['SchemaName']) { throw '-SchemaName needs -Schema.' }
    if ($Bound.ContainsKey('ChartOptions') -and $null -ne $Bound['ChartOptions']) {
        $props['chartOptions'] = ConvertTo-UDPivotJsonText -InputObject $Bound['ChartOptions'] -Name '-ChartOptions' -MaxLength $Script:MaxChartOptionsLength -MaxDepth $Script:MaxChartOptionsDepth
    }
    $props
}
