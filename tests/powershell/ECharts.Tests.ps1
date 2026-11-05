#Requires -Version 7.4
# Pester tests for PowerShellUniversal.Component.ECharts outside PSU: PSU's [Endpoint] type and
# Set-UDElement are replaced by stubs, the asset id is set by hand.

BeforeAll {
    if (-not ('Endpoint' -as [type])) {
        Add-Type -TypeDefinition @'
public class Endpoint {
    public System.Management.Automation.ScriptBlock ScriptBlock;
    public string RegisteredId;
    public Endpoint(System.Management.Automation.ScriptBlock scriptBlock) { ScriptBlock = scriptBlock; }
    public void Register(string id, object cmdlet) { RegisteredId = id; }
}
'@
    }
    $script:repo = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
    $script:module = Import-Module (Join-Path $script:repo 'modules' 'PowerShellUniversal.Component.ECharts' 'PowerShellUniversal.Component.ECharts.psm1') -Force -PassThru
    & $script:module { $Script:AssetId = 'asset-under-test' }
}

Describe 'New-UDEChart' {
    It 'returns the plugin hashtable for ud-echart' {
        $c = New-UDEChart -Id 'c1' -Data @([pscustomobject]@{ A = 1 }) -Type bar -X A
        $c.type | Should -Be 'ud-echart'
        $c.isPlugin | Should -BeTrue
        $c.assetId | Should -Be 'asset-under-test'
        $c.id | Should -Be 'c1'
        $c.chartType | Should -Be 'bar'
        $c.x | Should -Be 'A'
    }
    It 'sends only the parameters that were given' {
        $c = New-UDEChart -Data @() -Type line
        $c.ContainsKey('x') | Should -BeFalse
        $c.ContainsKey('dataLabels') | Should -BeFalse
        $c.ContainsKey('legend') | Should -BeFalse
        (New-UDEChart -Data @() -DataLabels:$false).dataLabels | Should -BeFalse
        (New-UDEChart -Data @() -Legend Top).legend | Should -Be 'top'
    }
    It 'converts a DataTable with DBNull and dates' {
        $t = [System.Data.DataTable]::new()
        [void]$t.Columns.Add('Name'); [void]$t.Columns.Add('When', [datetime]); [void]$t.Columns.Add('V', [int])
        [void]$t.Rows.Add('a', [datetime]'2026-01-02T03:04:05', [DBNull]::Value)
        $c = New-UDEChart -Data $t -X Name -Y V
        $c.data.Count | Should -Be 1
        $c.data[0].When | Should -Be '2026-01-02T03:04:05.0000000'
        $null -eq $c.data[0].V | Should -BeTrue
    }
    It 'registers endpoints under the chart id' {
        $c = New-UDEChart -Id 'clicky' -Data @() -OnClick { 'x' } -OnSelect { 'y' }
        $c.onClick.RegisteredId | Should -Be 'clicky'
        $c.onSelect.RegisteredId | Should -Be 'clicky'
        $c.ContainsKey('onZoom') | Should -BeFalse
    }
    It 'rejects formats that are not a known name' {
        { New-UDEChart -Data @() -Format 'number;alert(1)' } | Should -Throw
        { New-UDEChart -Data @() -Format 'currency:EUR' } | Should -Not -Throw
    }
    It 'rejects unknown chart types' {
        { New-UDEChart -Data @() -Type 'nope' } | Should -Throw
    }
    It 'knows the same chart types as the browser side' {
        $js = Join-Path $script:repo 'modules' 'PowerShellUniversal.Component.ECharts' 'Components' 'buildOption.js'
        $uri = [System.Uri]::new((Resolve-Path $js).Path).AbsoluteUri
        $jsTypes = node --input-type=module -e "import('$uri').then(m => console.log(m.CHART_TYPES.join(',')))"
        $psTypes = (Get-Command New-UDEChart).Parameters['Type'].Attributes.ValidValues
        ($psTypes | Sort-Object) -join ',' | Should -Be (($jsTypes -split ',' | Sort-Object) -join ',')
    }
    It 'fails clearly outside PSU when the bundle is missing' {
        & $script:module { $Script:AssetId = $null }
        try { { New-UDEChart -Data @() } | Should -Throw '*bundle*' }
        finally { & $script:module { $Script:AssetId = 'asset-under-test' } }
    }
}

Describe 'New-UDEChartTimeBreak' {
    It 'cuts nights and merges a weekend into one break' {
        $b = @(New-UDEChartTimeBreak -From '2026-11-06 00:00' -To '2026-11-10 23:59' -Weekends)
        $b.Count | Should -Be 4
        $b[1].start | Should -BeLike '2026-11-06T18:00:00*'
        $b[1].end | Should -BeLike '2026-11-09T08:00:00*'
        $b[0].gap | Should -Be '1%'
    }
    It 'stays inside the range' {
        $b = @(New-UDEChartTimeBreak -From '2026-11-04 12:00' -To '2026-11-04 20:00')
        $b.Count | Should -Be 1
        $b[0].start | Should -BeLike '2026-11-04T18:00:00*'
        $b[0].end | Should -BeLike '2026-11-04T20:00:00*'
    }
    It 'rejects a day that ends before it starts' {
        { New-UDEChartTimeBreak -From '2026-11-04' -To '2026-11-05' -DayStart '18:00' -DayEnd '08:00' } | Should -Throw '*DayEnd*'
    }
}

Describe 'Set-UDEChartData' {
    It 'sends converted data with Set-UDElement' {
        & $script:module {
            function script:Set-UDElement { param($Id, $Properties) $script:lastSet = @{ Id = $Id; Properties = $Properties } }
        }
        Set-UDEChartData -Id 'live' -Data @([pscustomobject]@{ T = [datetime]'2026-01-01'; V = 1 })
        $sent = & $script:module { $script:lastSet }
        $sent.Id | Should -Be 'live'
        $sent.Properties.data[0].T | Should -BeLike '2026-01-01T00:00:00*'
    }
}
