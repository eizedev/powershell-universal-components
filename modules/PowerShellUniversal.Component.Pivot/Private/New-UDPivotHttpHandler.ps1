function New-UDPivotHttpHandler {
    <#
    .SYNOPSIS
        The HTTP handler of the REST engine: no redirects, no cookies, and connections that keep an answer
        the server sends while the body is still being sent.
    .DESCRIPTION
        Compiles $Script:HttpTransportSource on first use. Where Add-Type is not available, a plain
        SocketsHttpHandler with the same settings: requests work, but an early answer (pivotkit-server's
        413 for a body over its cap) is lost and the request fails as unreachable.
    .EXAMPLE
        $client = [System.Net.Http.HttpClient]::new((New-UDPivotHttpHandler), $true)
    .OUTPUTS
        System.Net.Http.SocketsHttpHandler
    #>
    # Builds a handler in memory; changes no state, so no ShouldProcess
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType([System.Net.Http.SocketsHttpHandler])]
    param()
    $type = $null
    if ($false -ne $Script:HttpTransportCompiled) {
        $type = $Script:HttpTransportType -as [type]
        if (-not $type) {
            try {
                $references = @('System.Net.Http', 'System.Net.Sockets', 'System.Net.Primitives', 'System.Threading.Channels', 'System.Runtime', 'System.Memory', 'System.Threading', 'System.Collections.Concurrent')
                Add-Type -TypeDefinition $Script:HttpTransportSource -ReferencedAssemblies $references -ErrorAction Stop
                $type = $Script:HttpTransportType -as [type]
            }
            catch {
                # another runspace of the process may have compiled the same type a moment before: use it
                $type = $Script:HttpTransportType -as [type]
                if (-not $type) { Write-Verbose ('Invoke-UDPivotReport: no compiled HTTP transport ({0}); an answer the server sends before the body is sent is lost.' -f $_.Exception.Message) }
            }
        }
        $Script:HttpTransportCompiled = $null -ne $type
    }
    if ($type) { return $type::NewHandler() }
    $handler = [System.Net.Http.SocketsHttpHandler]::new()
    $handler.AllowAutoRedirect = $false
    $handler.UseCookies = $false
    $handler.AutomaticDecompression = [System.Net.DecompressionMethods]::All
    $handler
}
