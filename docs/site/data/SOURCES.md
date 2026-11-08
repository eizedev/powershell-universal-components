# Data of the live examples

The examples in `../examples.ps1` that call a public web API show the real `Invoke-RestMethod` call. The
site is built without network access: `Build-Site.ps1` answers those calls from the snapshots in this
folder, one file per address (`https://endoflife.date/api/python.json` is
`endoflife.date/api/python.json`), saved as the API sent it. An address with a query string is
`<host>/<path>.json`, and `Addresses.psd1` names the exact address. `Update-Data.ps1` fetches every file
again; look at the diff before committing it.

The module PowerShellUniversal.Component.Pivot.Demo ships this folder as `Data/` (its showcase app works
offline with these snapshots and can fetch the same addresses live), so this file travels with the data.

The code of this repository is MIT licensed; these files are data and keep the licence of their source.

| Files | Source | Licence | Attribution |
| --- | --- | --- | --- |
| `endoflife.date/api/*.json` | [endoflife.date](https://endoflife.date/), the API's `/api/<product>.json` (release cycles of one product) | [MIT](https://github.com/endoflife-date/endoflife.date/blob/master/LICENSE) | "endoflife.date", with the copyright notice and the licence text below |
| `archive-api.open-meteo.com/v1/archive.json` | [Open-Meteo](https://open-meteo.com/) Historical Weather API | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | "Weather data by Open-Meteo.com", linked to open-meteo.com, next to the data, and the Copernicus attribution below |

Fetched on 2026-11-08 (`Update-Data.ps1` writes this date), unchanged.

## endoflife.date

- Endpoint version: the API's v0 endpoints (`/api/<product>.json`, flat rows per release cycle), not
  v1 (`/api/v1/products/<product>`, nested, used by pivotkit's playground). A switch to v1 changes
  the addresses in `../examples.ps1`, these files and the row mapping in the examples.
- Request: `https://endoflife.date/api/<product>.json`, for example
  `https://endoflife.date/api/python.json`; one row per release cycle with `cycle`, `releaseDate`,
  `eol`, `latest`, `latestReleaseDate`, `lts` and, depending on the product, `support`,
  `extendedSupport`, `codename`, `releaseLabel` and `link`.
- Mixed types: `eol`, `support` and `extendedSupport` are a date (`"2031-10-31"`) or `true`/`false`
  (ended or not, without a date); the dates are text.
- Key: none. Terms of the API: the [OpenAPI document of API v1](https://endoflife.date/docs/api/v1/openapi.yml)
  (version 1.2.1, read on 2026-11-08) names the MIT License with a link to the repository's `LICENSE`,
  states no other terms of use and no numeric rate limit; it says the API may answer `429` (Too Many
  Requests), "to prevent abuse of the API and ensure fair usage for all users", possibly with a
  `Retry-After` header.
- Licence: the release data the API serves lives in the endoflife.date repository (one file per
  product, `products/<product>.md`), which is under the MIT License: its `LICENSE` file and its README
  ("Licensed under the MIT License"), checked on 2026-11-08. The API documentation names no separate
  licence for the API's answers. The MIT License asks to include this notice and the licence text in
  all copies or substantial portions; the text below is the repository's `LICENSE`, word for word:

  > Copyright 2020 endoflife.date contributors
  >
  > Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
  >
  > The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
  >
  > THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Open-Meteo

- Used by the showcase app of PowerShellUniversal.Component.Pivot.Demo (page Weather), not by the site.
- Request (`Addresses.psd1`): `https://archive-api.open-meteo.com/v1/archive` with the latitudes and
  longitudes of Berlin, London, Madrid, New York, Tokyo and Sydney in one call, `start_date=2024-01-01`,
  `end_date=2025-12-31`, `daily=temperature_2m_max,temperature_2m_min,temperature_2m_mean,precipitation_sum,sunshine_duration`
  and `timezone=auto`; the answer is an array with one object per city, in that order.
- Changes made by the app (the licence asks to indicate them): one row per city and day; sunshine
  converted from seconds to hours (one decimal); added city, country, continent, the meteorological
  season (swapped south of the equator) and "Rain day" (1 for at least 1 mm of rain). The file here is
  unchanged.
- [Terms](https://open-meteo.com/en/terms), read on 2026-11-08 (the page shows no date of its own).
  For the free API they say: "You may only use the free API services for non-commercial purposes."
  "Non-commercial use is defined as elaborated by creative commons." Examples of non-commercial use
  they give include "Private or non-profit websites or apps that do not have subscriptions or
  advertising" and "Use in educational content"; examples of commercial use include "Websites or apps
  that have subscriptions or display advertisements" and "Commercial products or promotional
  activities". Limits of the free API: "Less than 10'000 API calls per day, 5'000 per hour and 600 per
  minute", applied "by IP addresses and application"; the pricing table on the page also lists 300,000
  calls per month. For commercial use or more calls the page asks to subscribe to an API plan. This
  concerns the app's "Live data" switch, which calls the API from the PSU server; whether a particular
  installation's use is non-commercial is for its operator to judge.
- Data licence: the terms say "The data obtained through the API is provided under the terms of the
  CC-BY 4.0 licence". The [licence page](https://open-meteo.com/en/licence), read on 2026-11-08:
  "API data are offered under Attribution 4.0 International (CC BY 4.0)"; "You must give appropriate
  credit, provide a link to the licence, and indicate if changes were made."; "You must include a link
  next to any location Open-Meteo data are displayed", for example "Weather data by Open-Meteo.com"
  linked to open-meteo.com. The app shows that credit with a link to the licence under the report.
- Underlying data: the licence page lists "Weather reanalysis, air quality forecasts and elevation
  data from Copernicus Climate Change Service C3S" with a link to a Copernicus licence PDF (that link
  answered 404 on 2026-11-08), and ECMWF forecasts under CC BY. The Climate Data Store's catalogue
  (API, read on 2026-11-08) gives ERA5 single levels and ERA5-Land the licence CC-BY-4.0, with the DOIs
  [10.24381/cds.adbb2d47](https://doi.org/10.24381/cds.adbb2d47) and
  [10.24381/cds.e2161bac](https://doi.org/10.24381/cds.e2161bac).
- Copernicus attribution: ECMWF's page "How to acknowledge and cite a Climate Data Store (CDS)
  catalogue entry" (last changed 2025-07-03, read on 2026-11-08) says "All users of data uploaded on
  the Climate Data Store (CDS) must provide clear and visible attribution", besides what the dataset
  licence asks, with the template "[Generated using/Contains modified] Copernicus Climate Change Service
  information [year]." and the disclaimer "Neither the European Commission nor ECMWF is responsible for
  any use that may be made of the Copernicus information or data it contains." The page does not say
  which year to give; the app gives the year the snapshot was fetched. Under the Open-Meteo credit the
  app shows:

  > Contains modified Copernicus Climate Change Service information 2026. Neither the European
  > Commission nor ECMWF is responsible for any use that may be made of the Copernicus information or
  > data it contains. ERA5: doi:10.24381/cds.adbb2d47, ERA5-Land: doi:10.24381/cds.e2161bac.
