function Get-UDPivotStoreRequest {
    <#
    .SYNOPSIS
        The request a custom store's Save, Publish or Delete gets for one file: the context's request
        with FileName and the Key (users/<user key>/<file> or shared/<file>).
    .PARAMETER Context
        The result of New-UDPivotStoreContext.
    .PARAMETER FileName
        The view's file name.
    .EXAMPLE
        $request = Get-UDPivotStoreRequest -Context $context -FileName 'sales.pivotkit.json'
    .OUTPUTS
        System.Collections.Specialized.OrderedDictionary
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param([Parameter(Mandatory)][pscustomobject]$Context, [Parameter(Mandatory)][string]$FileName)
    $out = [ordered]@{}
    foreach ($k in $Context.Request.Keys) { $out[$k] = $Context.Request[$k] }
    $out['FileName'] = $FileName
    $out['Key'] = if ($Context.Scope -eq 'user') { 'users/{0}/{1}' -f $Context.UserKey, $FileName } else { 'shared/{0}' -f $FileName }
    $out
}
