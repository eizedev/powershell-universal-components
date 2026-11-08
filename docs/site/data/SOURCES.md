# Data of the live examples

The examples in `../examples.ps1` that call a public web API show the real `Invoke-RestMethod` call. The
site is built without network access: `Build-Site.ps1` answers those calls from the snapshots in this
folder, one file per address (`https://endoflife.date/api/python.json` is
`endoflife.date/api/python.json`), saved as the API sent it. `Update-Data.ps1` fetches every file
again; look at the diff before committing it.

The code of this repository is MIT licensed; these files are data and keep the licence of their source.

| Files | Source | Licence | Attribution |
| --- | --- | --- | --- |
| `endoflife.date/api/*.json` | [endoflife.date](https://endoflife.date/), the API's `/api/<product>.json` (release cycles of one product) | [MIT](https://github.com/endoflife-date/endoflife.date/blob/master/LICENSE) | "endoflife.date", with the copyright notice and the licence text below |

Fetched on 2026-11-08, unchanged.

## endoflife.date

- Request: `https://endoflife.date/api/<product>.json`, for example
  `https://endoflife.date/api/python.json`; one row per release cycle with `cycle`, `releaseDate`,
  `eol`, `latest`, `latestReleaseDate`, `lts` and, depending on the product, `support`,
  `extendedSupport`, `codename`, `releaseLabel` and `link`.
- Mixed types: `eol`, `support` and `extendedSupport` are a date (`"2031-10-31"`) or `true`/`false`
  (ended or not, without a date); the dates are text.
- Key: none. No rate limit is documented.
- Licence: the endoflife.date repository, data included, is under the MIT License, which asks to
  include this notice and the licence text in all copies or substantial portions:

  > Copyright 2020 endoflife.date contributors
  >
  > Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
  >
  > The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
  >
  > THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
