# Everything else: -Options

`-Options` takes any [Apache ECharts option](https://echarts.apache.org/en/option.html) and is merged
over what the parameters generated: objects key by key, arrays element by element (`series[0]` changes
the first series), an object given for an array (`yAxis = @{...}`) applies to every element.

--8<-- "examples/anything-else-options.md"

The ECharts instance is reachable in the browser as
`document.getElementById('<id>').querySelector('div').echarts`.

`-Options` is configuration for the app author; do not build it from what a user typed
([Security and limits](security.md)). Which gallery example needs which parameter or option:
[Apache ECharts gallery](gallery.md).
