@{
    RootModule        = 'PowerShellUniversal.Component.Perspective.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '8f8d3cbd-e95b-4d6f-98d1-abce9ca8d3f8'
    Author            = 'eizedev'
    CompanyName       = 'eizedev'
    Copyright         = '(c) 2026 eizedev. MIT License.'
    Description       = 'FINOS Perspective for PowerShell Universal apps: a datagrid, pivot table and chart in one, which users group, split, filter and sort themselves; WebAssembly engine for large row counts, light and dark theme, fed straight from SQL DataTables, REST results and PowerShell objects.'
    PowerShellVersion = '7.4'
    FunctionsToExport = @('New-UDPerspective')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            # "PowerShellUniversal" lists the module in PSU's admin console and the Devolutions gallery
            Tags         = @('PowerShellUniversal', 'UniversalDashboard', 'PSU', 'Perspective', 'Pivot', 'DataGrid', 'Dashboard', 'Visualization')
            LicenseUri   = 'https://github.com/eizedev/powershell-universal-components/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/eizedev/powershell-universal-components'
            ReleaseNotes = 'https://github.com/eizedev/powershell-universal-components/blob/main/modules/PowerShellUniversal.Component.Perspective/CHANGELOG.md'
        }
    }
}
