# Quick start of the root README: data every PSU server has, no database or API needed.
# Deploy as an app's script; the README screenshots assets/screenshot-quickstart-light.png and -dark.png show this app.
New-UDApp -Title 'Commands' -Content {
    New-UDCard -Title 'PowerShell commands per verb' -Content {
        $commands = Get-Command -CommandType Cmdlet, Function |
            Where-Object Verb
        # the ten verbs with the most commands, most first
        $top = $commands | Group-Object Verb |
            Sort-Object Count -Descending |
            Select-Object -First 10 -ExpandProperty Name
        $rows = $commands | Where-Object Verb -In $top |
            Group-Object Verb, CommandType | ForEach-Object {
                [pscustomobject]@{
                    Verb     = $_.Group[0].Verb
                    Type     = "$($_.Group[0].CommandType)"
                    Commands = $_.Count
                }
            } | Sort-Object { [array]::IndexOf($top, $_.Verb) }
        $chart = @{
            Data = $rows; Type = 'bar'; X = 'Verb'; Y = 'Commands'
            GroupBy = 'Type'; Stacked = $true; Height = '360px'
        }
        New-UDEChart @chart -OnClick {
            $e = $EventData
            Show-UDToast -Message "$($e.name): $($e.value) $($e.seriesName)s"
        }
    }
}
