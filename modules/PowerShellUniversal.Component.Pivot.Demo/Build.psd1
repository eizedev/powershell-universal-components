# Files the built module carries from elsewhere in the repository, so each is defined once:
# destination below the built module = source below the repository (build/Build-Module.ps1).
# Running from the source tree, the module finds them at their source (Resolve-ShowcasePath).
@{
    Include = @{
        # the pivot examples of the documentation site, shown as pages
        'Apps/Docs/examples.ps1' = 'docs/site/examples.ps1'
        # the snapshots of the public data and their sources and licences (SOURCES.md)
        'Data'                   = 'docs/site/data'
        # the ticket showcase of the pivot module with its view files
        'Apps/Tickets'           = 'modules/PowerShellUniversal.Component.Pivot/examples'
    }
}
