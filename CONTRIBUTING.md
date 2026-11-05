# Contributing

Thanks for helping. Bug reports and ideas go into [issues](https://github.com/eizedev/powershell-universal-components/issues),
questions into [discussions](https://github.com/eizedev/powershell-universal-components/discussions),
security reports privately (see [SECURITY.md](SECURITY.md)).

## Changes

1. Fork, create a branch named after the change (`feat/...`, `fix/...`, `docs/...`).
2. Follow [AGENTS.md](AGENTS.md): layout, commands and the rules that keep modules working inside PSU.
3. Run the tests (`npm test`, `Invoke-Pester -Path tests/powershell`) and build the module you changed.
4. Check the change on a PSU instance in a browser: light and dark theme, a narrow and a wide window.
5. Add an entry under `[Unreleased]` in the module's `CHANGELOG.md`.
6. Open a pull request with a short description and what you tested; use Conventional Commits.

## Adding a module

Name it `PowerShellUniversal.Component.<Name>`, with `New-UD<Name>` and the type `ud-<name>`; reuse
`shared/` instead of copying code; add a README, a CHANGELOG, an example app and tests. Check the
license of every library you add: permissive (MIT, Apache-2.0, BSD) and free for companies.
