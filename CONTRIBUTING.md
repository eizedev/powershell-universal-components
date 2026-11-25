# Contributing

Thanks for helping. Bug reports and concrete feature requests go into [issues](https://github.com/eizedev/powershell-universal-components/issues),
questions and ideas into [discussions](https://github.com/eizedev/powershell-universal-components/discussions),
security reports privately (see [SECURITY.md](SECURITY.md)).

## Changes

1. Fork, create a branch named after the change (`feat/...`, `fix/...`, `docs/...`).
2. Follow [AGENTS.md](AGENTS.md): layout, commands and the rules that keep modules working inside PSU.
3. A new page in `docs/` goes into the `nav` of `zensical.toml` and into one section of
   `[project.plugins.llmstxt.sections]` there (`tests/js/llms-sections.test.js` checks it).
4. Run the tests (`npm test`, `npm run test:browser` after building the docs site, `Invoke-Pester -Path tests/powershell`) and build the module you changed.
5. Check the change on a PSU instance in a browser: light and dark theme, a narrow and a wide window.
6. Add an entry under `[Unreleased]` in the module's `CHANGELOG.md`.
7. Open a pull request with a short description and what you tested; use Conventional Commits.

## Adding a module

Name it `PowerShellUniversal.Component.<Name>`, with `New-UD<Name>` and the type `ud-<name>`. Reuse
`shared/` instead of copying code. Check the licence of every library you add: permissive (MIT,
Apache-2.0, BSD) and free for companies. A new module needs:

- a README, a CHANGELOG, an example app and tests
- an entry in the build matrix of `.github/workflows/ci.yml` (`tests/js/ci.test.js` checks it)
- its pages in `nav` and in one `llmstxt` section of `zensical.toml`
- a link on the docs start page and in the root README

## Releasing a module (maintainers)

The steps and the one-time setup are in [Releases](docs/development/release.md).
