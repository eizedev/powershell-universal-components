function Clear-UDPivotStoredCopy {
    <#
    .SYNOPSIS
        Takes views out of every place they may be stored but -Keep, never out of a place another view
        may be in.
    .DESCRIPTION
        Removes a view of a name that was stored twice (a copy; the place version 0.1.0 gave it). Some of
        these places are guesses (a custom store without FileName), so a failed delete there is a
        warning; with -Strict (Delete) a view of which no place could be deleted is an error the reader
        sees.
    .PARAMETER Context
        The result of New-UDPivotStoreContext.
    .PARAMETER Found
        The views to take out (Select-UDPivotNamedView).
    .PARAMETER All
        Every stored view of the scope (Get-UDPivotStoredView).
    .PARAMETER Name
        The views' name, for the warning.
    .PARAMETER Keep
        A file name to leave: the one a save just wrote.
    .PARAMETER Strict
        Throw when no place of a view could be deleted.
    .EXAMPLE
        Clear-UDPivotStoredCopy -Context $context -Found $found -All $all -Name 'Sales' -Keep 'sales.pivotkit.json'
    .OUTPUTS
        None.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)][pscustomobject]$Context,
        [AllowEmptyCollection()][object[]]$Found,
        [AllowEmptyCollection()][object[]]$All,
        [Parameter(Mandatory)][string]$Name,
        [AllowEmptyString()][string]$Keep,
        [switch]$Strict
    )
    $claimed = @($All | Where-Object { $Found -notcontains $_ } | ForEach-Object { $_.Files })
    $done = @{}
    foreach ($entry in $Found) {
        $failed = $null
        $removed = 0
        foreach ($file in @($entry.Files | Where-Object { $_ -ne $Keep -and $claimed -notcontains $_ })) {
            if ($done.ContainsKey($file)) { $removed++; continue }
            try { Remove-UDPivotStoredFile -Context $Context -FileName $file; $done[$file] = $true; $removed++ }
            catch { if (-not $failed) { $failed = $_ } }
        }
        if ($failed) {
            if ($Strict -and -not $removed) { throw $failed }
            Write-Warning ('Pivot template store: "{0}" could not be removed from one place: {1}' -f $Name, $failed.Exception.Message)
        }
    }
}
