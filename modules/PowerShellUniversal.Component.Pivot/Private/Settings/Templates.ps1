# Templates: view files, template folders and template stores.
# pivotkit's view file (pivotkit-core's VIEW_FILE_LIMITS, VIEW_FILE_SCHEMA, VIEW_VERSION): format version
# 2 carries views of version 2, format 1 views of version 1; both are read, and a view without a version
# is version 1 (pivotkit migrates it to version 2 when it reads it)
$Script:ViewFileFormat = 'pivotkit-view'
$Script:ViewFileSchemaUrls = @{
    1 = 'https://pivotkit.eize.dev/schema/view-file-1.json'
    2 = 'https://pivotkit.eize.dev/schema/view-file-2.json'
}
$Script:KnownViewFileVersions = @(1, 2)
# the $schema a view file names (-SchemaUrl, or the module-wide default below): an https address, a
# path on the instance (/assets/pivot/schema/view-file-2.json: the browser puts its origin in front, a
# writer on the server the origin of an https default, else of the request), or '' for none. One check for every command (#110).
# The default is an environment variable of the PSU process: set once, it reaches the page, the event
# handlers' runspaces and every job. The module already reads the host's environment for defaults
# ($env:TZ, $env:Data__RepositoryPath); this is the first variable of its own.
$Script:SchemaUrlDefaultVariable = 'PSU_COMPONENT_PIVOT_SCHEMA_URL'
$Script:MaxSchemaUrlLength = 2000
$Script:SchemaUrlExample = '/assets/pivot/schema/view-file-2.json'
# an https address without user name or password (the scheme in any case), or a path that starts with
# one "/" (never "//" or "/\", which a browser reads as another host). The browser keeps the same rule
# in Components/prepare.js (schemaUrlOf).
$Script:SchemaUrlPattern = '^((?i:https)://[^\s/?#@\\]+([/?#]\S*)?|/(?![/\\])\S*)$'
# an address a request names (Origin, the page address, Referer): http or https, a host and a port
$Script:RequestAddressPattern = '^https?://(\[[0-9A-Fa-f:.]+\]|[A-Za-z0-9.-]+)(:\d{1,5})?([/?#]\S*)?$'
# the headers that carry the address the reader's browser used, in this order: an event's Origin, the
# page address PSU's client sends with a page (windowLocation), the Referer (measured on PSU 2026.3.4)
$Script:RequestAddressHeaders = @('Origin', 'windowLocation', 'Referer')
$Script:MaxViewFileLength = 1000000
$Script:MaxViewFileDepth = 16
$Script:MaxViewFileDescription = 2000
$Script:KnownViewVersion = 2
# a template's name in the Views menu (pivotkit-react's save field takes 120 characters)
$Script:MaxTemplateNameLength = 120
# what a reader reads when the store fails for a reason of the server (a folder it cannot write): the
# reason itself goes to the app's log, since it holds paths (Invoke-UDPivotTemplateRequest)
$Script:StoreFailedText = 'The server could not change the views. The app''s log says why; ask the app''s owner.'
# templates the report gets in all (pivotkit-core's TEMPLATE_LIMITS.count)
$Script:MaxTemplates = 500
# the default caps of a template store
$Script:DefaultMaxUserViews = 50
$Script:DefaultMaxSharedViews = 200
$Script:StoreLockTimeoutSec = 10
# the stores of the reports, for the event handlers the module registers for them: PSU runs a handler
# in a runspace of its own, which does not see the module's state of the page's runspace, but the same
# process. Process-wide, keyed by a hash of the app, the report and its settings.
$Script:StoreRegistryName = 'PowerShellUniversal.Component.Pivot.TemplateStores'
$Script:MaxStoreRegistryEntries = 1000
$Script:ModuleVersion = (Import-PowerShellDataFile -LiteralPath (Join-Path $PSScriptRoot '..' '..' 'PowerShellUniversal.Component.Pivot.psd1')).ModuleVersion
