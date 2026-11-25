# Security policy

## Scope

The PowerShell modules and JavaScript bundles in this repository, the demo modules included.

The modules treat as untrusted: the data, what comes back from the browser (views and `$EventData`),
view files, a reader's own files and request headers. The full list, what runs where and which
requests the modules make: [Security](https://powershell-universal-components.eize.dev/security/).

Report a way to:

- run script in the browser, or PowerShell on the server, from any untrusted input
- make a template store read or write outside its folder
- make an exported or downloaded file (CSV, XLSX, HTML report, SVG) dangerous to open
- leak a request, header or token into an error, `$Error`, a log line or an event
- make a module fetch an address from the data, a view or a request header (the server fetches only
  addresses the app author gives, such as `-Uri` or `-Schema`)

Not a vulnerability, by design and documented on the pages of each module:

- everything in `-Data` reaches the browser; the app removes what a reader must not see first
- configuration such as `-Options`, themes, `-ChartOptions` or a `-Schema` address comes from the app
  author, and the modules trust it
- a Perspective column the app author formats as a link makes the URLs in it clickable

A vulnerability in a bundled library (for example Apache ECharts or pivotkit) belongs to that
project. Tell us too if a module ships an affected version.

## Reporting a vulnerability

Please report privately through GitHub's
[Report a vulnerability](https://github.com/eizedev/powershell-universal-components/security/advisories/new)
(Security tab, Advisories), not in a public issue. If you cannot use GitHub, email `oss@eize.dev`.

Include the module and version, the PowerShell Universal version, steps to reproduce and what you
expected.

## Supported versions

The latest released version of each module.
