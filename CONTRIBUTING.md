# Contributing

Thanks for helping.

- Bug reports and concrete feature requests go into [issues](https://github.com/eizedev/powershell-universal-components/issues).
- Questions and ideas go into [discussions](https://github.com/eizedev/powershell-universal-components/discussions).
- Security reports go privately, see [SECURITY.md](SECURITY.md).
- Everyone follows the [Code of Conduct](CODE_OF_CONDUCT.md).

## Before you start

- Read [PRODUCT.md](PRODUCT.md): what the modules are, for whom, and what they are not.
- A new feature starts as an issue that says what problem it solves and for whom.
- [AGENTS.md](AGENTS.md) holds the layout, the commands and the rules that keep modules working inside PSU.
- Node.js and PowerShell 7.4+ in the versions [Development](docs/development/index.md#build-and-test) names.

## Make a change

1. Fork the repository and create a branch named after the change: `feat/...`, `fix/...` or `docs/...`.
2. For a fix, write the test first (see [Tests](#tests)).
3. Run the checks below.
4. Update the pages in `docs/` and add an entry under `[Unreleased]` in the `CHANGELOG.md` of each
   module you changed.
5. Open a pull request. Use Conventional Commits with the module as scope: `fix(pivot): ...`.

## Check your change

Every change, from the repository root:

```bash
npm ci
npm run lint
npm test
npm run growth
pwsh ./build/Invoke-ScriptAnalysis.ps1
pwsh -c 'Invoke-Pester -Path tests/powershell'
```

When `npm run growth` reports that something shrank, lower the baseline in the same pull request with
`node build/growth.js --update`.

Then, depending on what you changed:

| You changed | Also run |
| --- | --- |
| a component (`Components/`) | `./build/Build-Module.ps1 -Module <Module>`, then check it on a PSU instance: light and dark theme, a narrow and a wide window, the events it fires |
| `shared/` | build every module that uses it; each gets a `CHANGELOG.md` entry |
| the pivot module's packages | `npm ci` in its folder first: some unit tests skip without them |
| a page or an example in `docs/` | `pwsh ./docs/site/Build-Site.ps1`, build the site and `npm run test:browser` ([Development](docs/development/index.md#this-site)); a new page goes into `nav` and one `llmstxt` section of `zensical.toml` |
| a showcase app or a demo module | the browser tests on PSU ([Development](docs/development/index.md#browser-tests-on-psu)) |
| a `package.json` or lock file | `npm audit --audit-level=high` in that folder |

## Tests

- A fix comes with a test that fails without it: watch it fail, then fix the code.
- Never weaken, skip or delete a test to get green. If a test fails, say in the pull request whether
  the code or the test was wrong.
- Logic goes into plain `.js` modules tested with `node --test` in `tests/js/`, PowerShell into Pester
  tests in `tests/powershell/`. Rendering needs a browser: a Playwright test in `tests/browser/`.

## Dependencies

- Check the licence of every library you add: permissive (MIT, Apache-2.0, BSD) and free for companies.
- Pin every package to an exact version and commit the lock file.
- Prefer a small own wrapper over a wrapper package.
- Never bundle React, ReactDOM or `UniversalDashboard`: PSU provides them ([AGENTS.md](AGENTS.md#rules-that-matter-here)).

## Adding a module

Name it `PowerShellUniversal.Component.<Name>`, with `New-UD<Name>` and the type `ud-<name>`. Reuse
`shared/` instead of copying code. A new module needs:

- a README, a CHANGELOG, an example app and tests
- an entry in the build matrix of `.github/workflows/ci.yml` (`tests/js/ci.test.js` checks it)
- its pages in `nav` and in one `llmstxt` section of `zensical.toml`
- a link on the docs start page and in the root README

## Releasing a module

Maintainers release each module on its own. The checklist and the one-time setup are in
[Releases](docs/development/release.md).
