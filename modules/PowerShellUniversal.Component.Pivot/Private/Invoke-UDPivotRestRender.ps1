function Invoke-UDPivotRestRender {
    <#
    .SYNOPSIS
        POSTs a render to pivotkit-server's file route and returns the file's bytes.
    .DESCRIPTION
        POST <Uri>/views/render/file with the input as JSON (Invoke-UDPivotRestCall: the sign-in, no
        redirects, the server's errors as New-UDPivotServerError makes them).
    .PARAMETER Uri
        The REST service's address, https://host/api/v1.
    .PARAMETER Body
        The input of render_view as UTF-8 JSON (New-UDPivotRenderBody).
    .PARAMETER Auth
        @{ Token } or @{ Credential; TokenUri; Scope; Audience; Resource; ClientAuthentication }.
    .PARAMETER TimeoutSec
        The longest wait for the answer.
    .EXAMPLE
        Invoke-UDPivotRestRender -Uri 'https://reports.example.com/api/v1' -Body $json -Auth @{ Token = $Secret:PivotkitToken }
    .OUTPUTS
        System.Byte[]
    #>
    [CmdletBinding()]
    [OutputType([byte[]])]
    param(
        [Parameter(Mandatory)][uri]$Uri,
        [Parameter(Mandatory)][byte[]]$Body,
        [Parameter(Mandatory)][hashtable]$Auth,
        [ValidateRange(1, 3600)][int]$TimeoutSec = $Script:ReportTimeoutSec
    )
    , (Invoke-UDPivotRestCall -Uri $Uri -Route '/views/render/file' -Body $Body -Auth $Auth -TimeoutSec $TimeoutSec).Content
}
