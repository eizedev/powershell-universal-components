# Limits of field descriptions, schemas and chart options, and the tips a report may show.
# the caps of pivotkit (pivotkit-core's SCHEMA_CAPS): longer texts are cut here already, so a prop
# never carries more than the report would show
$Script:MaxFields = 1000
$Script:MaxLabelLength = 120
$Script:MaxDescriptionLength = 1000
$Script:MaxHrefLength = 2000
$Script:MaxOrderLength = 1000
$Script:FieldDefaultKeys = [ordered]@{
    Agg         = 'agg'
    Format      = 'format'
    DrillFormat = 'drillFormat'
    Label       = 'label'
    Description = 'description'
    Href        = 'href'
    Order       = 'order'
    Type        = 'type'
}
$Script:FormatNamePattern = '^[A-Za-z0-9:._%-]{1,64}$'
# a schema or the field defaults as JSON: the browser refuses longer ones too (prepare.js)
$Script:MaxSchemaLength = 1MB
$Script:MaxSchemaDepth = 64
$Script:SchemaTimeoutSec = 15
# a schema fetched from a URL is kept this long per PowerShell runspace, so a page does not fetch it on
# every render
$Script:SchemaCacheMinutes = 10
$Script:SchemaCache = @{}
$Script:MaxChartOptionsLength = 64KB
$Script:MaxChartOptionsDepth = 16
# the tips pivotkit-react can show (its TIP_IDS, in its spelling: it compares them case-sensitively). The
# notices filterEmpty, top and chartCapped always show and are no tips. tests/powershell/Build-Module.Tests.ps1
# compares this list with the installed pivotkit-react.
$Script:TipIds = @('showAs', 'colSubtotals', 'chartOverTime', 'pieSlices', 'stackedTotal', 'pieColumns', 'chartDates', 'chartTrend', 'chartSeries', 'textValue', 'dateUngrouped', 'manyColumns', 'afterDrag', 'values', 'saveTemplate', 'menus', 'cells')
# the descriptions of a table's columns: sys.extended_properties class 1 (object or column), major_id the
# object_id, minor_id the column_id (sys.extended_properties and sys.columns on Microsoft Learn)
$Script:SqlColumnDescriptionQuery = @'
SELECT c.name AS ColumnName, CAST(ep.value AS nvarchar(4000)) AS Description
FROM sys.columns AS c
INNER JOIN sys.extended_properties AS ep
    ON ep.class = 1 AND ep.major_id = c.object_id AND ep.minor_id = c.column_id AND ep.name = @Name
WHERE c.object_id = OBJECT_ID(@Table)
ORDER BY c.column_id;
'@
