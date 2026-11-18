# Files the built module carries from elsewhere in the repository, so each is defined once:
# destination below the built module = source below the repository (build/Build-Module.ps1).
@{
    Include = @{
        # pivotkit-core's JSON schemas of the view file and the view (view-file-1.json, view-file-2.json,
        # view-2.json), from the installed package: the version the bundle is built from, for a host
        # that publishes its own copy (-SchemaUrl)
        'schema' = 'modules/PowerShellUniversal.Component.Pivot/node_modules/pivotkit-core/schema'
    }
}
