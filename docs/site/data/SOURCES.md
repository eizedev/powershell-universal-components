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
| `archive-api.open-meteo.com/v1/archive.json` | [Open-Meteo](https://open-meteo.com/) Historical Weather API ("best match": ECMWF IFS, ERA5, ERA5-Land) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) | "Weather data by Open-Meteo.com", linked to open-meteo.com, next to the data, and the Copernicus attribution below |

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
- Key: none. No rate limit is documented.
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
- Changes made by the app (CC BY asks to say them): one row per city and day; sunshine converted from
  seconds to hours (one decimal); added city, country, continent, the meteorological season (swapped
  south of the equator) and "Rain day" (1 for at least 1 mm of rain). The file here is unchanged.
- Key: none for non-commercial use; commercial use needs a subscription and an `apikey`
  ([terms](https://open-meteo.com/en/terms), [pricing](https://open-meteo.com/en/pricing)). This
  applies to the app's live switch; the snapshot is redistributed under CC BY 4.0.
- Limits of the free API: 600 calls per minute, 5,000 per hour, 10,000 per day; a request of more than
  10 variables or more than two weeks counts as several calls (this one is a few hundred).
- Licence: [CC BY 4.0](https://open-meteo.com/en/licence), attribution next to the data.
- Underlying data: Open-Meteo's "best match" combines ECMWF IFS, ERA5 and ERA5-Land
  ([documentation](https://open-meteo.com/en/docs/historical-weather-api)). ERA5 and ERA5-Land come
  from the Copernicus Climate Change Service (C3S), CC BY 4.0; the Climate Data Store asks users to
  attribute the Copernicus programme with this text, which the app shows under the Open-Meteo credit:

  > Contains modified Copernicus Climate Change Service information 2023 (ERA5) and 2019 (ERA5-Land),
  > and ECMWF IFS data. Neither the European Commission nor ECMWF is responsible for any use that may
  > be made of the Copernicus information or data it contains.
