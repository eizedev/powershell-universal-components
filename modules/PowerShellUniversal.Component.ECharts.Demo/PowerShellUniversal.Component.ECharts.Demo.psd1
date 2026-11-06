@{
    RootModule        = 'PowerShellUniversal.Component.ECharts.Demo.psm1'
    ModuleVersion     = '0.2.0'
    GUID              = '856a5434-52c6-4bbf-8031-6e5bd7cc87f6'
    Author            = 'eizedev'
    CompanyName       = 'eizedev'
    Copyright         = '(c) 2026 eizedev. MIT License.'
    Description       = 'Showcase app for PowerShellUniversal.Component.ECharts: ticket report, finance, managed services, operations, a data platform combining many source systems, layouts and live data, all with generated data.'
    PowerShellVersion = '7.4'
    # the charts themselves; PSU loads it from its Modules folder or the gallery
    RequiredModules   = @(@{ ModuleName = 'PowerShellUniversal.Component.ECharts'; ModuleVersion = '0.2.0' })
    FunctionsToExport = @('New-UDEChartShowcase')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags         = @('PowerShellUniversal', 'ECharts', 'Charts', 'Dashboard', 'Demo')
            LicenseUri   = 'https://github.com/eizedev/powershell-universal-components/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/eizedev/powershell-universal-components'
            ReleaseNotes = 'https://github.com/eizedev/powershell-universal-components/blob/main/modules/PowerShellUniversal.Component.ECharts.Demo/CHANGELOG.md'
        }
    }
}
