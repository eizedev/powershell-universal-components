---
title: The $schema of a view file
description: "Where the $schema of a view file written by New-UDPivotReport points: -SchemaUrl, the module-wide default PSU_COMPONENT_PIVOT_SCHEMA_URL, and your own copy of the schema."
---

# The `$schema` of a view file: `-SchemaUrl`

Editors that know JSON Schema (VS Code, for one) fetch the address in `$schema`. They use it to check a
view file and complete its keys. By default the address is pivotkit's own copy:
`https://pivotkit.eize.dev/schema/view-file-2.json`. To keep that request inside your network, host a
copy and name it with `-SchemaUrl`.

`-SchemaUrl` takes one of these values:

- A path on the PSU server, such as `/assets/pivot/schema/view-file-2.json`. This is one value for
  every instance, including a local one on `http://localhost:5000`.
- An https address of your copy, such as `https://psu.example.com/assets/pivot/schema/view-file-2.json`.
  The scheme may be in any case.
- `''` to leave `$schema` out.

Every command checks the value the same way: no spaces, at most 2,000 characters, no user name or
password in an address. A path starts with a single `/`. Any other value stops the command with
`-SchemaUrl "<value>": expected an https address, a path such as /assets/pivot/schema/view-file-2.json, or an empty string`.
In `New-UDPivotReport` the page then stays empty, and PSU shows that error.

A path becomes an address when a view file is written:

- In the browser (Download view, Copy view as JSON), the report puts the page's origin in front. The
  file names the address the reader used. The browser ignores the module-wide default. A page
  without a usable origin writes pivotkit's address.
- On the server (the template stores, `ConvertTo-UDPivotViewFile`), the module takes the origin of
  the [module-wide default](#one-default-for-every-report-psu_component_pivot_schema_url) when that is
  an https address.
- Otherwise the server takes the origin from the request. It reads the headers the browser sent:
  `Origin`, else the page address, else `Referer`. PSU passes them to pages, event handlers and API
  endpoints. A template store uses the request of the save, which carries `Origin`.
- Without either, for example in a scheduled job, the command stops with an error.
- A shared view never takes the origin from the request, since everyone reads it. Without an https
  default it names pivotkit's address.

The request must carry the address your users see. Behind a reverse proxy that rewrites these
headers, set the module-wide default to the full https address. The server then uses its origin for
every path.

```powershell
New-UDPivotReport -Id 'tickets' -Data $tickets -SchemaUrl '/assets/pivot/schema/view-file-2.json'
```

## One default for every report: `PSU_COMPONENT_PIVOT_SCHEMA_URL`

A platform sets the address once, as the environment variable `PSU_COMPONENT_PIVOT_SCHEMA_URL` of the
PSU process. It takes the same values as `-SchemaUrl`. Every command without `-SchemaUrl` uses it. An
explicit `-SchemaUrl` always wins, `''` included. As an https address, its origin also completes
every path on the server.

- Set it where PSU starts: the service's environment, or the container's environment.
- Every process PSU starts inherits it: pages, event handlers and jobs.
- An empty or unset variable means pivotkit's address.
- A value that does not pass the check stops each command with an error that names the variable.

```yaml
# a container: docker compose
environment:
  - PSU_COMPONENT_PIVOT_SCHEMA_URL=/assets/pivot/schema/view-file-2.json
```

## Your own copy of the schema

The module ships pivotkit's schemas in its `schema` folder:

- `view-file-2.json`: the view file of format 2, which the report writes.
- `view-file-1.json`: the view file of format 1.
- `view-2.json`: the view of version 2.

They are the files of the pivotkit-core version the module's bundle is built from, copied when the
module is built. Their `$id` stays pivotkit's address. They refer to nothing outside themselves, so a
validator fetches only your copy.

1. Serve the folder over http or https without a sign-in. An editor fetches the file without the
   reader's PSU session, so a folder with authentication answers it with 401. A PSU published folder
   works (`New-PSUPublishedFolder`, or Build, Published Folders):

    ```powershell
    # the module as installed in the repository's Modules folder
    New-PSUPublishedFolder -Name 'Pivot schema' -RequestPath '/assets/pivot/schema' -Path '<repository>/Modules/PowerShellUniversal.Component.Pivot/<version>/schema'
    ```

    The module's folder carries its version in the path. Point the published folder at the new
    folder after an update, or copy `schema` into a folder of your own when you deploy. PSU serves
    `.json` files as `application/json`.

2. Pass the path, or set it as the default:

    ```powershell
    New-UDPivotReport -Id 'tickets' -Data $tickets -SchemaUrl '/assets/pivot/schema/view-file-2.json'
    ```

`-SchemaUrl` names the schema of format 2, which the report and its template stores write. A view
file of format 1 keeps pivotkit's `view-file-1.json` address. `ConvertTo-UDPivotViewFile` writes that
format for a view of version 1 or without a version. `''` leaves `$schema` out of both formats. When
a release of this module writes a newer format version, its CHANGELOG says so: serve the new schema
folder and change the file name in the address.
