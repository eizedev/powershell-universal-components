@{
    RootModule        = 'PowerShellUniversal.Component.Pivot.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'e59f7ff0-a6dc-4402-9729-98af8be5c83b'
    Author            = 'eizedev'
    CompanyName       = 'eizedev'
    Copyright         = '(c) 2026 eizedev. MIT License.'
    Description       = 'Pivot report builder for PowerShell Universal apps: readers drag fields into rows, columns, values and filters and get a table or a chart, with date grouping, drill-down to the source rows, templates, undo and Excel, CSV and PNG export; light and dark theme, English and German, fed straight from SQL DataTables, REST results and PowerShell objects.'
    PowerShellVersion = '7.4'
    FunctionsToExport = @('New-UDPivotReport', 'New-UDPivotReportPlaceholder', 'ConvertFrom-UDPivotView', 'ConvertFrom-UDPivotViewFile', 'ConvertTo-UDPivotViewFile', 'New-UDPivotFileTemplateStore', 'New-UDPivotTemplateStore', 'Invoke-UDPivotTemplateRequest', 'Get-UDPivotSqlColumnDescription')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            # "PowerShellUniversal" lists the module in PSU's admin console and the Devolutions gallery
            Tags         = @('PowerShellUniversal', 'UniversalDashboard', 'PSU', 'Pivot', 'PivotTable', 'Report', 'Dashboard', 'Excel', 'Visualization')
            LicenseUri   = 'https://github.com/eizedev/powershell-universal-components/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/eizedev/powershell-universal-components'
            ReleaseNotes = 'https://github.com/eizedev/powershell-universal-components/blob/main/modules/PowerShellUniversal.Component.Pivot/CHANGELOG.md'
        }
    }
}
