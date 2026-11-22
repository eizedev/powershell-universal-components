# Limits of a view: what ConvertFrom-UDPivotView and the commands that take a view accept.
# The keys of a pivotkit view (pivotkit-core's View); ConvertFrom-UDPivotView keeps only these.
$Script:ViewKeys = @{
    version     = 'number'
    rows        = 'names'
    cols        = 'names'
    values      = 'objects'
    filters     = 'objects'
    derived     = 'objects'
    sort        = 'objects'
    totals      = 'object'
    collapsed   = 'object'
    display     = 'string'
    chart       = 'object'
    formatting  = 'object'
    fieldLabels = 'labels'
}
# pivotkit-core's DISPLAY_MODES
$Script:DisplayModes = @('table', 'chart', 'both')
# a view as JSON is a few kilobytes; this leaves room for long filter lists
$Script:MaxViewLength = 64KB
# nesting of a view: values[].conditional.colors, collapsed.rows[][] - four levels
$Script:MaxViewDepth = 8
$Script:MaxListLength = 64
$Script:MaxNameLength = 256
