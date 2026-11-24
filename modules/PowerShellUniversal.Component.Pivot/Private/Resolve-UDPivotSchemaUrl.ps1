function Resolve-UDPivotSchemaUrl {
    <#
    .SYNOPSIS
        The $schema a writer on the server puts into a view file: a path on the instance with an origin
        in front, anything else as it is.
    .DESCRIPTION
        A path takes the origin of PSU_COMPONENT_PIVOT_SCHEMA_URL when that is an https address: the
        address the platform names, also behind a proxy. Otherwise it takes the origin of the request
        (Get-UDPivotRequestOrigin). With neither (a scheduled job) it stops: a $schema without an
        origin names no file anywhere. With -WithoutRequest the request's headers are never read: a path
        without an https default gives pivotkit's address of the current format.
    .PARAMETER SchemaUrl
        A value of Get-UDPivotSchemaUrl.
    .PARAMETER Headers
        $Headers of the request, or $null.
    .PARAMETER WithoutRequest
        Read no header: for a file others read (a shared view), whose $schema no request may choose.
    .EXAMPLE
        Resolve-UDPivotSchemaUrl -SchemaUrl '/assets/pivot/schema/view-file-2.json' -Headers $Headers
    .OUTPUTS
        System.String, or $null.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowNull()][AllowEmptyString()][string]$SchemaUrl, [AllowNull()][object]$Headers, [switch]$WithoutRequest)
    if (-not $SchemaUrl -or -not $SchemaUrl.StartsWith('/')) { return $SchemaUrl }
    $origin = $null
    $default = Get-UDPivotSchemaUrl
    if ($default -and -not $default.StartsWith('/')) { $origin = ([uri]$default).GetLeftPart([System.UriPartial]::Authority) }
    if (-not $origin -and $WithoutRequest) { return $Script:ViewFileSchemaUrls[$Script:KnownViewVersion] }
    if (-not $origin) { $origin = Get-UDPivotRequestOrigin -Headers $Headers }
    if (-not $origin) {
        throw ('-SchemaUrl "{0}": a path needs the address of a request, and there is none here. Set {1} to an https address, or pass -SchemaUrl as one.' -f $SchemaUrl, $Script:SchemaUrlDefaultVariable)
    }
    $origin + $SchemaUrl
}
