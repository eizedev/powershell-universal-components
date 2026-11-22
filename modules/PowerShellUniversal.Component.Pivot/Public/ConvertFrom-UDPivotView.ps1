function ConvertFrom-UDPivotView {
    <#
    .SYNOPSIS
        Checks a pivot view (a report layout) and returns it as a clean object or as compact JSON.
    .DESCRIPTION
        A view is the report as JSON: the fields on Rows, Columns, Values and Filters, sorting, totals,
        the chart. Views come from the browser ($EventData of -OnViewChange and -OnSaveTemplate), from
        files or from a database, so treat them as untrusted input: this function is the check before
        a view is stored or used.

        It accepts a JSON string, a hashtable or a PSCustomObject. The view goes through one round trip
        ConvertTo-Json/ConvertFrom-Json (nothing is evaluated). It must be a JSON object of at most
        -MaxLength characters and at most eight levels deep. Only the keys of a pivotkit view are kept:
        version, rows, cols, values, filters, derived, sort, totals, collapsed, display, chart,
        formatting and fieldLabels. The checks:

        - rows and cols: lists of at most 64 field names.
        - values, filters, derived and sort: lists of at most 64 objects.
        - display: "table", "chart" or "both", in lower case.
        - fieldLabels: the report's own names for fields, an object of at most 1000 field names, each
          with a text of 1 to 256 characters (an empty field name is no valid JSON here).

        Anything else throws an error that says what is wrong. Filters pass as they are, of view version
        2 (in, blank, text, compare, relative, top, value with not and blanks) and of version 1 (include,
        exclude, label), which the report migrates. The report itself checks every field name and setting
        against the data again (pivotkit-core's normalize) and drops what does not fit.
    .PARAMETER InputObject
        The view: a JSON string, a hashtable or a PSCustomObject (e.g. $EventData.view).
    .PARAMETER MaxLength
        The longest view accepted, in characters of compact JSON. Default: 65536.
    .PARAMETER AsJson
        Return the view as compact JSON (for a file or a database column) instead of an object.
    .EXAMPLE
        $view = ConvertFrom-UDPivotView -InputObject $EventData.view
    .EXAMPLE
        Set-Content -LiteralPath $path -Value (ConvertFrom-UDPivotView -InputObject $EventData.json -AsJson)
    .EXAMPLE
        ConvertFrom-UDPivotView '{"rows":["Team"],"values":[{"field":"Hours","agg":"sum"}]}'
    .OUTPUTS
        System.Management.Automation.PSCustomObject, or System.String with -AsJson.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject], [string])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)][AllowNull()][object]$InputObject,
        [ValidateRange(256, 1MB)][int]$MaxLength = $Script:MaxViewLength,
        [switch]$AsJson
    )
    process {
        # -ErrorVariable gets the error itself, not each step it took through the module
        $errorMark = Get-UDPivotErrorMark -Cmdlet $PSCmdlet
        trap { Reset-UDPivotErrorVariable -Mark $errorMark; throw $_ }
        if ($null -eq $InputObject) { throw 'Pivot view: no view (null).' }
        if ($InputObject -is [string]) {
            $json = $InputObject.Trim()
        }
        else {
            # deeper than a view can be: ConvertTo-Json cuts it off with a warning, ConvertFrom-Json then sees
            # the cut-off levels as strings and the shape check below refuses them
            $json = ConvertTo-Json -InputObject $InputObject -Depth ($Script:MaxViewDepth + 1) -Compress -WarningAction SilentlyContinue
        }
        if ($json.Length -gt $MaxLength) { throw ('Pivot view: {0} characters, more than the {1} allowed.' -f $json.Length, $MaxLength) }
        try {
            $parsed = ConvertFrom-Json -InputObject $json -Depth $Script:MaxViewDepth -NoEnumerate
        }
        catch {
            throw ('Pivot view: not valid JSON of at most {0} levels ({1})' -f $Script:MaxViewDepth, $_.Exception.Message)
        }
        if ($parsed -isnot [System.Management.Automation.PSCustomObject]) { throw 'Pivot view: expected a JSON object.' }

        $view = [ordered]@{}
        foreach ($property in $parsed.PSObject.Properties) {
            $key = $Script:ViewKeys.Keys | Where-Object { $_ -eq $property.Name } | Select-Object -First 1
            if (-not $key) { continue }
            $value = $property.Value
            if ($null -eq $value) { continue }
            switch ($Script:ViewKeys[$key]) {
                'number' {
                    if ($value -isnot [long] -and $value -isnot [int] -and $value -isnot [double]) { throw ('Pivot view: {0} must be a number.' -f $key) }
                }
                'string' {
                    if ($value -isnot [string] -or $value -cnotin $Script:DisplayModes) { throw ('Pivot view: {0} must be "table", "chart" or "both".' -f $key) }
                }
                'object' {
                    if ($value -isnot [System.Management.Automation.PSCustomObject]) { throw ('Pivot view: {0} must be an object.' -f $key) }
                }
                'labels' {
                    # names of the report's own for fields (pivotkit-core's view.fieldLabels): field name -> text
                    if ($value -isnot [System.Management.Automation.PSCustomObject]) { throw ('Pivot view: {0} must be an object of field names and their names.' -f $key) }
                    $names = @($value.PSObject.Properties)
                    if ($names.Count -gt $Script:MaxFields) { throw ('Pivot view: {0} must name at most {1} fields.' -f $key, $Script:MaxFields) }
                    foreach ($name in $names) {
                        $text = $name.Value
                        # an empty field name never gets here: ConvertFrom-Json refuses it; pivotkit trims the text
                        if ($name.Name.Length -gt $Script:MaxNameLength -or $text -isnot [string] -or $text.Trim().Length -lt 1 -or $text.Trim().Length -gt $Script:MaxNameLength) {
                            throw ('Pivot view: {0} must name each field with a text of 1 to {1} characters.' -f $key, $Script:MaxNameLength)
                        }
                    }
                }
                'names' {
                    $list = @($value)
                    if ($value -isnot [array] -or $list.Count -gt $Script:MaxListLength) { throw ('Pivot view: {0} must be a list of at most {1} field names.' -f $key, $Script:MaxListLength) }
                    foreach ($name in $list) {
                        if ($name -isnot [string] -or $name.Length -gt $Script:MaxNameLength) { throw ('Pivot view: {0} must hold field names (text of at most {1} characters).' -f $key, $Script:MaxNameLength) }
                    }
                    $value = [string[]]$list
                }
                'objects' {
                    $list = @($value)
                    if ($value -isnot [array] -or $list.Count -gt $Script:MaxListLength) { throw ('Pivot view: {0} must be a list of at most {1} entries.' -f $key, $Script:MaxListLength) }
                    foreach ($entry in $list) {
                        if ($entry -isnot [System.Management.Automation.PSCustomObject]) { throw ('Pivot view: every entry of {0} must be an object.' -f $key) }
                    }
                    $value = [object[]]$list
                }
            }
            $view[$key] = $value
        }
        $result = [pscustomobject]$view
        if ($AsJson) { return ConvertTo-Json -InputObject $result -Depth $Script:MaxViewDepth -Compress }
        $result
    }
}
