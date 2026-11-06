#Requires -Version 7.4
# Pester tests for PowerShellUniversal.Component.Perspective outside PSU: PSU's [Endpoint] type is a
# stub, the asset id is set by hand.

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
    $script:module = Import-Module (Join-Path $script:repo 'modules' 'PowerShellUniversal.Component.Perspective' 'PowerShellUniversal.Component.Perspective.psm1') -Force -PassThru
    & $script:module { $Script:AssetId = 'asset-under-test' }
}

Describe 'New-UDPerspective' {
    It 'returns the plugin hashtable with the rows and their original column names' {
        $rows = @([pscustomobject]@{ TicketId = 1; Team = 'Network' }, [pscustomobject]@{ TicketId = 2; Team = 'Server' })
        $c = New-UDPerspective -Id 'p1' -Data $rows -GroupBy Team -Sort 'TicketId desc'
        $c.type | Should -Be 'ud-perspective'
        $c.assetId | Should -Be 'asset-under-test'
        @($c.data).Count | Should -Be 2
        $c.columnNames | Should -Be @('TicketId', 'Team')
        $c.groupBy | Should -Be @('Team')
        $c.plugin | Should -Be 'Datagrid'
    }
    It 'takes the chart names of Perspective 5 (measured in the browser)' {
        (New-UDPerspective -Data @([pscustomobject]@{ A = 1 }) -Plugin 'X/Y Scatter').plugin | Should -Be 'X/Y Scatter'
        { New-UDPerspective -Data @() -Plugin 'XY Scatter' } | Should -Throw
    }
    It 'has the toolbar on by default, with Y Bar as the chart of the Table/Chart switch' {
        $c = New-UDPerspective -Data @([pscustomobject]@{ A = 1 })
        $c.toolbar | Should -BeTrue
        $c.chartPlugin | Should -Be 'Y Bar'
        $c.ContainsKey('labels') | Should -BeFalse
    }
    It 'takes -NoToolbar, -ChartPlugin and -Labels' {
        $c = New-UDPerspective -Data @([pscustomobject]@{ A = 1 }) -NoToolbar -ChartPlugin Treemap -Labels @{ EditView = 'Ansicht bearbeiten' }
        $c.toolbar | Should -BeFalse
        $c.chartPlugin | Should -Be 'Treemap'
        $c.labels.EditView | Should -Be 'Ansicht bearbeiten'
        # the table is not a chart
        { New-UDPerspective -Data @() -ChartPlugin Datagrid } | Should -Throw
    }
    It 'converts a DataTable' {
        $t = [System.Data.DataTable]::new()
        [void]$t.Columns.Add('Name'); [void]$t.Columns.Add('Count', [int])
        [void]$t.Rows.Add('a', 1); [void]$t.Rows.Add('b', [DBNull]::Value)
        $c = New-UDPerspective -Data $t
        $c.columnNames | Should -Be @('Name', 'Count')
        @($c.data)[1].Count | Should -BeNullOrEmpty
    }
    It 'registers the click endpoint' {
        $c = New-UDPerspective -Id 'p2' -Data @() -OnClick ([Endpoint]::new({ 1 }))
        $c.onClick.RegisteredId | Should -Be 'p2'
    }
}
