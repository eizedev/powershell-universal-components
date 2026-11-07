---
title: Field names and descriptions
description: "Display names, descriptions, links, orders and formats of the fields of New-UDPivotReport: -FieldDefaults, -FieldDescriptions, SQL Server column descriptions with Get-UDPivotSqlColumnDescription, and -Schema from a JSON Schema or an OpenAPI document."
---

# Field names and descriptions

A column called `LeadHours` or `cust_no` tells a reader little. The report can show a field under
another name, explain it behind an "i" next to the field (in the field list, its menu and the table's
headers) with a "Learn more" link, sort its items in their own order and give it an aggregator and a
format when it is put into Values. Three parameters say it, from the most specific to the most general:

| Parameter | What | Where it comes from |
| --- | --- | --- |
| `-FieldDefaults` | everything about a field: label, description, link, order, aggregator, formats, type | your app script |
| `-FieldDescriptions` | a description per field | SQL Server column descriptions, a CSV, a hashtable |
| `-Schema` | labels, descriptions, links, types and orders from a JSON Schema or an OpenAPI document | the API the data comes from |

Where they say something about the same field, `-FieldDefaults` wins over `-FieldDescriptions`, and
both win over `-Schema`, key by key. Field names match without regard to case. Views and templates
always keep the field's own name: a label changes what the reader sees, not what is stored.

--8<-- "examples/field-names-and-descriptions.md"

## -FieldDefaults

```powershell
New-UDPivotReport -Id 'tickets' -Data $tickets -FieldDefaults @{
    LeadHours = @{ Label = 'Lead time (h)'; Description = 'Hours from creation to closing; empty while the ticket is open.'
                   Href = 'https://wiki.example.com/tickets/lead-time'; Agg = 'average'; Format = 'number:1' }
    Priority  = @{ Order = 'P1', 'P2', 'P3', 'P4'; Description = 'P1 is the most urgent.' }
    Ticket    = @{ Agg = 'count'; DrillFormat = 'text' }
}
```

| Key | What | Checked on the server |
| --- | --- | --- |
| `Label` | the name shown for the field everywhere: field list, zones, headers, value names ("Average of Lead time (h)"), drill-down, chart, exports | text, cut at 120 characters |
| `Description` | plain text behind the "i"; screen readers hear it with the field | text, cut at 1000 characters |
| `Href` | a "Learn more" link under the description | an absolute `https://` link without user name or password, at most 2000 characters |
| `Order` | the field's own order of items on Rows and Columns ("Custom order" in its menu); items not listed follow A to Z | a list of at most 1000 values |
| `Agg`, `Format` | aggregator and format when the field is put into Values (`average`, `number:1`, `currency:EUR`, ...) | names only |
| `DrillFormat` | the format of the field's values in the drill-down: `text` shows an id as it is (40072, not 40,072), `date` a date without its time | a name |
| `Type` | the type the column is read as: `string`, `number`, `date`, `boolean` (numbers that arrive as text, dates as numbers) | one of these |

Anything else throws an error that names the field and the key: an unknown key, a number where text
belongs, an `http://` or `javascript:` link. Two fields with the same label are told apart by their
names in parentheses. The report shows descriptions as text, never as HTML.

Readers can switch the "i" off in **Options**, **Help** ("Show field descriptions"); `-FieldInfo Off`
or `-FieldInfo On` decides it for them, and `-ZoneInfo` does the same for the "i" next to the zone
titles that explains Rows, Columns, Values and Filters.

## -FieldDescriptions and SQL Server column descriptions

`-FieldDescriptions` takes field name to text, for example the descriptions a database already has.
In SQL Server they are the extended property `MS_Description` of each column (what SQL Server
Management Studio shows as a column's Description). `Get-UDPivotSqlColumnDescription` reads them for one
table or view and returns the hashtable `-FieldDescriptions` takes:

```powershell
$connectionString = 'Server=sql01;Database=ServiceDesk;Integrated Security=true;TrustServerCertificate=true'
$tickets = Invoke-Sqlcmd -ConnectionString $connectionString -Query 'SELECT Ticket, Created, Team, Priority, LeadHours FROM dbo.Tickets'
$descriptions = Get-UDPivotSqlColumnDescription -ConnectionString $connectionString -Table 'dbo.Tickets'
New-UDPivotReport -Id 'tickets' -Data $tickets -FieldDescriptions $descriptions
```

With `-ConnectionString` the function opens its own connection with Microsoft.Data.SqlClient when that
is loaded (the SqlServer module loads it), else with System.Data.SqlClient, which PowerShell 7 ships; the
module needs neither to load. `-Connection` takes a connection your app has open already (any ADO.NET
provider for SQL Server) and leaves it open. Put the call where the data is read (the `New-UDDynamic`
of the report, or a cached variable), not into an event.

It sends one query, with the table name as a parameter of `OBJECT_ID()`:

```sql
SELECT c.name AS ColumnName, CAST(ep.value AS nvarchar(4000)) AS Description
FROM sys.columns AS c
INNER JOIN sys.extended_properties AS ep
    ON ep.class = 1 AND ep.major_id = c.object_id AND ep.minor_id = c.column_id AND ep.name = @Name
WHERE c.object_id = OBJECT_ID(@Table)
ORDER BY c.column_id;
```

`sys.extended_properties` has one row per extended property; for class 1 (object or column) `major_id`
is the object's id and `minor_id` the column's id
([sys.extended_properties](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/extended-properties-catalog-views-sys-extended-properties),
[sys.columns](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-columns-transact-sql)).
SQL Server shows an account only the properties of objects it has permissions on; columns without a
description are left out. `-PropertyName` reads another extended property than `MS_Description`.

The same query works without the function, for example with `Invoke-Sqlcmd`: replace `@Table` and
`@Name` with literals you control (never with input from a reader) and turn the rows into a hashtable:

```powershell
$descriptions = @{}
foreach ($row in Invoke-Sqlcmd -ConnectionString $connectionString -Query $query) {
    if ($row.Description -isnot [System.DBNull]) { $descriptions[$row.ColumnName] = $row.Description }
}
```

## -Schema: JSON Schema and OpenAPI

Data from a REST API usually has a schema. `-Schema` reads the row's properties from it: `title`
becomes the label, `description` the description, `externalDocs.url` the link (https only), `type` and
`format` the type (`integer`, `number`, `date`, `date-time`), `enum` the order of the items.

```powershell
# a JSON Schema of one row (or of an array of rows)
New-UDPivotReport -Data $rows -Schema @{ properties = @{ LeadHours = @{ title = 'Lead time (h)'; type = 'number' } } }

# an OpenAPI 3 or Swagger 2 document: -SchemaName names the schema of a row
New-UDPivotReport -Data (Invoke-RestMethod 'https://api.example.com/tickets') -Schema 'https://api.example.com/openapi.json' -SchemaName 'Ticket'
New-UDPivotReport -Data $rows -Schema (Join-Path $Repository 'schemas/tickets.json')
```

`-Schema` takes a hashtable or an object, JSON text, a file path, or an `https://` URL. A URL is
fetched by the server, never by the browser: once per PowerShell runspace every 10 minutes, with a
timeout of 15 seconds and at most 1 MB; other address schemes (`http://`, `file://`) are refused. The
schema must be one JSON object of at most 1 MB and 64 levels. `-SchemaName` is a name in
`components.schemas` (`definitions` in Swagger 2) or a local reference such as
`#/components/schemas/Ticket`.

The server only checks the size and that it is JSON and passes the schema on; pivotkit-core's
`fieldDefaultsFromSchema` reads it in the browser. It follows only references inside the document,
fetches and runs nothing, caps every text, and removes characters that would make a text read as
another (bidi controls, zero-width characters). What it cannot read - a reference to another document,
a cycle, a cap - is left out and named in the browser's console; the report works without it. A large
OpenAPI document travels to the browser with every page: for a big API, save the schema of the row as
a file and pass that.

Next: [Views and templates](views.md), [Events, security and limits](events.md), [Reference](reference.md).
