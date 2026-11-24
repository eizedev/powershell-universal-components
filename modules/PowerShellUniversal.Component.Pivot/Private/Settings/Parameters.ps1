# Parameters New-UDPivotReport and New-UDPivotReportPlaceholder share, and the limits of files
# readers load (-AllowImport).
# a CSS length or calc()/clamp()/min()/max(); a bare number is pixels
$Script:HeightPattern = '^\s*(\d+(\.\d+)?(px|vh|svh|dvh|em|rem|%)?|(calc|clamp|min|max)\(.*\))\s*$'
$Script:LocalePattern = '^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*$'
$Script:MissingAssetMessage = 'PowerShellUniversal.Component.Pivot: the JavaScript bundle (index.<hash>.bundle.js) was not found next to the module, or the module was imported outside PowerShell Universal.'

# the keys of pivotkit-core's LIMITS for a loaded file -ImportLimit may set. Their defaults are
# pivotkit's (docs/concepts/limits.md of pivotkit; docs/pivot/import.md lists them). The report sends
# them as pivotkit-react's importLimits, merged over its limits for a loaded file only.
# Components/prepare.js keeps the same list (IMPORT_LIMIT_KEYS)
$Script:ImportLimitKeys = @('fileBytes', 'rows', 'columns', 'importCells', 'textLength', 'archiveEntries', 'unpackedBytes')
# pivotkit takes whole numbers from 1 up to JavaScript's Number.MAX_SAFE_INTEGER
$Script:MaxImportLimit = 9007199254740991
