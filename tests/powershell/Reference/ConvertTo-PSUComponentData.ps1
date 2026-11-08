function ConvertTo-PSUComponentData {
    <#
    .SYNOPSIS
        Turns whatever a query returned into rows a component can send to the browser.
    .DESCRIPTION
        Accepts a System.Data.DataTable or DataView (SqlClient, ODBC, OleDb), DataRow objects,
        PSCustomObjects (Invoke-RestMethod, Select-Object, Import-Csv), hashtables, scalars, or a script
        block that returns any of these. Returns an array of PSCustomObjects:
        - DBNull and $null become $null, so the browser sees null instead of an empty object
        - DateTime and DateTimeOffset become ISO 8601 strings, so dates survive serialization
        - TimeSpan becomes seconds (a number), enums their name
        - scalars (numbers, dates, GUIDs, strings) become one column "value"
        - column order follows the source
        PSCustomObjects because PSU serializes an [ordered] dictionary as an array of key/value pairs
        (measured on PSU 2026.3.4). Shared by every component module of this repository; compiled
        into each module at build time.
    .PARAMETER InputObject
        The data, or a script block returning it.
    .EXAMPLE
        ConvertTo-PSUComponentData -InputObject $dataTable
    .EXAMPLE
        ConvertTo-PSUComponentData -InputObject { Invoke-RestMethod 'https://api.example.com/items' }
    .OUTPUTS
        System.Management.Automation.PSCustomObject[]
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject[]])]
    param([AllowNull()][object]$InputObject)

    if ($null -eq $InputObject) { return , @() }
    if ($InputObject -is [scriptblock]) { $InputObject = & $InputObject }

    $rows = if ($InputObject -is [System.Data.DataTable]) { $InputObject.Rows }
    elseif ($InputObject -is [System.Data.DataView]) { $InputObject | ForEach-Object Row }
    else { @($InputObject) }

    $result = @(foreach ($row in $rows) {
            if ($null -eq $row -or $row -is [System.DBNull]) { continue }
            $out = [ordered]@{}
            if ($row -is [System.Data.DataRowView]) { $row = $row.Row }
            if ($row -is [System.Data.DataRow]) {
                foreach ($col in $row.Table.Columns) { $out[$col.ColumnName] = ConvertTo-PSUComponentValue $row[$col] }
            }
            elseif ($row -is [System.Collections.IDictionary]) {
                foreach ($key in $row.Keys) { $out[[string]$key] = ConvertTo-PSUComponentValue $row[$key] }
            }
            elseif ($row -is [string] -or $row -is [valuetype]) {
                # numbers, dates, GUIDs, enums, booleans: one column "value" instead of their properties
                $out['value'] = ConvertTo-PSUComponentValue $row
            }
            else {
                foreach ($prop in $row.PSObject.Properties) {
                    if ($prop.MemberType -in 'NoteProperty', 'Property', 'AliasProperty', 'ScriptProperty') {
                        $out[$prop.Name] = ConvertTo-PSUComponentValue $prop.Value
                    }
                }
            }
            [pscustomobject]$out
        })
    , $result
}

function ConvertTo-PSUComponentValue {
    <#
    .SYNOPSIS
        Converts one cell value to a JSON-safe value (see ConvertTo-PSUComponentData).
    .PARAMETER Value
        The value.
    .EXAMPLE
        ConvertTo-PSUComponentValue ([DBNull]::Value)
    #>
    [CmdletBinding()]
    param([AllowNull()][object]$Value)
    if ($null -eq $Value -or $Value -is [System.DBNull]) { return $null }
    if ($Value -is [datetime] -or $Value -is [datetimeoffset]) { return $Value.ToString('o') }
    if ($Value -is [timespan]) { return $Value.TotalSeconds }
    if ($Value -is [enum]) { return [string]$Value }
    $Value
}
