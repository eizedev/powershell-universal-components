function ConvertTo-UDPivotViewFile {
    <#
    .SYNOPSIS
        A view as a pivotkit view file: the JSON pivotkit's Views menu loads and a template store keeps.
    .DESCRIPTION
        Checks the view with ConvertFrom-UDPivotView and writes the envelope in pivotkit's key order
        ($schema, format, formatVersion, name, description, createdAt, generator, source, extensions,
        view) with a two-space indent and a trailing newline. The format version follows the view: 2 for
        a view of version 2 (what the report sends), 1 for a view of version 1 or without a version, so
        a pivotkit that reads only format 1 still loads the file of an older view.

        A path in -SchemaUrl gets the origin of PSU_COMPONENT_PIVOT_SCHEMA_URL when that is an https
        address. Otherwise it gets the origin the reader's browser used: $Headers of the page, event or
        API endpoint that calls this function (Origin, the page address, Referer). With neither it stops.
    .PARAMETER View
        The view (JSON text, a hashtable or an object).
    .PARAMETER Name
        The view's name (1 to 120 characters of plain text).
    .PARAMETER Description
        More about it, at most 2000 characters.
    .PARAMETER SourceId
        The id of the data the view was made for (New-UDPivotReport -SourceId, default its -Id).
    .PARAMETER SourceName
        The name of that data, for people.
    .PARAMETER SchemaUrl
        The $schema of a file of format 2: an https address of your own copy, a path on PSU such as
        /assets/pivot/schema/view-file-2.json (written with an origin, see the description), or '' to
        leave it out. Default: the environment variable
        PSU_COMPONENT_PIVOT_SCHEMA_URL, else pivotkit's view-file-2.json. A file of format 1 keeps
        pivotkit's view-file-1.json unless the value is ''.
    .PARAMETER CreatedAt
        When it was written (UTC). Without it the file is the same bytes for the same view.
    .EXAMPLE
        ConvertTo-UDPivotViewFile -View $EventData.view -Name 'Open work per team' -SourceId 'tickets'
    .OUTPUTS
        System.String
    .LINK
        https://powershell-universal-components.eize.dev/pivot/templates/
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][AllowNull()][object]$View,
        [Parameter(Mandatory)][string]$Name,
        [AllowEmptyString()][string]$Description,
        [AllowEmptyString()][string]$SourceId,
        [AllowEmptyString()][string]$SourceName,
        [AllowEmptyString()][string]$SchemaUrl,
        [Nullable[datetime]]$CreatedAt
    )
    # -ErrorVariable gets the error itself, not each step it took through the module
    $errorMark = Get-UDPivotErrorMark -Cmdlet $PSCmdlet
    trap { Reset-UDPivotErrorVariable -Mark $errorMark; throw $_ }
    $checked = ConvertFrom-UDPivotView -InputObject $View
    $viewVersion = $checked.PSObject.Properties['version'].Value
    if ($null -ne $viewVersion -and ($viewVersion -ne [math]::Truncate($viewVersion) -or $viewVersion -lt 1 -or $viewVersion -gt $Script:KnownViewVersion)) {
        # the number as written, whatever the culture of the thread (1.5, not 1,5)
        throw ([string]::Format([cultureinfo]::InvariantCulture, 'View file: view version {0} is not one this module writes (1 to {1}).', $viewVersion, $Script:KnownViewVersion))
    }
    $formatVersion = if ($null -ne $viewVersion -and $viewVersion -ge 2) { 2 } else { 1 }
    # an address of your own names the current format's schema; a file of format 1 keeps pivotkit's
    # (#110), and '' leaves $schema out of every format
    $schemaAddress = Get-UDPivotSchemaUrl -SchemaUrl $SchemaUrl -Given:$PSBoundParameters.ContainsKey('SchemaUrl')
    if ($null -eq $schemaAddress -or ($schemaAddress -and $formatVersion -ne $Script:KnownViewVersion)) { $schemaAddress = $Script:ViewFileSchemaUrls[$formatVersion] }
    else { $schemaAddress = Resolve-UDPivotSchemaUrl -SchemaUrl $schemaAddress -Headers $PSCmdlet.SessionState.PSVariable.GetValue('Headers') }
    $file = [ordered]@{}
    if ($schemaAddress) { $file['$schema'] = $schemaAddress }
    $file['format'] = $Script:ViewFileFormat
    $file['formatVersion'] = $formatVersion
    $file['name'] = ConvertTo-UDPivotTemplateName -Name $Name
    $text = Limit-UDPivotText -Text ($Description -replace '[\p{Cc}\p{Cf}]', ' ') -MaxLength $Script:MaxViewFileDescription
    if ($text) { $file['description'] = $text }
    if ($CreatedAt) { $file['createdAt'] = ([datetime]$CreatedAt).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [cultureinfo]::InvariantCulture) }
    $file['generator'] = [ordered]@{ name = 'PowerShellUniversal.Component.Pivot'; version = [string]$Script:ModuleVersion }
    $source = [ordered]@{}
    if ($SourceId) { $source['id'] = Limit-UDPivotText -Text $SourceId -MaxLength $Script:MaxNameLength }
    if ($SourceName) { $source['name'] = Limit-UDPivotText -Text $SourceName -MaxLength $Script:MaxNameLength }
    $file['source'] = $source
    $file['extensions'] = [ordered]@{}
    $file['view'] = $checked
    (ConvertTo-Json -InputObject $file -Depth ($Script:MaxViewDepth + 2)) -replace "`r`n", "`n"
}
