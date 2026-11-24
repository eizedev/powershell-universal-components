function Invoke-UDPivotStoreLock {
    <#
    .SYNOPSIS
        Runs a script block while holding the lock of one store folder or key (a named mutex).
    .PARAMETER Name
        What is locked (a folder, a key).
    .PARAMETER ScriptBlock
        The work.
    .EXAMPLE
        Invoke-UDPivotStoreLock -Name $folder -ScriptBlock { Set-Content -LiteralPath $path -Value $json }
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][scriptblock]$ScriptBlock)
    $mutex = [System.Threading.Mutex]::new($false, ('udpivot-{0}' -f (Get-UDPivotSha256 -Text $Name.ToLowerInvariant() -Length 32)))
    $held = $false
    try {
        try { $held = $mutex.WaitOne([timespan]::FromSeconds($Script:StoreLockTimeoutSec)) }
        catch [System.Threading.AbandonedMutexException] { $held = $true }
        if (-not $held) { throw 'The view store is busy; try again.' }
        & $ScriptBlock
    }
    finally {
        if ($held) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
}
