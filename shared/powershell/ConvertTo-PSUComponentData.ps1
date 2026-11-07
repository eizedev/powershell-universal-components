# How ConvertTo-PSUComponentData treats a value, by its type: 'Plain' goes out as it is, 'Date' as
# ISO 8601 text, 'Null' as $null. Types not listed go through ConvertTo-PSUComponentValue.
$Script:PSUComponentValueKind = @{
    [string]         = 'Plain'
    [bool]           = 'Plain'
    [char]           = 'Plain'
    [byte]           = 'Plain'
    [sbyte]          = 'Plain'
    [int16]          = 'Plain'
    [uint16]         = 'Plain'
    [int]            = 'Plain'
    [uint32]         = 'Plain'
    [long]           = 'Plain'
    [uint64]         = 'Plain'
    [single]         = 'Plain'
    [double]         = 'Plain'
    [decimal]        = 'Plain'
    [guid]           = 'Plain'
    [datetime]       = 'Date'
    [datetimeoffset] = 'Date'
    [System.DBNull]  = 'Null'
}

# A DataTable is the large case (SQL results of thousands of rows), and building PSCustomObjects in
# PowerShell costs about 40 microseconds per row on a small server; the same in C# about 7 (measured
# on PSU 2026.3.4: 5000 rows x 12 columns, 190 ms against 35 ms). The class is compiled once per
# process (about 2 s), the first time a DataTable of at least $Script:PSUComponentCompileMinRows rows
# arrives; PSU runs its apps in its own process, so that happens once per PSU start, not per app start.
# Where Add-Type is not available (constrained language mode) the PowerShell path does the same work.
# The class name carries a hash of the source, so modules built from different versions of this file
# never share a class.
$Script:PSUComponentRowSource = @'
using System;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using System.Management.Automation;

namespace PSUComponentData
{
    public static class RowConverter_SUFFIX
    {
        // The rows (DataRows, or the DataRowViews of a DataView) as ConvertTo-PSUComponentData returns
        // them, or null when a column needs the
        // PowerShell rules (types other than strings, numbers, booleans, GUIDs, dates and
        // TimeSpans) or two names differ only in case (an [ordered] dictionary merges them).
        public static object[] Convert(DataTable table, IEnumerable rows)
        {
            int count = table.Columns.Count;
            string[] names = new string[count];
            int[] kinds = new int[count];
            HashSet<string> seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            for (int c = 0; c < count; c++)
            {
                DataColumn column = table.Columns[c];
                names[c] = column.ColumnName;
                if (!seen.Add(column.ColumnName)) return null;
                Type type = column.DataType;
                if (type.IsPrimitive || type == typeof(string) || type == typeof(decimal) || type == typeof(Guid)) kinds[c] = 0;
                else if (type == typeof(DateTime)) kinds[c] = 1;
                else if (type == typeof(DateTimeOffset)) kinds[c] = 2;
                else if (type == typeof(TimeSpan)) kinds[c] = 3;
                else return null;
            }
            List<object> result = new List<object>();
            foreach (object item in rows)
            {
                DataRowView view = item as DataRowView;
                DataRow row = view != null ? view.Row : (DataRow)item;
                PSObject output = new PSObject();
                for (int c = 0; c < count; c++)
                {
                    object value = row[c];
                    if (value is DBNull) value = null;
                    else if (kinds[c] == 1) value = ((DateTime)value).ToString("o");
                    else if (kinds[c] == 2) value = ((DateTimeOffset)value).ToString("o");
                    else if (kinds[c] == 3) value = ((TimeSpan)value).TotalSeconds;
                    output.Properties.Add(new PSNoteProperty(names[c], value));
                }
                result.Add(output);
            }
            return result.ToArray();
        }
    }
}
'@
$Script:PSUComponentRowType = & {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $hash = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Script:PSUComponentRowSource)) } finally { $sha.Dispose() }
    'PSUComponentData.RowConverter_' + (-join ($hash[0..7] | ForEach-Object { $_.ToString('x2') }))
}
$Script:PSUComponentRowSource = $Script:PSUComponentRowSource.Replace('RowConverter_SUFFIX', ($Script:PSUComponentRowType -split '\.')[-1])
# smaller tables take a few milliseconds in PowerShell; the compiler is not worth its 2 s there
$Script:PSUComponentCompileMinRows = 1000
# $true: compiled, $false: not available (or switched off by a test), $null: not tried yet
$Script:PSUComponentRowCompiled = $null

function Get-PSUComponentRowConverter {
    <#
    .SYNOPSIS
        The compiled DataTable converter of ConvertTo-PSUComponentData, compiled on first use; $null when
        Add-Type is not available.
    .EXAMPLE
        $converter = Get-PSUComponentRowConverter
    .OUTPUTS
        System.Type, or $null.
    #>
    [CmdletBinding()]
    [OutputType([type])]
    param()
    if ($false -eq $Script:PSUComponentRowCompiled) { return $null }
    $type = $Script:PSUComponentRowType -as [type]
    if (-not $type) {
        try {
            Add-Type -TypeDefinition $Script:PSUComponentRowSource -ErrorAction Stop
            $type = $Script:PSUComponentRowType -as [type]
        }
        catch {
            Write-Verbose ('ConvertTo-PSUComponentData: no compiled converter ({0}); PowerShell converts the rows.' -f $_.Exception.Message)
        }
    }
    $Script:PSUComponentRowCompiled = $null -ne $type
    $type
}

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

        Speed: a page waits for this conversion before it gets the component, so it avoids a function
        call per cell. A DataTable of at least 1000 rows whose columns hold strings, numbers, booleans,
        GUIDs, dates or TimeSpans goes through a small compiled class (see $Script:PSUComponentRowSource).
        Otherwise the columns of a DataTable are classified once by their type, and strings, numbers,
        booleans, GUIDs and dates of other rows are converted inline. Only values of other types
        (TimeSpan, enums, arrays, nested objects) go through ConvertTo-PSUComponentValue.
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

    # assigned inside the branches: the output of an if statement would enumerate a DataTable's rows
    $source = $null
    if ($InputObject -is [System.Data.DataTable]) { $source = $InputObject; $tableRows = $InputObject.Rows }
    elseif ($InputObject -is [System.Data.DataView]) { $source = $InputObject.Table; $tableRows = $InputObject }
    if ($null -ne $source -and $source.Rows.Count -ge $Script:PSUComponentCompileMinRows) {
        $converter = Get-PSUComponentRowConverter
        if ($converter) {
            $converted = $converter::Convert($source, $tableRows)
            if ($null -ne $converted) { return , $converted }
        }
    }

    $rows = if ($InputObject -is [System.Data.DataTable]) { $InputObject.Rows }
    elseif ($InputObject -is [System.Data.DataView]) { $InputObject | ForEach-Object Row }
    else { @($InputObject) }

    $kinds = $Script:PSUComponentValueKind
    # the properties a PSCustomObject or .NET object contributes (the original filter on MemberType)
    $propertyTypes = [System.Management.Automation.PSMemberTypes]'NoteProperty,Property,AliasProperty,ScriptProperty'
    # the column plan of the DataTable the previous DataRow belonged to
    $table = $null
    $result = @(foreach ($row in $rows) {
        if ($null -eq $row -or $row -is [System.DBNull]) { continue }
        $out = [ordered]@{}
        if ($row -is [System.Data.DataRowView]) { $row = $row.Row }
        if ($row -is [System.Data.DataRow]) {
            if (-not [object]::ReferenceEquals($table, $row.Table)) {
                # a column holds one type (or DBNull): decide once per column what its cells need
                $table = $row.Table
                $columns = @($table.Columns)
                # plain strings: a name from ForEach-Object is a PSObject, and as a key it would turn the
                # AutomationNull of an empty array into $null
                $names = [string[]]@(foreach ($column in $columns) { $column.ColumnName })
                $columnKinds = @(foreach ($column in $columns) { $kinds[$column.DataType] })
                $dateColumns = [int[]]@(for ($c = 0; $c -lt $columns.Count; $c++) { if ($columnKinds[$c] -eq 'Date') { $c } })
                $otherColumns = [bool[]]@(foreach ($kind in $columnKinds) { $kind -notin 'Plain', 'Date' })
            }
            # ItemArray is a copy of the row's values: dates are replaced in it first
            $items = $row.ItemArray
            foreach ($c in $dateColumns) {
                $value = $items[$c]
                if ($value -isnot [System.DBNull]) { $items[$c] = $value.ToString('o') }
            }
            for ($c = 0; $c -lt $items.Length; $c++) {
                $value = $items[$c]
                if ($value -is [System.DBNull]) { $value = $null }
                elseif ($otherColumns[$c]) {
                    # straight into the row: an empty array becomes AutomationNull there, as it always did
                    $out[$names[$c]] = ConvertTo-PSUComponentValue $value
                    continue
                }
                $out[$names[$c]] = $value
            }
        }
        elseif ($row -is [System.Collections.IDictionary]) {
            foreach ($key in $row.Keys) {
                $value = $row[$key]
                # the same rules as ConvertTo-PSUComponentValue, inline for the common types
                if ($null -ne $value) {
                    $kind = $kinds[$value.GetType()]
                    if ($kind -eq 'Date') { $value = $value.ToString('o') }
                    elseif ($kind -eq 'Null') { $value = $null }
                    elseif ($kind -ne 'Plain') {
                        $out[[string]$key] = ConvertTo-PSUComponentValue $value
                        continue
                    }
                }
                $out[[string]$key] = $value
            }
        }
        elseif ($row -is [string] -or $row -is [valuetype]) {
            # numbers, dates, GUIDs, enums, booleans: one column "value" instead of their properties
            $out['value'] = ConvertTo-PSUComponentValue $row
        }
        else {
            foreach ($prop in $row.PSObject.Properties) {
                if (-not ($prop.MemberType -band $propertyTypes)) { continue }
                $value = $prop.Value
                # the same rules as ConvertTo-PSUComponentValue, inline for the common types
                if ($null -ne $value) {
                    $kind = $kinds[$value.GetType()]
                    if ($kind -eq 'Date') { $value = $value.ToString('o') }
                    elseif ($kind -eq 'Null') { $value = $null }
                    elseif ($kind -ne 'Plain') {
                        $out[$prop.Name] = ConvertTo-PSUComponentValue $value
                        continue
                    }
                }
                $out[$prop.Name] = $value
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
    .DESCRIPTION
        The rules for every type. ConvertTo-PSUComponentData applies them inline for the common
        types (see $Script:PSUComponentValueKind) and calls this function for the others.
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
