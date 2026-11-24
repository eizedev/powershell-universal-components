#Requires -Version 7.4
# Adds PSU's Endpoint type (Endpoint.cs) where PSU is not running: the Pester tests and the docs site
# build dot-source this file. Add-Type keeps the first definition in a session, so every caller uses
# this one definition and the result does not depend on the order the test files run in.
if (-not ('Endpoint' -as [type])) {
    Add-Type -TypeDefinition (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Endpoint.cs') -Raw)
}
