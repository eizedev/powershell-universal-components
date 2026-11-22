function Write-UDPivotReportTable {
    <#
    .SYNOPSIS
        Writes rows as pivotkit's table of data (columns, rows, rowCount) into an open JSON object, row by
        row, and stops as soon as the JSON passes -MaxBytes.
    .DESCRIPTION
        A DataTable or DataView is read straight from its rows (no row objects in between), when its
        columns hold text, numbers, booleans, GUIDs, dates or TimeSpans; any other -Data goes through
        ConvertTo-PSUComponentData first. Values: text, a finite number, true, false or null; dates as
        ISO 8601 text, TimeSpans as seconds, DBNull, NaN and infinity as null, anything else its text.
        The columns are those of the first row; every row is read by those names, so another property
        order keeps its columns, a missing one is null, and one the first row lacks is left out with one
        warning. With -MaxBytes the row count times the columns is checked first (each cell takes at
        least two bytes), then the JSON written so far every 256 rows; past the cap it throws
        PivotDataTooLarge, before the rest is converted.
    .PARAMETER Writer
        The writer, inside an object (WriteStartObject done).
    .PARAMETER Data
        The rows: a DataTable, DataView, DataRows, objects, hashtables or a script block returning them.
    .PARAMETER MaxBytes
        The most bytes the writer may hold; 0 for no cap.
    .PARAMETER RowCount
        Write rowCount after the rows (pivotkit-server's data in the request needs it).
    .EXAMPLE
        Write-UDPivotReportTable -Writer $writer -Data $table -MaxBytes 10MB -RowCount
    .OUTPUTS
        None.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)][System.Text.Json.Utf8JsonWriter]$Writer,
        [Parameter(Mandatory)][AllowNull()][AllowEmptyCollection()][object]$Data,
        [long]$MaxBytes = 0,
        [switch]$RowCount
    )
    $tooLarge = {
        throw (New-UDPivotError -Id PivotDataTooLarge -Category LimitsExceeded -Data @{ MaxBytes = $MaxBytes } -Message ('-Data is larger than {0:N0} bytes, the most this request may carry (-MaxBytes; pivotkit-server takes 10 MiB from a caller unless its operator raised rest.data.maxBytes): send fewer rows or columns, raise -MaxBytes to what the server takes, or let the operator configure a source for the data and use -Source.' -f $MaxBytes))
    }
    # a DataTable or DataView whose column types need no PowerShell rules: its rows as they are
    # assigned, not taken from an if's output: the pipeline would enumerate the table into its rows
    $table = $null
    if ($Data -is [System.Data.DataTable]) { $table = $Data } elseif ($Data -is [System.Data.DataView]) { $table = $Data.Table }
    $plainTypes = [type[]]@([string], [bool], [char], [byte], [sbyte], [int16], [uint16], [int], [uint32], [long], [uint64], [single], [double], [decimal], [guid], [datetime], [datetimeoffset], [timespan])
    $direct = $table -and $table.Columns.Count -and @($table.Columns | Where-Object { $_.DataType -notin $plainTypes }).Count -eq 0
    if ($direct) {
        $columns = [string[]]@($table.Columns | ForEach-Object ColumnName)
        $source = $table.Rows
        if ($Data -is [System.Data.DataView]) { $source = $Data }
        $count = $source.Count
    }
    else {
        # PSCustomObjects as they are (the compiled writer reads them by name and applies the value rules);
        # anything else through ConvertTo-PSUComponentData
        $writerType = if ($Data -is [System.Collections.IList] -and $Data.Count -ge $Script:ReportWriterMinRows) { Get-UDPivotTableWriter }
        if ($writerType -and $writerType::AllCustomObjects($Data)) { $source = $Data }
        else { $source = ConvertTo-PSUComponentData -InputObject $Data }
        $columns = [string[]]@($source | Select-Object -First 1 | ForEach-Object { $_.PSObject.Properties.Name })
        $count = @($source).Count
    }
    # an empty result has no columns to check a view against: the caller decides (a schedule skips the run)
    if (-not $columns.Count) { throw '-Data: no rows, so there is no report to render; check for rows before you call (if (@($rows).Count) { ... }).' }
    if ($MaxBytes -gt 0 -and [long]$count * (2 * $columns.Count + 1) -gt $MaxBytes) { & $tooLarge }

    $Writer.WriteStartArray('columns')
    foreach ($name in $columns) { $Writer.WriteStringValue($name) }
    $Writer.WriteEndArray()
    $Writer.WriteStartArray('rows')
    $known = [System.Collections.Generic.HashSet[string]]::new($columns, [System.StringComparer]::OrdinalIgnoreCase)
    $dropped = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $width = $columns.Count
    $written = 0
    $compiled = if ($count -ge $Script:ReportWriterMinRows) { Get-UDPivotTableWriter }
    # which writer wrote the last table: Compiled or PowerShell (the tests check that the class runs)
    $Script:LastTableWriter = if ($compiled) { 'Compiled' } else { 'PowerShell' }
    if ($compiled) {
        $written = $compiled::WriteRows($Writer, $columns, $source, $MaxBytes, $dropped)
        if ($written -lt 0) { & $tooLarge }
        # nothing left for the loop below
        $source = @()
    }
    foreach ($item in $source) {
        if ($direct) {
            $dataRow = if ($item -is [System.Data.DataRowView]) { $item.Row } else { $item }
            # a row deleted but not yet accepted has no values to read (ItemArray throws): left out
            if ($dataRow.RowState -in [System.Data.DataRowState]::Deleted, [System.Data.DataRowState]::Detached) { continue }
            $values = $dataRow.ItemArray
        }
        else {
            # by name: the rows' properties may come in another order than the first row's
            $properties = $item.PSObject.Properties
            $values = [object[]]::new($width)
            for ($i = 0; $i -lt $width; $i++) { $p = $properties[$columns[$i]]; if ($p) { $values[$i] = $p.Value } }
            foreach ($name in $properties.Name) { if (-not $known.Contains($name)) { [void]$dropped.Add($name) } }
        }
        $Writer.WriteStartArray()
        foreach ($v in $values) {
            if ($null -eq $v -or $v -is [System.DBNull]) { $Writer.WriteNullValue() }
            elseif ($v -is [string]) { $Writer.WriteStringValue($v) }
            elseif ($v -is [bool]) { $Writer.WriteBooleanValue($v) }
            elseif ($v -is [double] -or $v -is [single]) { if ([double]::IsNaN($v) -or [double]::IsInfinity($v)) { $Writer.WriteNullValue() } else { $Writer.WriteNumberValue([double]$v) } }
            elseif ($v -is [int] -or $v -is [long] -or $v -is [short] -or $v -is [byte] -or $v -is [sbyte] -or $v -is [uint16] -or $v -is [uint32]) { $Writer.WriteNumberValue([long]$v) }
            elseif ($v -is [decimal] -or $v -is [uint64]) { $Writer.WriteNumberValue([decimal]$v) }
            elseif ($v -is [datetime] -or $v -is [datetimeoffset]) { $Writer.WriteStringValue($v.ToString('o', [cultureinfo]::InvariantCulture)) }
            elseif ($v -is [timespan]) { $Writer.WriteNumberValue([double]$v.TotalSeconds) }
            else { $Writer.WriteStringValue([string]$v) }
        }
        $Writer.WriteEndArray()
        $written++
        if ($MaxBytes -gt 0 -and ($written % 256) -eq 0 -and $Writer.BytesCommitted + $Writer.BytesPending -gt $MaxBytes) { & $tooLarge }
    }
    $Writer.WriteEndArray()
    if ($MaxBytes -gt 0 -and $Writer.BytesCommitted + $Writer.BytesPending -gt $MaxBytes) { & $tooLarge }
    if ($RowCount) { $Writer.WriteNumber('rowCount', [long]$written) }
    if ($dropped.Count) {
        $names = @($dropped | Select-Object -First 5) -join ', '
        Write-Warning ('-Data: properties the first row does not have are left out: {0}{1}. Give every row the same properties (Select-Object) to keep them.' -f $names, $(if ($dropped.Count -gt 5) { ', and {0} more' -f ($dropped.Count - 5) }))
    }
}
