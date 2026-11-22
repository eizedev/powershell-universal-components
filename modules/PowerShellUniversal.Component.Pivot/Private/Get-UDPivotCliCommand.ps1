function Get-UDPivotCliCommand {
    <#
    .SYNOPSIS
        How to start pivotkit's command line: the program and the arguments before pivotkit's own.
    .DESCRIPTION
        -CliPath, else the command pivotkit on the PATH (npm install --global pivotkit-cli). A .js file
        runs with node. On Windows npm installs pivotkit.cmd, a batch file that would pass every argument
        through cmd.exe's quoting: the function runs the package's bin/pivotkit.js next to it with node
        instead.
    .PARAMETER CliPath
        The pivotkit program or its bin/pivotkit.js.
    .EXAMPLE
        Get-UDPivotCliCommand -CliPath '/usr/local/bin/pivotkit'
    .OUTPUTS
        System.Management.Automation.PSCustomObject with FileName and Arguments.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([AllowEmptyString()][string]$CliPath)
    $path = if ($CliPath) {
        if (-not (Test-Path -LiteralPath $CliPath -PathType Leaf)) { throw (New-UDPivotError -Id PivotCliNotFound -Category ObjectNotFound -Message ('-CliPath "{0}": no such file.' -f $CliPath)) }
        (Resolve-Path -LiteralPath $CliPath).ProviderPath
    }
    else {
        $found = Get-Command -Name 'pivotkit' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $found) { throw (New-UDPivotError -Id PivotCliNotFound -Category ObjectNotFound -Message 'pivotkit''s command line was not found: install it with "npm install --global pivotkit-cli" (Node 24 or later; Node 22 for pivotkit-cli 0.4 and older) on the PSU server, or pass -CliPath.') }
        $found.Source
    }
    if ($path -match '\.(cmd|bat|ps1)$') {
        # npm's shims sit next to node_modules/pivotkit-cli
        $js = Join-Path (Split-Path -Parent $path) 'node_modules' 'pivotkit-cli' 'bin' 'pivotkit.js'
        if (-not (Test-Path -LiteralPath $js -PathType Leaf)) { throw (New-UDPivotError -Id PivotCliNotFound -Category ObjectNotFound -Message ('"{0}" is a script shim; pass -CliPath with pivotkit-cli''s bin/pivotkit.js.' -f $path)) }
        $path = $js
    }
    if ($path -match '\.(js|mjs)$') {
        $node = Get-Command -Name 'node' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $node) { throw (New-UDPivotError -Id PivotCliNotFound -Category ObjectNotFound -Message 'node was not found: pivotkit''s command line needs Node 24 or later (Node 22 for pivotkit-cli 0.4 and older) on the PSU server.') }
        return [pscustomobject]@{ FileName = $node.Source; Arguments = @($path) }
    }
    [pscustomobject]@{ FileName = $path; Arguments = @() }
}
