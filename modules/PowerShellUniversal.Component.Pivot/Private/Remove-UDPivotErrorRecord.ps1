function Remove-UDPivotErrorRecord {
    <#
    .SYNOPSIS
        Removes the record of an error the module caught and handled from $Error.
    .DESCRIPTION
        PowerShell adds every caught error to $global:Error. Where the module handles an error of an
        HTTP request or of reading its answer (a failed request, a cut-off answer, a text that is no
        JSON), the caught record would stay there with what it carries: a request with its headers, part
        of an answer. Called first in such a catch block. It removes the newest record only when it is
        this error: catch hands over a copy of the record, so it is found by its exception. Any other
        record (the caller's own, or one that came in between) stays. Never throws.
    .PARAMETER ErrorRecord
        $_ of the catch block.
    .EXAMPLE
        catch { Remove-UDPivotErrorRecord -ErrorRecord $_; throw (New-UDPivotError -Id PivotServerError -Message '...') }
    #>
    # Changes only $Error, the session's list of errors, which no caller asks to confirm
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Management.Automation.ErrorRecord]$ErrorRecord)
    if ($global:Error.Count -and [object]::ReferenceEquals($global:Error[0].Exception, $ErrorRecord.Exception)) { $global:Error.RemoveAt(0) }
}
