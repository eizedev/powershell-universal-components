#Requires -Version 7.4
# Pester tests for the templates of PowerShellUniversal.Component.Pivot outside PSU: view files,
# -TemplatePath, the template stores, the role checks of their event handlers. PSU's [Endpoint] type is
# a stub, the asset id is set by hand.

BeforeAll {
    . (Join-Path $PSScriptRoot '..' '..' 'build' 'Add-EndpointType.ps1')
    $script:repo = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
    $script:module = Import-Module (Join-Path $script:repo 'modules' 'PowerShellUniversal.Component.Pivot' 'PowerShellUniversal.Component.Pivot.psm1') -Force -PassThru
    & $script:module { $Script:AssetId = 'asset-under-test' }
    $script:rows = @([pscustomobject]@{ Team = 'Ops'; Hours = 2 })
    $script:view = @{ rows = @('Team'); values = @(@{ field = 'Hours'; agg = 'sum' }) }
    # the key the generated handler carries
    $script:keyOf = { param($Endpoint) [regex]::Match($Endpoint.ScriptBlock.ToString(), "'([0-9a-f]{32})'").Groups[1].Value }
    $script:failedText = & $script:module { $Script:StoreFailedText }
}

Describe 'What a reader reads when the store fails' {
    It 'a folder the server cannot make: the general text, the path in the log only' {
        # a file where the store's folder should be: making the folder fails with the path in its message
        $blocker = Join-Path ([System.IO.Path]::GetTempPath()) ('pivot-tests-{0}' -f [guid]::NewGuid().ToString('n'))
        Set-Content -LiteralPath $blocker -Value 'not a folder'
        try {
            $store = New-UDPivotFileTemplateStore -Path (Join-Path $blocker 'views')
            $report = New-UDPivotReport -Id 'tickets' -Data $script:rows -TemplateStore $store -UserName 'alex' -Roles 'Reader'
            $key = & $script:keyOf $report.onSaveTemplate
            $answer = Invoke-UDPivotTemplateRequest -Key $key -Action Save -EventData @{ name = 'Overview'; view = $script:view } -UserName 'alex' -Roles 'Reader' -WarningVariable logged -WarningAction SilentlyContinue
            $answer.error | Should -Be $script:failedText
            $answer.error | Should -Not -Match ([regex]::Escape($blocker))
            ($logged -join "`n") | Should -Match 'Pivot template store'
        }
        finally { Remove-Item -LiteralPath $blocker -Force }
    }

    It 'a store of the app: its own refusal reaches the reader, an error of a .NET method does not' {
        $refusing = New-UDPivotTemplateStore -Get { } -Save { throw 'Not on weekends.' } -Delete { }
        $report = New-UDPivotReport -Id 'tickets' -Data $script:rows -TemplateStore $refusing -UserName 'alex' -Roles 'Reader'
        $key = & $script:keyOf $report.onSaveTemplate
        (Invoke-UDPivotTemplateRequest -Key $key -Action Save -EventData @{ name = 'Overview'; view = $script:view } -UserName 'alex' -Roles 'Reader').error | Should -Be 'Not on weekends.'
        $failing = New-UDPivotTemplateStore -Get { } -Save { [System.IO.File]::ReadAllText('/no/such/folder/views.json') } -Delete { }
        $report = New-UDPivotReport -Id 'tickets2' -Data $script:rows -TemplateStore $failing -UserName 'alex' -Roles 'Reader'
        $key = & $script:keyOf $report.onSaveTemplate
        $answer = Invoke-UDPivotTemplateRequest -Key $key -Action Save -EventData @{ name = 'Overview'; view = $script:view } -UserName 'alex' -Roles 'Reader' -WarningAction SilentlyContinue
        $answer.error | Should -Be $script:failedText
        $answer.error | Should -Not -Match 'no/such/folder'
    }
}
