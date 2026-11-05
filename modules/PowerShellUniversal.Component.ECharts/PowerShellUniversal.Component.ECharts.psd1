@{
    RootModule        = 'PowerShellUniversal.Component.ECharts.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '3f6c2b5e-8a4d-4c1e-9b7a-2d5e6f8a1c34'
    Author            = 'eizedev'
    CompanyName       = 'eizedev'
    Copyright         = '(c) 2026 eizedev. MIT License.'
    Description       = 'Interactive Apache ECharts charts for PowerShell Universal apps: zoom, range selection, click events, linked charts, light and dark theme, CSV and Excel export, fed straight from SQL DataTables, REST results and PowerShell objects.'
    # PSU 2026 runs apps in PowerShell 7 (integrated SDK or an external pwsh environment)
    PowerShellVersion = '7.4'
    FunctionsToExport = @('New-UDEChart', 'New-UDEChartTimeBreak', 'Set-UDEChartData')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            # "PowerShellUniversal" lists the module in PSU's admin console and the Devolutions gallery
            Tags         = @('PowerShellUniversal', 'UniversalDashboard', 'PSU', 'ECharts', 'Charts', 'Dashboard', 'Visualization')
            LicenseUri   = 'https://github.com/eizedev/powershell-universal-components/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/eizedev/powershell-universal-components'
            ReleaseNotes = 'https://github.com/eizedev/powershell-universal-components/blob/main/modules/PowerShellUniversal.Component.ECharts/CHANGELOG.md'
        }
    }
}
