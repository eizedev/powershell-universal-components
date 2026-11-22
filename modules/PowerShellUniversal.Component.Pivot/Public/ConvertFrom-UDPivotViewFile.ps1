function ConvertFrom-UDPivotViewFile {
    <#
    .SYNOPSIS
        Reads a pivotkit view file (or a saved view { name, view }) and returns its name, description,
        source and checked view.
    .DESCRIPTION
        A view file is the JSON pivotkit's Views menu downloads (Download view, Copy view as JSON) and a
        template store keeps: format "pivotkit-view", formatVersion 1 or 2, name, description, source and
        the view. This function reads one as untrusted input: at most 1,000,000 characters and 16 levels,
        parsed without evaluating anything; a newer formatVersion or view version (above 2) is refused
        (saving it again would lose what the newer version added); a view of version 1 is read as it is
        and migrated to version 2 by the report; the name becomes plain text of 1 to 120
        characters; the view goes through ConvertFrom-UDPivotView. An object { name, view } (a saved view
        as an app keeps it) is read as well; a bare view needs -Name.
    .PARAMETER InputObject
        The view file: JSON text, a hashtable or an object.
    .PARAMETER Name
        The name of a view file that has none (a bare view), such as the file's name.
    .EXAMPLE
        ConvertFrom-UDPivotViewFile -InputObject (Get-Content -LiteralPath ./open-work.pivotkit.json -Raw)
    .OUTPUTS
        System.Management.Automation.PSCustomObject with Name, Description, Source (id, name), Generator
        (name, version: what wrote the file) and View.
    .LINK
        https://powershell-universal-components.eize.dev/pivot/templates/
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)][AllowNull()][object]$InputObject,
        [string]$Name
    )
    process {
        # -ErrorVariable gets the error itself, not each step it took through the module
        $errorMark = Get-UDPivotErrorMark -Cmdlet $PSCmdlet
        trap { Reset-UDPivotErrorVariable -Mark $errorMark; throw $_ }
        if ($null -eq $InputObject) { throw 'View file: no content (null).' }
        $json = if ($InputObject -is [string]) { $InputObject.Trim() } else {
            ConvertTo-Json -InputObject $InputObject -Depth ($Script:MaxViewFileDepth + 1) -Compress -WarningAction SilentlyContinue
        }
        $json = Test-UDPivotJsonText -Text $json -Name 'View file' -MaxLength $Script:MaxViewFileLength -MaxDepth $Script:MaxViewFileDepth
        $file = ConvertFrom-Json -InputObject $json -Depth $Script:MaxViewFileDepth -NoEnumerate
        # keys in any case: an object from PowerShell has Name and View
        $get = { param($Key) $p = $file.PSObject.Properties | Where-Object { $_.Name -eq $Key } | Select-Object -First 1; if ($p) { , $p.Value } }

        $isFile = (& $get 'format') -ceq $Script:ViewFileFormat
        if ($isFile) {
            $version = & $get 'formatVersion'
            $newest = ($Script:KnownViewFileVersions | Measure-Object -Maximum).Maximum
            if ($null -ne $version -and -not (($version -is [int] -or $version -is [long]) -and $version -in $Script:KnownViewFileVersions)) {
                if (($version -is [int] -or $version -is [long] -or $version -is [double] -or $version -is [decimal]) -and $version -gt $newest) {
                    throw ('View file: format version {0} is newer than this module reads ({1}); update PowerShellUniversal.Component.Pivot.' -f $version, $newest)
                }
                throw ('View file: formatVersion must be one of {0}.' -f ($Script:KnownViewFileVersions -join ', '))
            }
        }
        $view = & $get 'view'
        if ($null -eq $view) {
            # a bare view: the whole document is the view
            if ($isFile) { throw 'View file: no view.' }
            $view = $file
        }
        $viewVersion = if ($view -is [System.Management.Automation.PSCustomObject]) { $view.PSObject.Properties['version'].Value }
        if (($viewVersion -is [int] -or $viewVersion -is [long] -or $viewVersion -is [double]) -and $viewVersion -gt $Script:KnownViewVersion) {
            throw ('View file: view version {0} is newer than this module reads ({1}); update PowerShellUniversal.Component.Pivot.' -f $viewVersion, $Script:KnownViewVersion)
        }
        $checked = ConvertFrom-UDPivotView -InputObject $view

        $title = & $get 'name'
        if ($title -isnot [string] -or [string]::IsNullOrWhiteSpace($title)) { $title = $Name }
        $description = & $get 'description'
        $source = & $get 'source'
        $generator = & $get 'generator'
        [pscustomobject]@{
            Name        = ConvertTo-UDPivotTemplateName -Name $title
            Description = if ($description -is [string]) { Limit-UDPivotText -Text ($description -replace '[\p{Cc}\p{Cf}]', ' ') -MaxLength $Script:MaxViewFileDescription }
            Source      = if ($source -is [System.Management.Automation.PSCustomObject]) {
                [pscustomobject]@{
                    id   = if ($source.id -is [string]) { Limit-UDPivotText -Text $source.id -MaxLength $Script:MaxNameLength }
                    name = if ($source.name -is [string]) { Limit-UDPivotText -Text $source.name -MaxLength $Script:MaxNameLength }
                }
            }
            Generator   = if ($generator -is [System.Management.Automation.PSCustomObject]) {
                [pscustomobject]@{
                    name    = if ($generator.name -is [string]) { Limit-UDPivotText -Text $generator.name -MaxLength $Script:MaxNameLength }
                    version = if ($generator.version -is [string]) { Limit-UDPivotText -Text $generator.version -MaxLength 40 }
                }
            }
            View        = $checked
        }
    }
}
