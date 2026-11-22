function ConvertTo-UDPivotImportLimit {
    <#
    .SYNOPSIS
        Checks -ImportLimit and returns it as the report's import limits: pivotkit's key names, whole numbers.
    .DESCRIPTION
        Used by New-UDPivotReport. The keys are pivotkit-core's limits of a loaded file: fileBytes (bytes
        of a file), rows, columns, importCells (rows x columns, a workbook's texts and formats),
        textLength (characters of one value), archiveEntries (parts of a workbook) and unpackedBytes (bytes a workbook unpacks to), matched
        without regard to case and
        returned in pivotkit's spelling and order. Each value is a whole number from 1 to 9007199254740991
        (JavaScript's largest exact integer); 250MB and 2GB are fine. An unknown key, a value that is
        not a whole number or one out of range throws an error that names the key. Keys left out keep
        pivotkit's defaults.
    .PARAMETER ImportLimit
        The limits, e.g. @{ fileBytes = 250MB; rows = 2000000 }.
    .EXAMPLE
        ConvertTo-UDPivotImportLimit -ImportLimit @{ FileBytes = 250MB; rows = 2000000 }
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$ImportLimit)
    $limits = [ordered]@{}
    foreach ($key in $ImportLimit.Keys) {
        $name = $Script:ImportLimitDefaults.Keys | Where-Object { $_ -eq [string]$key } | Select-Object -First 1
        if (-not $name) {
            throw ('-ImportLimit: unknown limit "{0}"; known are {1}.' -f $key, ($Script:ImportLimitDefaults.Keys -join ', '))
        }
        if ($limits.Contains($name)) { throw ('-ImportLimit: {0} is given twice.' -f $name) }
        $value = $ImportLimit[$key]
        $isNumber = $value -is [int] -or $value -is [long] -or $value -is [double] -or $value -is [decimal] -or $value -is [single]
        if (-not $isNumber -or $value -ne [math]::Truncate($value) -or $value -lt 1 -or $value -gt $Script:MaxImportLimit) {
            throw ('-ImportLimit: {0} must be a whole number from 1 to {1}, not "{2}".' -f $name, $Script:MaxImportLimit, $value)
        }
        $limits[$name] = [long]$value
    }
    # in pivotkit's order, whatever order the hashtable had
    $ordered = [ordered]@{}
    foreach ($name in $Script:ImportLimitDefaults.Keys) { if ($limits.Contains($name)) { $ordered[$name] = $limits[$name] } }
    [pscustomobject]$ordered
}
