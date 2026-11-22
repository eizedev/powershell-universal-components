function Get-UDPivotSqlColumnDescription {
    <#
    .SYNOPSIS
        The column descriptions of a SQL Server table or view (extended property MS_Description), as the
        hashtable -FieldDescriptions of New-UDPivotReport takes.
    .DESCRIPTION
        Reads sys.extended_properties for the columns of one table or view (class 1, major_id the object,
        minor_id the column) with the property name MS_Description - what SQL Server Management Studio
        writes as a column's Description - and returns column name to text, in column order. Columns
        without a description are left out.

        Pass an open connection (-Connection: System.Data.SqlClient, Microsoft.Data.SqlClient or any
        ADO.NET connection to SQL Server; it stays open) or a connection string (-ConnectionString: the
        function opens and closes a connection with Microsoft.Data.SqlClient when that is loaded, for
        example by the SqlServer module, else with System.Data.SqlClient, which PowerShell 7 ships).
        The table name goes to SQL Server as a parameter of OBJECT_ID(), never into the query text. The
        account sees only the descriptions of objects it has permissions on; an unknown table gives an
        empty result.
    .PARAMETER Connection
        An open ADO.NET connection to the database that holds the table.
    .PARAMETER ConnectionString
        A connection string to the database that holds the table.
    .PARAMETER Table
        The table or view, as OBJECT_ID() takes it: dbo.Tickets, [sales].[Order Lines] or Tickets
        (the user's default schema).
    .PARAMETER PropertyName
        The extended property to read. Default: MS_Description.
    .PARAMETER TimeoutSec
        Command timeout in seconds. Default: 30.
    .EXAMPLE
        $descriptions = Get-UDPivotSqlColumnDescription -ConnectionString $connectionString -Table 'dbo.Tickets'
        New-UDPivotReport -Id 'tickets' -Data $tickets -FieldDescriptions $descriptions
    .EXAMPLE
        $connection = [System.Data.SqlClient.SqlConnection]::new($connectionString)
        $connection.Open()
        try { $descriptions = Get-UDPivotSqlColumnDescription -Connection $connection -Table '[sales].[Orders]' }
        finally { $connection.Dispose() }
    .OUTPUTS
        System.Collections.Specialized.OrderedDictionary
    .LINK
        https://powershell-universal-components.eize.dev/pivot/fields/
    #>
    [CmdletBinding(DefaultParameterSetName = 'ConnectionString')]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Connection')][System.Data.IDbConnection]$Connection,
        [Parameter(Mandatory, ParameterSetName = 'ConnectionString')][ValidateNotNullOrEmpty()][string]$ConnectionString,
        [Parameter(Mandatory)][ValidateLength(1, 776)][string]$Table,
        [ValidateLength(1, 128)][string]$PropertyName = 'MS_Description',
        [ValidateRange(1, 3600)][int]$TimeoutSec = 30
    )
    # -ErrorVariable gets the error itself, not each step it took through the module
    $errorMark = Get-UDPivotErrorMark -Cmdlet $PSCmdlet
    trap { Reset-UDPivotErrorVariable -Mark $errorMark; throw $_ }

    $own = $PSCmdlet.ParameterSetName -eq 'ConnectionString'
    if ($own) {
        $type = 'Microsoft.Data.SqlClient.SqlConnection' -as [type]
        if (-not $type) { $type = 'System.Data.SqlClient.SqlConnection' -as [type] }
        if (-not $type) { throw 'Get-UDPivotSqlColumnDescription: no SQL Server client (Microsoft.Data.SqlClient or System.Data.SqlClient) is loaded; pass an open connection with -Connection.' }
        $Connection = $type::new($ConnectionString)
    }
    try {
        if ($own) { $Connection.Open() }
        $command = $Connection.CreateCommand()
        try {
            $command.CommandTimeout = $TimeoutSec
            $command.CommandText = $Script:SqlColumnDescriptionQuery
            foreach ($parameter in @{ '@Table' = $Table; '@Name' = $PropertyName }.GetEnumerator()) {
                $p = $command.CreateParameter()
                $p.ParameterName = $parameter.Key
                $p.DbType = [System.Data.DbType]::String
                $p.Value = $parameter.Value
                [void]$command.Parameters.Add($p)
            }
            $result = [ordered]@{}
            $reader = $command.ExecuteReader()
            try {
                while ($reader.Read()) {
                    if ($reader.IsDBNull(1)) { continue }
                    $text = [string]$reader.GetValue(1)
                    if (-not [string]::IsNullOrWhiteSpace($text)) { $result[[string]$reader.GetValue(0)] = $text }
                }
            }
            finally {
                $reader.Dispose()
            }
            $result
        }
        finally {
            $command.Dispose()
        }
    }
    finally {
        if ($own) { $Connection.Dispose() }
    }
}
