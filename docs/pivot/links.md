---
title: Links into a report
description: "Links that open a view in New-UDPivotReport: links from pivotkit's create_link with the report's -Id as linkKey, and links whose query string names parameters of a pivotkit-server source."
---

# Links into a report

A link can open a [view](views.md) in a report. pivotkit makes such links with `create_link`;
a link to [rows from a server](server-rows.md) can also carry parameters of the source.

## Links from pivotkit (create_link)

pivotkit's MCP tool `create_link` and its REST route `POST /views/link` make a link that opens a view
in a page; a model or a program that worked out a view with a pivotkit-server can hand a person that
link, and the person sees the view over the app's data with their own rights. The report opens such
a link when the pivotkit-server's source names the page and the report:

```json
{
  "sources": {
    "tickets": {
      "file": "data/tickets.csv",
      "link": "https://psu.example.com/tickets/report",
      "linkKey": "tickets"
    }
  }
}
```

```powershell
New-UDPivotReport -Id 'tickets' -SourceId 'tickets' -Data $tickets
```

- `link` is the address of the PSU page, `linkKey` the report's `-Id`: the link then ends in
  `#pivot-tickets=1.<view>` (pivotkit's share format). Without `linkKey` it ends in `#pivot=1.<view>`,
  which the report whose data the link names takes, and removes from the address.
- The link names the data it was made for (the source's id). The report opens it only when that is
  its own `-SourceId` (default its `-Id`); a link for other data is left alone, the report starts as
  without it, and the browser console says why. Give the PSU report the source's id as `-SourceId`.
  A link that names no data (a view file without `source.id`, made by hand) is loaded without that
  check: the report still checks its fields against the data, as for every view.
- Once the report shows the link's view, it writes its own entry in place of pivotkit's, so a
  reload, the light/dark switch and a copied address keep the view.
- The link holds the layout only, never data; the report checks the view against the rows the
  person may see, as for every link. `-NoAddressBar` ignores links, also these.

pivotkit's side: [create_link](https://pivotkit.eize.dev/reference/mcp/) and
[sources](https://pivotkit.eize.dev/reference/mcp/#configuration) (`sources.<id>.link`, `.linkKey`).

A source only the server can reach opens with the person's own rows: `New-UDPivotReport -Uri -Source`
fetches them on the PSU server, with the link's parameters from the page's query string
([rows from a server](server-rows.md)).

## Links with parameters

A link from `create_link` names the source's parameters in the page's query string, such as
`/orders?customer=acme#pivot-orders=1.<view>`. The view stays in the fragment, and the report reads
it in the browser as every link ([links from pivotkit](#links-from-pivotkit-create_link)).

- The module reads `$Query` of the page. It passes on only the names the server lists as the source's
  `linkParams` in `GET /sources`. Other names in the query string stay out.
- Pass `-Query $Query` where the call runs in a script block or function defined in the app script.
- `-Parameter` replaces the query string: `-Parameter @{ customer = $Query.customer }` narrows what a
  link may set. A value that is `$null` is left out. `-Params` is another name for it.
- The server checks every value again with the rights of the person who opens the page.
- The report writes its view into the fragment and keeps the query string. A link a person copies from
  the address bar still names the customer.
- Values in a query string land in access logs, the browser history and the `Referer` header. List
  only parameters whose values may show up there. Let the reverse proxy in front of PSU send a strict
  `Referrer-Policy` header, such as `same-origin`
  ([pivotkit's security notes](https://pivotkit.eize.dev/security/#link-params)).
- Give the report an `-Id`. Without it, the key the reader's view is kept under follows the server's
  columns, and a person with another profile gets another key.

A view the server publishes for the source goes by its name: `-View 'by-region'`. Then only the fields
it uses leave the server. The server lists its views' names, not the views, so the report starts with
the view of the link, else empty.
