// Tests for the ECharts option builder. Run: node --test tests/js/
import { test } from "node:test";
import assert from "node:assert/strict";
import { buildOption, mergeOptions, boxStats, quantile, displayName, linearFit, CHART_TYPES, LARGE } from "../../modules/PowerShellUniversal.Component.ECharts/Components/buildOption.js";

const days = [
    { day: "2026-11-01T00:00:00", team: "OPS", opened: 3 },
    { day: "2026-11-01T00:00:00", team: "DEV", opened: 5 },
    { day: "2026-11-02T00:00:00", team: "OPS", opened: 4 }
];

test("line with GroupBy: one series per group, time axis, rows kept for events", () => {
    const o = buildOption({ chartType: "line", data: days, x: "Day", y: ["Opened"], groupBy: "Team" }, { locale: "en-US" });
    // groups in natural order, independent of row order
    assert.deepEqual(o.series.map((s) => s.name), ["DEV", "OPS"]);
    assert.equal(o.xAxis.type, "time");
    assert.deepEqual(o.series[1].data[1], { value: ["2026-11-02T00:00:00", 4], rowIndex: 2 });
    assert.equal(o.series[0].emphasis.focus, "series");
});

test("series names are the column names as typed, not as PSU camelCased them", () => {
    const o = buildOption({ chartType: "bar", data: days, x: "Team", y: ["Opened"] }, {});
    assert.equal(o.series[0].name, "Opened");
    assert.equal(displayName("leadTime", ["LeadTime"]), "LeadTime");
});

test("category bars align values to categories and stack", () => {
    const rows = [{ m: "Jan", a: 1, b: 2 }, { m: "Feb", a: 3, b: 4 }];
    const o = buildOption({ chartType: "bar", data: rows, x: "m", y: ["a", "b"], stacked: true }, {});
    assert.deepEqual(o.xAxis.data, ["Jan", "Feb"]);
    assert.deepEqual(o.series[1].data.map((d) => d.value), [2, 4]);
    assert.equal(o.series[0].stack, "total");
});

test("horizontal bars swap the axes", () => {
    const o = buildOption({ chartType: "bar", data: [{ n: "x", v: 1 }], x: "n", y: ["v"], horizontal: true }, {});
    assert.equal(o.yAxis.type, "category");
    assert.equal(o.yAxis.inverse, true);
    assert.equal(o.xAxis[0].type, "value");
});

test("secondary axis", () => {
    const rows = [{ m: "Jan", revenue: 10, margin: 0.2 }];
    const o = buildOption({ chartType: "bar", data: rows, x: "m", y: ["revenue", "margin"], secondaryY: ["Margin"] }, {});
    assert.equal(o.yAxis.length, 2);
    assert.equal(o.series[1].yAxisIndex, 1);
});

test("markLine: statistics per series, fixed line once", () => {
    const rows = [{ m: "a", x: 1, y: 2 }];
    const o = buildOption({ chartType: "line", data: rows, x: "m", y: ["x", "y"], markLine: ["median", { value: 48, name: "SLA" }] }, {});
    assert.equal(o.series[0].markLine.data.length, 2);
    assert.equal(o.series[1].markLine.data.length, 1);
    assert.equal(o.series[0].markLine.data[1].yAxis, 48);
});

test("every formatter returns a string", () => {
    const o = buildOption({ chartType: "line", data: days, x: "day", y: ["opened"], dataLabels: true }, {});
    const label = o.series[0].label.formatter({ value: ["x", 5] });
    assert.equal(typeof label, "string");
    assert.equal(typeof o.tooltip.axisPointer.label.formatter({ axisDimension: "y", value: 37.8295197 }), "string");
    assert.equal(o.tooltip.axisPointer.label.formatter({ axisDimension: "y", value: 37.8295197 }), "37.83");
});

test("pie and donut", () => {
    const rows = [{ s: "Open", c: 2 }, { s: "Closed", c: 6 }];
    const donut = buildOption({ chartType: "donut", data: rows, x: "s", y: ["c"] }, {});
    assert.deepEqual(donut.series[0].radius, ["45%", "72%"]);
    assert.equal(donut.series[0].data[1].name, "Closed");
    assert.equal(buildOption({ chartType: "pie", data: rows, x: "s", y: ["c"], dataLabels: false }, {}).series[0].label.show, false);
});

test("boxplot statistics", () => {
    assert.equal(quantile([1, 2, 3, 4], 0.5), 2.5);
    const s = boxStats([1, 2, 3, 4, 5, 6, 7, 8, 100]);
    assert.deepEqual(s.box, [1, 3, 5, 7, 8]);
    assert.deepEqual(s.outliers, [100]);
    const o = buildOption({ chartType: "boxplot", data: [{ g: "a", v: 1 }, { g: "a", v: 3 }, { g: "b", v: 2 }], x: "g", y: ["v"] }, {});
    assert.deepEqual(o.xAxis.data, ["a", "b"]);
});

test("histogram bins and median line", () => {
    const rows = Array.from({ length: 100 }, (_, i) => ({ h: i }));
    const o = buildOption({ chartType: "histogram", data: rows, y: ["h"], bins: 10 }, { locale: "en-US" });
    assert.equal(o.series[0].data.length, 10);
    assert.equal(o.series[0].data.reduce((a, b) => a + b, 0), 100);
    assert.equal(o.series[0].markLine.data[0].name, "Median");
});

test("waterfall running total", () => {
    const rows = [{ s: "Start", v: 100 }, { s: "Cost", v: -30 }, { s: "End", v: 0 }];
    const o = buildOption({ chartType: "waterfall", data: rows, x: "s", y: ["v"], totals: ["End"] }, {});
    assert.deepEqual(o.series[0].data, [0, 70, 0]);
    assert.deepEqual(o.series[1].data.map((d) => d.value), [100, 30, 70]);
});

test("treemap hierarchy from path columns", () => {
    const rows = [{ r: "EU", c: "DE", v: 2 }, { r: "EU", c: "FR", v: 1 }, { r: "US", c: "US", v: 3 }];
    const o = buildOption({ chartType: "treemap", data: rows, path: ["r", "c"], y: ["v"] }, {});
    assert.equal(o.series[0].data.length, 2);
    assert.equal(o.series[0].data[0].children.length, 2);
});

test("sankey links and candlestick with volume", () => {
    const s = buildOption({ chartType: "sankey", data: [{ source: "a", target: "b", value: 2 }] }, {});
    assert.deepEqual(s.series[0].data.map((d) => d.name), ["a", "b"]);
    const c = buildOption({ chartType: "candlestick", data: [{ date: "2026-01-01", open: 1, close: 2, low: 0.5, high: 3, volume: 10 }], x: "date" }, {});
    assert.equal(c.grid.length, 2);
    assert.deepEqual(c.series[0].data[0].value, [1, 2, 0.5, 3]);
});

test("large data uses plain arrays and sampling", () => {
    const rows = Array.from({ length: LARGE + 1 }, (_, i) => ({ t: i, v: i }));
    const o = buildOption({ chartType: "line", data: rows, x: "t", y: ["v"], xAxisType: "value" }, {});
    assert.ok(Array.isArray(o.series[0].data[0]));
    assert.equal(o.series[0].sampling, "lttb");
    assert.equal(o.animation, false);
});

test("mergeOptions: objects by key, arrays by index, object into every array element", () => {
    assert.deepEqual(mergeOptions({ a: { b: 1, c: 2 } }, { a: { c: 3 } }), { a: { b: 1, c: 3 } });
    assert.deepEqual(mergeOptions([{ x: 1 }, { x: 2 }], [{ y: 1 }]), [{ x: 1, y: 1 }, { x: 2 }]);
    assert.deepEqual(mergeOptions([{ x: 1 }, { x: 2 }], { y: 0 }), [{ x: 1, y: 0 }, { x: 2, y: 0 }]);
    const o = buildOption({ chartType: "bar", data: days, x: "team", y: ["opened"], options: { series: [{ itemStyle: { borderRadius: 4 } }] } }, {});
    assert.equal(o.series[0].itemStyle.borderRadius, 4);
    assert.equal(o.series[0].type, "bar");
});

test("groups sort naturally: P2 before P10", () => {
    const rows = [{ x: "a", g: "P10", v: 1 }, { x: "a", g: "P2", v: 1 }, { x: "a", g: "P1", v: 1 }];
    assert.deepEqual(buildOption({ chartType: "bar", data: rows, x: "x", y: ["v"], groupBy: "g" }, {}).series.map((s) => s.name), ["P1", "P2", "P10"]);
});

test("value labels use the short form of the format", () => {
    const o = buildOption({ chartType: "bar", data: [{ s: "a", v: 9850000 }], x: "s", y: ["v"], dataLabels: true, format: "currency:EUR" }, { locale: "de-DE" });
    assert.match(o.series[0].label.formatter({ value: 9850000 }), /9,9\sMio\.\s€/);
    assert.match(o.tooltip.valueFormatter(9850000), /9\.850\.000,00\s€/);
});

test("every chart type builds from empty data", () => {
    for (const t of CHART_TYPES) {
        assert.doesNotThrow(() => buildOption({ chartType: t, data: [] }, {}), t);
    }
    assert.throws(() => buildOption({ chartType: "nope", data: [] }, {}), /Unknown chart type/);
});

test("responsive rules for narrow containers", async () => {
    const { responsive, optionForWidth, NARROW } = await import("../../modules/PowerShellUniversal.Component.ECharts/Components/buildOption.js");
    const rows = [{ s: "Open", c: 2 }, { s: "Closed", c: 6 }];
    const base = buildOption({ chartType: "donut", data: rows, x: "s", y: ["c"] }, {});
    const rules = responsive(base, { chartType: "donut" }, { locale: "en-US" });
    assert.equal(rules[0].maxWidth, NARROW);
    const narrow = optionForWidth(base, rules, 390);
    assert.equal(narrow.series[0].label.position, "inside");
    assert.equal(narrow.series[0].label.formatter({ percent: 75 }), "75%");
    assert.equal(narrow.series[0].label.formatter({ percent: 2 }), "", "tiny slices stay unlabelled");
    assert.equal(narrow.series[0].data.length, 2, "data survives the merge");
    assert.notEqual(optionForWidth(base, rules, 1200).series[0].label.position, "inside");
    const barBase = buildOption({ chartType: "bar", data: rows, x: "s", y: ["c"], dataLabels: true }, {});
    const barRules = responsive(barBase, { chartType: "bar", dataLabels: true }, {});
    const bars = optionForWidth(barBase, barRules, 400);
    assert.notEqual(bars.series[0].label.show, false, "labels stay on a narrow card");
    assert.equal(bars.toolbox.feature.magicType.show, false);
    assert.equal(optionForWidth(barBase, barRules, 300).series[0].label.show, false, "and go when tiny");
    assert.equal(optionForWidth(barBase, responsive(barBase, { chartType: "bar" }, {}), 300).toolbox.show, false);
});

test("axis breaks: ISO dates on a time axis become epoch ms, none on category axes", async () => {
    const { axisBreaks } = await import("../../modules/PowerShellUniversal.Component.ECharts/Components/buildOption.js");
    const b = axisBreaks([{ start: "2026-11-05T18:00:00Z", end: "2026-11-06T08:00:00Z" }], "time");
    assert.equal(b[0].start, Date.parse("2026-11-05T18:00:00Z"));
    assert.equal(b[0].gap, "1%");
    assert.equal(axisBreaks([{ start: 1, end: 2 }], "category"), undefined);
    assert.equal(axisBreaks([{ start: 5, end: 2 }], "value"), undefined, "end before start is dropped");
    const o = buildOption({ chartType: "line", data: days, x: "day", y: ["opened"], breaks: [{ start: "2026-11-01T12:00:00Z", end: "2026-11-01T20:00:00Z" }] }, {});
    assert.equal(o.xAxis.breaks.length, 1);
    assert.equal(buildOption({ chartType: "bar", data: [{ s: "a", v: 1 }], x: "s", y: ["v"], yBreaks: [{ start: 100, end: 1000, gap: "5%" }] }, {}).yAxis[0].breaks[0].end, 1000);
});

test("sparkline: no axes, no legend, latest point marked", () => {
    const rows = [{ t: "a", v: 1 }, { t: "b", v: 3 }, { t: "c", v: null }];
    const o = buildOption({ chartType: "area", data: rows, x: "t", y: ["v"], sparkline: true }, {});
    assert.equal(o.xAxis.show, false);
    assert.equal(o.legend.show, false);
    assert.equal(o.toolbox, undefined);
    assert.deepEqual(o.series[0].markPoint.data[0].coord, [1, 3]);
});

test("facets: one grid per value, shared value scale", () => {
    const rows = [
        { day: "Mon", hour: "08", v: 2 }, { day: "Mon", hour: "09", v: 9 },
        { day: "Tue", hour: "08", v: 4 }, { day: "Tue", hour: "09", v: 1 },
        { day: "Wed", hour: "08", v: 3 }
    ];
    const o = buildOption({ chartType: "line", data: rows, x: "hour", y: ["v"], facet: "day", facetColumns: 2 }, {});
    assert.equal(o.grid.length, 3);
    assert.equal(o.xAxis.length, 3);
    assert.deepEqual(o.yAxis.map((a) => a.max), [9, 9, 9]);
    assert.deepEqual(o.series.map((s) => s.xAxisIndex), [0, 1, 2]);
    assert.deepEqual(o.title.map((t) => t.text), ["Mon", "Tue", "Wed"]);
    assert.ok(o.grid.every((g) => /%$/.test(g.top)), "layout in plain percent");
});

test("normalize: stacks sum to 100 %, raw values kept", () => {
    const rows = [{ m: "Jan", a: 1, b: 3 }, { m: "Feb", a: 2, b: 2 }];
    const o = buildOption({ chartType: "bar", data: rows, x: "m", y: ["a", "b"], normalize: true }, { locale: "en-US" });
    assert.deepEqual(o.series[0].data.map((d) => d.value), [25, 50]);
    assert.deepEqual(o.series[1].data.map((d) => d.raw), [3, 2]);
    assert.equal(o.yAxis[0].max({ max: 100.00000000001 }), 100.00000000001, "never clips the stack");
    assert.equal(o.yAxis[0].max({ max: 60 }), 100);
    assert.equal(o.series[1].stack, "total");
    const labelled = buildOption({ chartType: "bar", data: rows, x: "m", y: ["a", "b"], normalize: true, dataLabels: true }, {});
    assert.equal(labelled.series[0].label.position, "inside", "labels inside the stack");
});

test("zoom axis: value axis zoom for vertical bars", () => {
    const rows = [{ m: "Jan", a: 1 }];
    const o = buildOption({ chartType: "bar", data: rows, x: "m", y: ["a"], zoom: "both", zoomAxis: "y" }, {});
    assert.ok(o.dataZoom.every((z) => z.yAxisIndex !== undefined));
    assert.ok(o.dataZoom.some((z) => z.orient === "vertical"));
    const both = buildOption({ chartType: "bar", data: rows, x: "m", y: ["a"], zoom: "inside", zoomAxis: "both" }, {});
    assert.equal(both.dataZoom.length, 2);
});

test("bubble, mark area, band", () => {
    const rows = [{ x: 1, y: 2, s: 10, lo: 1, hi: 3 }, { x: 2, y: 3, s: 40, lo: 2, hi: 5 }];
    const b = buildOption({ chartType: "scatter", data: rows, x: "x", y: ["y"], size: "s", xAxisType: "value" }, {});
    assert.equal(typeof b.series[0].symbolSize, "function");
    assert.equal(Math.round(b.series[0].symbolSize([2, 3, 40])), 48);
    const t = [{ t: "2026-11-01T00:00:00Z", v: 1, lo: 0, hi: 2 }, { t: "2026-11-02T00:00:00Z", v: 2, lo: 1, hi: 4 }];
    const m = buildOption({ chartType: "line", data: t, x: "t", y: ["v"], markArea: [{ from: "2026-11-01T06:00:00Z", to: "2026-11-01T08:00:00Z", name: "Maintenance" }] }, {});
    assert.equal(m.series[0].markArea.data[0][0].xAxis, Date.parse("2026-11-01T06:00:00Z"));
    const band = buildOption({ chartType: "line", data: t, x: "t", y: ["v"], band: ["lo", "hi"] }, {});
    assert.equal(band.series.length, 3);
    assert.equal(band.series[0].stack, "__band");
    assert.deepEqual(band.series[1].data.map((d) => d[1]), [2, 3], "second band series is the width");
    assert.equal(band.series[2].name, "v");
});

test("gauge styles and gantt", () => {
    const ring = buildOption({ chartType: "gauge", data: [{ s: "A", v: 99.9 }, { s: "B", v: 98 }], x: "s", y: ["v"], gaugeStyle: "ring" }, {});
    assert.equal(ring.series.length, 2);
    const grade = buildOption({ chartType: "gauge", data: [{ v: 97 }], y: ["v"], gaugeStyle: "grade", min: 90, thresholds: [{ value: 95, color: "red" }, { value: 99, color: "orange" }, { value: 100, color: "green" }] }, {});
    assert.deepEqual(grade.series[0].axisLine.lineStyle.color.map((c) => c[1]), ["red", "orange", "green"]);
    const rows = [{ host: "srv1", start: "2026-11-05T22:00:00Z", end: "2026-11-05T23:30:00Z", state: "ok" }, { host: "srv2", start: "2026-11-05T22:30:00Z", end: "2026-11-06T01:00:00Z", state: "failed" }];
    const g = buildOption({ chartType: "gantt", data: rows, x: "host", groupBy: "state" }, {});
    assert.deepEqual(g.yAxis.data, ["srv1", "srv2"]);
    assert.deepEqual(g.series.map((s) => s.name), ["failed", "ok"]);
    assert.equal(g.series[1].data[0].value[1], Date.parse("2026-11-05T22:00:00Z"));
    assert.equal(typeof g.series[0].renderItem, "function");
});

test("zoom auto: slider with preview on time axes and many categories", () => {
    const time = buildOption({ chartType: "line", data: days, x: "day", y: ["opened"] }, {});
    assert.ok(time.dataZoom.some((z) => z.type === "slider"));
    const few = buildOption({ chartType: "bar", data: [{ s: "a", v: 1 }], x: "s", y: ["v"] }, {});
    assert.ok(few.dataZoom.every((z) => z.type === "inside"));
    const many = buildOption({ chartType: "bar", data: Array.from({ length: 61 }, (_, i) => ({ s: "c" + i, v: i })), x: "s", y: ["v"] }, {});
    assert.ok(many.dataZoom.some((z) => z.type === "slider"));
    const none = buildOption({ chartType: "line", data: days, x: "day", y: ["opened"], zoom: "none" }, {});
    assert.equal(none.dataZoom.length, 0);
});

test("ECharts locale from a language tag", async () => {
    // locales.js imports ECharts' language files; only the tag mapping is tested here
    const src = (await import("node:fs")).readFileSync(new URL("../../modules/PowerShellUniversal.Component.ECharts/Components/locales.js", import.meta.url), "utf8");
    const body = src.slice(src.indexOf("export function echartsLocale"));
    const LOCALES = { DE: 1, FR: 1, "PT-br": 1, "nb-NO": 1 };
    const echartsLocale = new Function("LOCALES", body.replace("export ", "") + "; return echartsLocale;")(LOCALES);
    assert.equal(echartsLocale("de-DE"), "DE");
    assert.equal(echartsLocale("pt-BR"), "PT-br");
    assert.equal(echartsLocale("nb"), "nb-NO");
    assert.equal(echartsLocale("xx-YY"), "EN");
    assert.equal(echartsLocale(undefined), "EN");
});

test("graph: nodes from links, groups, degree-based size", () => {
    const rows = [
        { source: "CRM", target: "vm-sql01", kind: "Service", tkind: "VM" },
        { source: "ERP", target: "vm-sql01", kind: "Service", tkind: "VM" },
        { source: "vm-sql01", target: "esx-03", kind: "VM", tkind: "Host" }
    ];
    const o = buildOption({ chartType: "graph", data: rows, groupBy: "kind", targetGroup: "tkind" }, {});
    const s = o.series[0];
    assert.deepEqual(s.data.map((d) => d.name), ["CRM", "vm-sql01", "ERP", "esx-03"]);
    assert.deepEqual(o.legend.data, ["Service", "VM", "Host"]);
    assert.equal(s.data[1].value, 3, "vm-sql01 has three links");
    assert.ok(s.data[1].symbolSize > s.data[0].symbolSize);
    assert.equal(s.emphasis.focus, "adjacency");
});

test("linearFit: exact line, stable with timestamps", () => {
    const f = linearFit([[0, 1], [1, 3], [2, 5]]);
    assert.equal(f.slope, 2);
    assert.equal(f.intercept, 1);
    const t0 = Date.parse("2026-01-01T00:00:00Z");
    const day = 86400000;
    const g = linearFit([0, 1, 2, 3].map((i) => [t0 + i * day, 50 + i]));
    assert.ok(Math.abs(g.slope * day - 1) < 1e-9, "one per day");
    assert.equal(linearFit([[1, 1]]), undefined);
});

test("trend: forecast to a target marks the date", () => {
    const rows = [0, 1, 2, 3].map((i) => ({ day: `2026-01-0${i + 1}T00:00:00Z`, used: 70 + 5 * i }));
    const o = buildOption({ chartType: "line", data: rows, x: "day", y: ["used"], trend: "linear", trendTarget: 100 }, {});
    const t = o.series.find((s) => s.name === "used (trend)");
    assert.ok(t, "trend series added");
    assert.equal(t.lineStyle.type, "dashed");
    const hit = Date.parse("2026-01-07T00:00:00Z");
    assert.ok(Math.abs(t.markLine.data[0].xAxis - hit) < 1000, "100 reached on Jan 7");
    assert.ok(Math.abs(t.data[1][1] - 100) < 1e-6);
});

test("markPoint: statistics on every series, a fixed pin on the first", () => {
    const rows = [{ d: "Mon", a: 1, b: 4 }, { d: "Tue", a: 3, b: 2 }];
    const o = buildOption({ chartType: "bar", data: rows, x: "d", markPoint: ["max", { x: "Tue", y: 3, label: "Peak" }] }, {});
    assert.deepEqual(o.series[0].markPoint.data.map((p) => p.type || p.name), ["max", "Peak"]);
    assert.deepEqual(o.series[1].markPoint.data.map((p) => p.type || p.name), ["max"]);
});

test("tree: one root, path levels as children", () => {
    const rows = [
        { vc: "vc1", cluster: "A", host: "esx-01" },
        { vc: "vc1", cluster: "A", host: "esx-02" },
        { vc: "vc2", cluster: "B", host: "esx-03" }
    ];
    const o = buildOption({ chartType: "tree", data: rows, path: ["vc", "cluster", "host"], rootName: "All" }, {});
    const root = o.series[0].data[0];
    assert.equal(root.name, "All");
    assert.deepEqual(root.children.map((c) => c.name), ["vc1", "vc2"]);
    assert.equal(root.children[0].children[0].children.length, 2);
    assert.equal(o.series[0].orient, "LR");
});

test("chord, parallel and themeriver build their series", () => {
    const links = [{ source: "VMware", target: "Veeam", value: 410 }, { source: "VMware", target: "EDR", value: 380 }];
    const c = buildOption({ chartType: "chord", data: links }, {});
    assert.equal(c.series[0].type, "chord");
    assert.deepEqual(c.series[0].data.map((d) => d.name), ["VMware", "Veeam", "EDR"]);

    const vms = [{ vm: "a", os: "Windows", cpu: 4, ram: 16 }, { vm: "b", os: "Linux", cpu: 2, ram: 8 }];
    const p = buildOption({ chartType: "parallel", data: vms, x: "vm", y: ["os", "cpu", "ram"], groupBy: "os" }, {});
    assert.equal(p.parallelAxis[0].type, "category");
    assert.equal(p.parallelAxis[1].type, "value");
    assert.equal(p.series.length, 2);
    assert.deepEqual(p.series[0].data[0].value, ["Linux", 2, 8]);

    const r = buildOption({ chartType: "themeriver", data: days, x: "day", groupBy: "team", y: ["opened"] }, {});
    assert.equal(r.singleAxis.type, "time");
    assert.deepEqual(r.series[0].data[0], ["2026-11-01T00:00:00", 3, "OPS"]);
});

test("graph layered: columns follow the links, edge labels from a column", () => {
    const rows = [
        { from: "fw-01", to: "core-01", ports: "port1 > Te1/1" },
        { from: "core-01", to: "acc-01", ports: "" },
        { from: "acc-01", to: "esx-01", ports: "Gi1/0/12 > vmnic2" },
        { from: "core-01", to: "esx-01", ports: null }
    ];
    const o = buildOption({ chartType: "graph", data: rows, source: "from", target: "to", layout: "layered", edgeLabel: "ports" }, {});
    const s = o.series[0];
    assert.equal(s.layout, "none");
    const x = Object.fromEntries(s.data.map((d) => [d.name, d.x]));
    assert.deepEqual([x["fw-01"], x["core-01"], x["acc-01"], x["esx-01"]], [0, 200, 400, 600], "esx-01 right of its furthest predecessor");
    assert.equal(s.links[2].label.formatter, "Gi1/0/12 > vmnic2");
    assert.equal(s.links[1].label, undefined);
});

test("matrix: one grid per cell on the matrix, one scale per column", () => {
    const rows = [];
    for (const c of ["A", "B"]) for (const k of ["Tickets", "SLA"]) for (const w of [1, 2, 3]) rows.push({ customer: c, kpi: k, week: `W${w}`, value: k === "SLA" ? 90 + w : w * (c === "A" ? 10 : 20) });
    const o = buildOption({ chartType: "matrix", data: rows, y: ["customer"], groupBy: "kpi", x: "week", value: "value" }, {});
    assert.deepEqual(o.matrix.x.data, ["Tickets", "SLA"]);
    assert.deepEqual(o.matrix.y.data, ["A", "B"]);
    assert.equal(o.grid.length, 4);
    assert.deepEqual(o.grid[0].coord, ["Tickets", "A"]);
    // Tickets range 10..60 for both customers, 15 % padding
    assert.equal(o.yAxis[0].max, 67.5, "Tickets scale shared by A and B");
    assert.equal(o.yAxis[2].max, o.yAxis[0].max);
    assert.equal(o.yAxis[0].min, 2.5);
    assert.equal(o.series[3].xAxisIndex, 3);
});

test("thresholds on a line: piecewise colours by value, trend lines excluded", () => {
    const rows = [0, 1, 2, 3].map((i) => ({ t: `2026-01-0${i + 1}T00:00:00Z`, ms: 100 + 100 * i }));
    const o = buildOption({ chartType: "line", data: rows, x: "t", y: ["ms"], trend: "linear", thresholds: [{ value: 250, color: "green" }, { value: 1e9, color: "red" }] }, {});
    assert.equal(o.visualMap.type, "piecewise");
    assert.deepEqual(o.visualMap.seriesIndex, [0]);
    assert.deepEqual(o.visualMap.pieces[0], { lte: 250, color: "green" });
    assert.equal(o.visualMap.pieces[1].gt, 250);
});

test("mergeOptions ignores __proto__ and constructor keys", () => {
    const user = JSON.parse('{"__proto__": {"polluted": 1}, "constructor": {"x": 1}, "title": {"text": "ok"}}');
    const out = mergeOptions({ title: { text: "a" } }, user);
    assert.equal(out.title.text, "ok");
    assert.equal(out.polluted, undefined);
    assert.equal(Object.getPrototypeOf(out), Object.prototype);
    assert.equal({}.polluted, undefined);
});

test("tooltips escape names from the data", () => {
    const evil = '<img src=x onerror="alert(1)">';
    const heat = buildOption({ chartType: "heatmap", data: [{ x: evil, y: "b", v: 1 }], x: "x", y: ["y"], value: "v" }, {});
    const text = heat.tooltip.formatter({ value: [0, 0, 1] });
    assert.ok(!text.includes("<img"), text);
    assert.ok(text.includes("&lt;img"));
    const g = buildOption({ chartType: "graph", data: [{ source: evil, target: "t" }] }, {});
    assert.ok(!g.tooltip.formatter({ name: evil, data: {} }).includes("<img"));
});

test("a column name that matches no column is an error naming the columns", () => {
    const rows = [{ team: "A", n: 1 }];
    assert.throws(() => buildOption({ chartType: "bar", data: rows, x: "Team", y: ["Tickets"] }, {}), /-Y Tickets.*Columns in the data: team, n/);
    assert.throws(() => buildOption({ chartType: "bar", data: rows, x: "Tem", y: ["n"] }, {}), /-X Tem/);
    assert.doesNotThrow(() => buildOption({ chartType: "bar", data: [], x: "Anything", y: ["Else"] }, {}), "empty data is fine");
    const empty = buildOption({ chartType: "line", data: [] }, {});
    assert.equal(empty.graphic.style.text, "No data");
});

test("both themes carry a full palette", async () => {
    const { ensureTheme } = await import("../../modules/PowerShellUniversal.Component.ECharts/Components/themes.js");
    const registered = {};
    const fake = { registerTheme: (name, theme) => { registered[name] = theme; } };
    for (const mode of ["light", "dark"]) {
        const name = ensureTheme(fake, mode, {});
        assert.ok(Array.isArray(registered[name].color) && registered[name].color.length >= 8, `${mode} palette`);
    }
});

test("-EventColumns with an unknown column is an error like the other column parameters", () => {
    assert.throws(() => buildOption({ chartType: "bar", data: [{ name: "a", n: 1 }], x: "name", y: ["n"], eventColumns: ["Nmae"] }, {}), /-EventColumns Nmae/);
});

test("corporate design: CSS tokens and a custom theme over the module's theme", async () => {
    const { themeObject, readCssTokens, ensureTheme } = await import("../../modules/PowerShellUniversal.Component.ECharts/Components/themes.js");
    const css = { "--psu-chart-1": "#003366", "--psu-chart-3": "#ff6600", "--psu-chart-text": "#111111" };
    const tokens = readCssTokens((name) => css[name] || "");
    const t = themeObject("light", { text: "#999999" }, undefined, tokens);
    assert.deepEqual(t.color.slice(0, 3), ["#003366", "#b6d634", "#ff6600"], "CSS colours replace their positions, the others stay");
    assert.equal(t.color.length, 9);
    assert.equal(t.textStyle.color, "#111111", "CSS text colour wins over the page's");
    const custom = { color: ["#123456"], title: { textStyle: { fontWeight: "bold" } } };
    const c = themeObject("dark", {}, custom, {});
    assert.deepEqual(c.color, ["#123456"]);
    assert.equal(c.title.textStyle.fontWeight, "bold");
    assert.ok(c.title.textStyle.color, "keys the custom theme does not set stay");
    assert.equal(c.line.label.textBorderWidth, 0, "line labels keep their style (no duplicate key)");
    const names = new Set();
    const fake = { registerTheme: (n) => names.add(n) };
    assert.equal(ensureTheme(fake, "dark", {}, undefined, {}), "psu-dark");
    assert.notEqual(ensureTheme(fake, "dark", {}, custom, {}), "psu-dark", "a custom variant gets its own name");
});

test("a custom theme cannot reach the prototype chain", async () => {
    const { themeObject } = await import("../../modules/PowerShellUniversal.Component.ECharts/Components/themes.js");
    const hostile = JSON.parse('{"__proto__": {"polluted": 1}, "title": {"constructor": {"x": 1}, "textStyle": {"color": "#123"}}}');
    const t = themeObject("light", {}, hostile, {});
    assert.equal({}.polluted, undefined);
    assert.equal(t.polluted, undefined);
    assert.equal(t.title.textStyle.color, "#123");
    assert.equal(Object.getPrototypeOf(t), Object.prototype);
});

test("-Aggregate combines rows with the same category; without it the last row wins", () => {
    const rows = [{ team: "A", n: 1 }, { team: "A", n: 5 }, { team: "B", n: 2 }];
    const last = buildOption({ chartType: "bar", data: rows, x: "team", y: ["n"] }, {});
    assert.deepEqual(last.series[0].data.map((d) => d.value), [5, 2]);
    const sum = buildOption({ chartType: "bar", data: rows, x: "team", y: ["n"], aggregate: "sum" }, {});
    assert.deepEqual(sum.series[0].data.map((d) => d.value), [6, 2]);
    const count = buildOption({ chartType: "pie", data: rows, x: "team", y: ["n"], aggregate: "count" }, {});
    assert.deepEqual(count.series[0].data.map((d) => [d.name, d.value]), [["A", 2], ["B", 1]]);
    const avg = buildOption({ chartType: "bar", data: rows, x: "team", y: ["n"], aggregate: "avg" }, {});
    assert.equal(avg.series[0].data[0].value, 3);
});

test("polar and radialbar put bars on a polar coordinate system", () => {
    const rows = [0, 1, 2].map((h) => ({ hour: `0${h}`, tickets: 10 + h }));
    const p = buildOption({ chartType: "polar", data: rows, x: "hour", y: ["tickets"] }, {});
    assert.equal(p.series[0].coordinateSystem, "polar");
    assert.equal(p.angleAxis.type, "category");
    assert.deepEqual(p.angleAxis.data, ["00", "01", "02"]);
    const r = buildOption({ chartType: "radialbar", data: rows, x: "hour", y: ["tickets"], max: 100 }, {});
    assert.equal(r.radiusAxis.type, "category");
    // the full value (-Max 100) fills three quarters of the circle
    assert.ok(Math.abs(r.angleAxis.max - 100 * 4 / 3) < 1e-9);
    assert.equal(r.series[0].roundCap, true);
});

test("bump ranks items per period by value", () => {
    const rows = [
        { m: "Jan", c: "A", t: 10 }, { m: "Jan", c: "B", t: 20 },
        { m: "Feb", c: "A", t: 30 }, { m: "Feb", c: "B", t: 5 }
    ];
    const o = buildOption({ chartType: "bump", data: rows, x: "m", groupBy: "c", y: ["t"] }, {});
    const a = o.series.find((s) => s.name === "A");
    assert.deepEqual(a.data.map((d) => d.value), [2, 1], "A climbs from #2 to #1");
    assert.equal(a.data[1].raw, 30);
    assert.equal(o.yAxis.inverse, true);
});

test("aggregate: empty groups are gaps, large groups work, time axes combine equal timestamps", () => {
    const empty = buildOption({ chartType: "bar", data: [{ k: "a", v: null }, { k: "a", v: null }, { k: "b", v: 2 }], x: "k", y: ["v"], aggregate: "sum" }, {});
    assert.equal(empty.series[0].data[0].value, null, "sum of no values is a gap");
    const big = Array.from({ length: 300000 }, (_, i) => ({ k: "a", v: i }));
    const max = buildOption({ chartType: "bar", data: big, x: "k", y: ["v"], aggregate: "max" }, {});
    const first = max.series[0].data[0];
    assert.equal(first && typeof first === "object" ? first.value : first, 299999);
    const t = [{ d: "2026-11-01T00:00:00Z", n: 1 }, { d: "2026-11-01T00:00:00Z", n: 2 }, { d: "2026-11-02T00:00:00Z", n: 5 }];
    const line = buildOption({ chartType: "line", data: t, x: "d", y: ["n"], aggregate: "sum" }, {});
    assert.deepEqual(line.series[0].data.map((p) => p.value[1]), [3, 5]);
    const bump = buildOption({ chartType: "bump", data: [{ m: "Jan", c: "A", t: null }, { m: "Jan", c: "B", t: 5 }, { m: "Jan", c: "C", t: 4 }], x: "m", groupBy: "c", y: ["t"] }, {});
    assert.equal(bump.series.find((s) => s.name === "A").data[0].value, null, "no value, no rank");
});
