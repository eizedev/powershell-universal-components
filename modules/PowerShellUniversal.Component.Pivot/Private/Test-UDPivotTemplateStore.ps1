function Test-UDPivotTemplateStore {
    <#
    .SYNOPSIS
        True for a store of New-UDPivotFileTemplateStore or New-UDPivotTemplateStore.
    .PARAMETER Store
        The value of -TemplateStore.
    .EXAMPLE
        Test-UDPivotTemplateStore -Store $store
    .OUTPUTS
        System.Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([AllowNull()][object]$Store)
    $Store -is [System.Management.Automation.PSCustomObject] -and $Store.PSObject.TypeNames -contains 'UDPivotTemplateStore' -and $Store.Kind -in 'File', 'Custom'
}
