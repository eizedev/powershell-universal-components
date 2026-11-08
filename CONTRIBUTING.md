# Contributing

Thanks for helping. Bug reports and ideas go into [issues](https://github.com/eizedev/powershell-universal-components/issues),
questions into [discussions](https://github.com/eizedev/powershell-universal-components/discussions),
security reports privately (see [SECURITY.md](SECURITY.md)).

## Changes

1. Fork, create a branch named after the change (`feat/...`, `fix/...`, `docs/...`).
2. Follow [AGENTS.md](AGENTS.md): layout, commands and the rules that keep modules working inside PSU.
3. Run the tests (`npm test`, `npm run test:browser` after building the docs site, `Invoke-Pester -Path tests/powershell`) and build the module you changed.
4. Check the change on a PSU instance in a browser: light and dark theme, a narrow and a wide window.
5. Add an entry under `[Unreleased]` in the module's `CHANGELOG.md`.
6. Open a pull request with a short description and what you tested; use Conventional Commits.

## Adding a module

Name it `PowerShellUniversal.Component.<Name>`, with `New-UD<Name>` and the type `ud-<name>`; reuse
`shared/` instead of copying code; add a README, a CHANGELOG, an example app and tests. Check the
license of every library you add: permissive (MIT, Apache-2.0, BSD) and free for companies.

## Releasing a module (maintainers)

Once per repository: Settings > Environments > `psgallery` with yourself as required reviewer and
deployment tags `*-v*`; in that environment (never as a repository secret) the secret
`PSGALLERY_API_KEY`, a gallery key scoped to the repository's module names. When the repository is
public, a ruleset lets only maintainers create `*-v*` tags.

1. In the module's `CHANGELOG.md`, move the entries from `[Unreleased]` to `## [x.y.z] - YYYY-MM-DD`;
   set `ModuleVersion` in the manifest to `x.y.z`. Merge that pull request.
2. Tag the merge commit on `main`: `git tag <Module>-vx.y.z && git push origin <Module>-vx.y.z`. A tag on
   a commit that is not on `main` stops the workflow before anything is built.
3. The workflow `release.yml` tests, builds and checks the module, then waits for approval in the
   environment `psgallery`; after it, it publishes to the PowerShell Gallery and creates the GitHub
   release with the zip and the CHANGELOG section.

"Run workflow" on `release.yml` with a tag name checks a release without publishing anything. A module
that requires another one (a demo requires its component module) is released after it: the gallery checks that
the required version is there.
