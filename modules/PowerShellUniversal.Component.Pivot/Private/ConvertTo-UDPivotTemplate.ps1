function ConvertTo-UDPivotTemplate {
    <#
    .SYNOPSIS
        Checks the entries of -Templates and returns them as name, view, scope and deletable.
    .DESCRIPTION
        Used by New-UDPivotReport. An entry is a hashtable or an object with Name (plain text, 1 to 120
        characters), View (as ConvertFrom-UDPivotView accepts it) or File (a pivotkit view file as text
        or object, read by ConvertFrom-UDPivotViewFile; its name is the default of Name), Scope (shared or
        user; without it a Deletable entry is the reader's own, every other one shared, as in pivotkit)
        and Deletable. A wrong entry throws an error that names it.
    .PARAMETER Template
        The entries.
    .EXAMPLE
        ConvertTo-UDPivotTemplate -Template @(@{ Name = 'Per team'; View = @{ rows = @('Team') } })
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([AllowEmptyCollection()][object[]]$Template)

    $index = 0
    foreach ($entry in $Template) {
        $index++
        if ($null -eq $entry) { continue }
        $name = Get-UDPivotEntryValue -InputObject $entry -Name 'Name'
        $file = Get-UDPivotEntryValue -InputObject $entry -Name 'File'
        $label = if ($name -is [string] -and $name.Trim()) { $name } else { 'entry {0}' -f $index }
        try {
            if ($null -ne $file) {
                $read = ConvertFrom-UDPivotViewFile -InputObject $file -Name $name
                $view = $read.View
                if (-not ($name -is [string] -and $name.Trim())) { $name = $read.Name }
            }
            else {
                $view = ConvertFrom-UDPivotView -InputObject (Get-UDPivotEntryValue -InputObject $entry -Name 'View')
            }
            $name = ConvertTo-UDPivotTemplateName -Name $name
        }
        catch {
            throw ('-Templates, "{0}": {1}' -f $label, $_.Exception.Message)
        }
        $deletable = [bool](Get-UDPivotEntryValue -InputObject $entry -Name 'Deletable')
        $scope = [string](Get-UDPivotEntryValue -InputObject $entry -Name 'Scope')
        # pivotkit's rule without a scope: a deletable entry is the reader's own, every other one shared
        if (-not $scope) { $scope = if ($deletable) { 'user' } else { 'shared' } }
        if ($scope -notin 'shared', 'user') { throw ('-Templates, "{0}": Scope must be shared or user.' -f $name) }
        [pscustomobject]@{ name = $name; view = $view; scope = $scope.ToLowerInvariant(); deletable = $deletable }
    }
}
