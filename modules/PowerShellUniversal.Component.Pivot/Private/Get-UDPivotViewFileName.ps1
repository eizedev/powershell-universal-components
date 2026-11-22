function Get-UDPivotViewFileName {
    <#
    .SYNOPSIS
        The file name a template store keeps a view under: <slug>-<hash>.pivotkit.json.
    .DESCRIPTION
        The slug is the name in lower case without accents, every run of other characters a "-" (as
        pivotkit-core's viewFileName), at most 60 characters; the hash (10 hex characters of the SHA-256
        of the source id and the name as it is) keeps two names apart that give the same slug, the same
        name in another case (pivotkit tells names apart by case), and the views of two reports with the
        same name. Nothing of the name can leave the folder. The file name of a new view only: a save over
        a stored view keeps that view's file (Invoke-UDPivotTemplateStore finds it by its name).
    .PARAMETER Name
        The checked template name.
    .PARAMETER SourceId
        The id of the data the view was made for (New-UDPivotReport -SourceId).
    .PARAMETER Attempt
        Another file name for the same name (1, 2, ...), when the first one holds another view.
    .PARAMETER Legacy
        The file name version 0.1.0 gave the view: the hash of the source id and the name in lower case
        (one file for a name in any case). Never the same as a file name of this version.
    .NOTES
        The parts of the hashed text are joined with a NUL character, which a checked name never holds,
        so a file name of this version and one of 0.1.0 (joined with "|") never meet.
    .EXAMPLE
        Get-UDPivotViewFileName -Name 'Revenue by region' -SourceId 'sales'
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string]$Name, [AllowEmptyString()][AllowNull()][string]$SourceId, [ValidateRange(0, 100)][int]$Attempt = 0, [switch]$Legacy)
    $plain = -join ($Name.ToLowerInvariant().Normalize([System.Text.NormalizationForm]::FormKD).ToCharArray() |
            Where-Object { [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne [System.Globalization.UnicodeCategory]::NonSpacingMark })
    $slug = ($plain -replace '[^a-z0-9]+', '-').Trim('-')
    if ($slug.Length -gt 60) { $slug = $slug.Substring(0, 60).Trim('-') }
    if (-not $slug) { $slug = 'view' }
    $text = if ($Legacy) { '{0}|{1}' -f $SourceId, $Name.ToLowerInvariant() }
    else { (@($SourceId, $Name) + @(if ($Attempt) { $Attempt })) -join [char]0 }
    '{0}-{1}.pivotkit.json' -f $slug, (Get-UDPivotSha256 -Text $text -Length 10)
}
