# Development

The repository builds one PowerShell module per component. Each module is a React component registered
with PSU and a PowerShell function returning the hashtable PSU renders. Code several modules need - the
bridge to PSU's light/dark theme, column matching, number formats, HTML escaping, CSV/Excel export,
text contrast on fills, data conversion - lives once in `shared/` and is compiled into every module, so
component modules never depend on each other at runtime (the demo module requires the chart module).
[AGENTS.md](https://github.com/eizedev/powershell-universal-components/blob/HEAD/AGENTS.md) holds the
layout and the rules that keep modules working inside PSU.

## Build and test

Requires Node.js 22.18 or newer (Babel 8; CI tests the latest 22.x) and PowerShell 7.4+.

```powershell
npm ci; npm test                                   # JavaScript unit tests
./build/Build-Module.ps1 -Module <Module>          # any folder in modules/; output/<Module>/<Version>
Invoke-Pester -Path ./tests/powershell
```

A change to a component is checked on a PSU instance in a browser - light and dark theme, a narrow and a
wide window, the events it fires - before it is called done; unit tests do not cover rendering.

## This site

The pages are Markdown in `docs/`, built with [Zensical](https://zensical.org/) and the shared design of
[eizedev/brand](https://github.com/eizedev/brand). The examples are the single source in
`docs/site/examples.ps1`: `docs/site/Build-Site.ps1` runs each one with the real `New-UDEChart` or
`New-UDPerspective`, writes its code and a placeholder into `docs/site/generated/examples/<id>.md`
(pages include it with `--8<-- "examples/<id>.md"`), the props into `examples.json` and builds
`charts.js`, which draws the modules' own components into the placeholders. The reference comes from
the comment-based help the same way.

```powershell
./docs/site/Build-Site.ps1
uv run --with-requirements <brand>/docs-site/requirements.txt zensical build   # into site/
npx playwright install chromium firefox webkit; npm run test:browser
```

The design's stylesheet comes from eizedev/brand (`docs/assets/site.css`, not committed): copy it from
there for a local build. A new example goes into `examples.ps1` and is included on the page it belongs
to; the build fails for an example that no page includes.

## Browser tests on PSU

```powershell
$env:PSU_URL = '<app url>'; npm run test:browser -- psu   # the showcase app, all three browsers
```

## Adding a module

Name it `PowerShellUniversal.Component.<Name>`, with `New-UD<Name>` and the type `ud-<name>`; reuse
`shared/` instead of copying code; add a README, a CHANGELOG, an example app, tests and its pages here.
Check the license of every library you add: permissive (MIT, Apache-2.0, BSD) and free for companies.

How to contribute: [CONTRIBUTING.md](https://github.com/eizedev/powershell-universal-components/blob/HEAD/CONTRIBUTING.md).
