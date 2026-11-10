@{
    RootModule        = 'PowerShellUniversal.Component.Pivot.Demo.psm1'
    ModuleVersion     = '0.1.2'
    GUID              = 'b551b13d-c6fd-47ba-b311-54643c7d2b72'
    Author            = 'eizedev'
    CompanyName       = 'eizedev'
    Copyright         = '(c) 2026 eizedev. MIT License.'
    Description       = 'Showcase app for PowerShellUniversal.Component.Pivot: pivot reports on software release cycles (endoflife.date) and weather (Open-Meteo) with shipped snapshots or live data, your own CSV and JSON files, and a 5,000-row ticket report with templates, events and page layouts; English and German.'
    PowerShellVersion = '7.4'
    # the pivot report itself; PSU loads it from its Modules folder or the gallery
    RequiredModules   = @(@{ ModuleName = 'PowerShellUniversal.Component.Pivot'; ModuleVersion = '0.3.0' })
    FunctionsToExport = @('New-UDPivotShowcase', 'Get-UDPivotShowcaseData')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags         = @('PowerShellUniversal', 'Pivot', 'PivotTable', 'Report', 'Dashboard', 'Demo')
            LicenseUri   = 'https://github.com/eizedev/powershell-universal-components/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/eizedev/powershell-universal-components'
            ReleaseNotes = 'https://github.com/eizedev/powershell-universal-components/blob/main/modules/PowerShellUniversal.Component.Pivot.Demo/CHANGELOG.md'
        }
    }
}
