// Tests for the ECharts option builder. Run: node --test tests/js/
import { test } from "node:test";
import assert from "node:assert/strict";
import { buildOption, mergeOptions, boxStats, quantile, displayName, CHART_TYPES, LARGE } from "../../modules/PowerShellUniversal.Component.ECharts/Components/buildOption.js";

const days = [
    { day: "2026-11-01T00:00:00", team: "OPS", opened: 3 },
    { day: "2026-11-01T00:00:00", team: "DEV", opened: 5 },
    { day: "2026-11-02T00:00:00", team: "OPS", opened: 4 }
];

test("line with GroupBy: one series per group, time axis, rows kept for events", () => {
    const o = buildOption({ chartType: "line", data: days, x: "Day", y: ["Opened"], groupBy: "Team" }, { locale: "en-US" });
    assert.deepEqual(o.series.map((s) => s.name), ["OPS", "DEV"]);
    assert.equal(o.xAxis.type, "time");
    assert.deepEqual(o.series[0].data[1], { value: ["2026-11-02T00:00:00", 4], rowIndex: 2 });
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

test("every chart type builds from empty data", () => {
    for (const t of CHART_TYPES) {
        assert.doesNotThrow(() => buildOption({ chartType: t, data: [] }, {}), t);
    }
    assert.throws(() => buildOption({ chartType: "nope", data: [] }, {}), /Unknown chart type/);
});
