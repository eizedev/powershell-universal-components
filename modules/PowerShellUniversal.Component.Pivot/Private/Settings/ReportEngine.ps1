# Reports without a browser: Invoke-UDPivotReport, Get-UDPivotSource.
# the formats of pivotkit's render (pivotkit-cli render -f, pivotkit-server render_view format) and the
# file name extensions that name one (.htm is html, as in the command line)
$Script:ReportFormats = @('xlsx', 'html', 'csv', 'json', 'svg')
$Script:ReportExtensions = @{ '.xlsx' = 'xlsx'; '.html' = 'html'; '.htm' = 'html'; '.csv' = 'csv'; '.json' = 'json'; '.svg' = 'svg' }
# the keys of a layout (pivotkit-core's viewFromLayout input; RenderViewInput.layout of the REST service)
$Script:LayoutKeys = @('rows', 'cols', 'values', 'groups', 'filters', 'chart', 'map')
# pivotkit-core's CHART_TYPES: the chart a layout may ask for
$Script:ChartTypes = @('auto', 'bar', 'line', 'area', 'pie', 'donut', 'heatmap', 'combo', 'treemap')
$Script:ReportTimeoutSec = 120
# what pivotkit's command line needs, for the errors when it or node is missing (the help of
# Invoke-UDPivotReport names the same, tests/powershell/PivotOutput.Tests.ps1)
$Script:CliNodeRequirement = 'Node 24 or later; Node 22 for pivotkit-cli 0.4 and older'
# the rows of a server source (New-UDPivotReport -Uri -Source): the most bytes of the answer the module
# reads and hands to the page. pivotkit-server's default limits (50,000 rows, 1,000,000 values) answer
# about 4 MiB for 8 columns; PSU passed a text prop of 64 MiB to the browser (measured on 2026.2.5 and
# 2026.3.4), but each copy costs PSU's memory (docs/pivot/reports.md, sizing)
$Script:RecordsMaxBytes = 32MB
# the largest -MaxBytes: what PSU passed to the browser in the measurement above
$Script:RecordsMaxBytesLimit = 64MB
# an error answer of the rows route is read up to this many bytes (a problem document is far smaller)
$Script:ErrorBodyMaxBytes = 1MB
# the name of a view the server publishes for a source (pivotkit-server's named views)
$Script:ViewNamePattern = '^[A-Za-z0-9_-]{1,80}$'
# a request body above this gets a warning: pivotkit-server's default rest.data.maxBytes
$Script:ReportDataWarnBytes = 10MB
# ReportWriter.cs writes rows into JSON without a PowerShell statement per cell: in PowerShell 100,000
# rows x 3 columns allocated about 2 GB on the way and took the managed heap of the process up by about
# 750 MB before the garbage collector caught up (measured 2026-11-15, PowerShell 7.6 on macOS; the
# live test on PSU 2026.2.5 saw about 700 MB). Compiled once per process when a table of at least
# $Script:ReportWriterMinRows rows arrives, as ConvertTo-PSUComponentData does; where Add-Type fails,
# PowerShell writes the rows with the same result. The module needs full language mode (it does not load
# in constrained language mode, and the JSON writer is a .NET type that mode blocks).
$writer = Get-PSUComponentTypeSource -Path (Join-Path $PSScriptRoot '..' 'ReportWriter.cs') -TypeName 'PivotReportTable.Writer'
$Script:ReportWriterSource = $writer.Source
$Script:ReportWriterType = $writer.Type
$Script:ReportWriterMinRows = 1000
$Script:LastTableWriter = $null
# $true: compiled, $false: not available (or switched off by a test), $null: not tried yet
$Script:ReportWriterCompiled = $null
# a token taken from the cache has at least this much time left, so it does not expire on the way
$Script:TokenSkewSec = 60
# OAuth access tokens per token endpoint, client and scope, for this runspace: @{ Token; Expires }
$Script:TokenCache = @{}
# The connection under every request of the REST engine reads the server's answer while the body is
# still being sent. pivotkit-server answers a body over its cap with 413 at once and resets the
# connection while the client still sends (measured with pivotkit c390784b on 2026-11-15: the answer
# after about 600 KB, the reset a few milliseconds later). HttpClient (and Invoke-WebRequest) reads the
# answer only once the body is sent: on a plain connection the write fails with "Error while copying
# content to a stream" and the 413 is lost, also with Expect: 100-continue (node:http sends 100 Continue
# before the answer).
# The stream in HttpTransport.cs keeps reading the socket in the background and, when a write fails
# after bytes of an answer arrived, drops the rest of the body, so HttpClient reads that answer. It sits
# below TLS and a proxy's tunnel, so both work as before. Compiled on first use; where Add-Type fails,
# the requests go through a plain handler and an early answer is lost. Neither is meant for constrained language mode:
# the module needs full language mode (see the row writer above; it does not load in constrained
# language mode), and the REST engine builds HttpClient objects either way.
$transport = Get-PSUComponentTypeSource -Path (Join-Path $PSScriptRoot '..' 'HttpTransport.cs') -TypeName 'PivotReportHttp.Transport'
$Script:HttpTransportSource = $transport.Source
$Script:HttpTransportType = $transport.Type
Remove-Variable -Name writer, transport
# $true: compiled, $false: not available (or switched off by a test), $null: not tried yet
$Script:HttpTransportCompiled = $null
