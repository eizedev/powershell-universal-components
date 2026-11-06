# Relations and hierarchies

`graph` draws dependencies and topology from `-Source` and `-Target` (`-Layout Force | Circular |
Layered`, `-EdgeLabel` for ports on the lines, `-Undirected`); `tree` draws a hierarchy from `-Path`
(`-Orient LR | TB | Radial`, `-Depth`, `-RootName`); `sankey` and `chord` show flows and overlaps
between the same set of things.

## Network path (layered graph)

--8<-- "examples/network-path-layered-graph.md"

## Folders as a tree

--8<-- "examples/folders-as-a-tree.md"

## Flows (sankey)

--8<-- "examples/flows-sankey.md"

## Overlaps (chord)

--8<-- "examples/overlaps-chord.md"

