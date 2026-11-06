# Events, security and limits

## Events

`-OnClick` runs on the server when a cell is clicked; `$EventData.row` holds the values of the clicked
row (or of the group in a pivot), `$EventData.filter` the group and split values that lead to the cell
as `[column, operator, value]`.

```powershell
New-UDPerspective -Data $tickets -OnClick { Show-UDToast -Message "Ticket $($EventData.row.Id)" }
```

The [datagrid example](index.md#datagrid-that-readers-rearrange) shows the `$EventData` of a click.

## Security notes

- The engine, the data and every view stay in the browser and the PSU server; nothing is sent elsewhere
  while a reader uses the datagrid, a pivot or a chart.
- The map plugins of the configuration panel (Map Scatter, Map Line, Map Density and the other map
  charts) draw on base map tiles that Perspective loads from `tile.openstreetmap.org` or
  `tiles.versatiles.org` as soon as a reader picks one. The tile requests carry the browser's IP address
  and the map area shown. Where that is not wanted, or the browser has no internet access, a
  Content-Security-Policy without these hosts in `img-src` and `connect-src` blocks them; the map
  plugins then show the points without a background map.
- All rows go to the browser: select the columns a reader may see first (`Select-Object`).
- Cell values are shown as text; a column formatted as a link (in the panel or through `-Config`) makes
  its values clickable URLs, so do not do that for data users can write.
- `$EventData` of `-OnClick` comes from the browser: treat it as user input on the server.

## Size

The module's bundle is about 6.7 MB: it carries Perspective's WebAssembly, so the engine needs no
internet access. The browser downloads it once and caches it; PSU runs it for every Perspective
component on a page, and only the first run sets the engine up, the others share it (one Web Worker per
page).
