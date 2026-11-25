// Tests for what a chart keeps over PSU's light/dark switch: zoom, legend selection and brush
// (modules/PowerShellUniversal.Component.ECharts/Components/viewState.js). Run: node --test tests/js/
import { test } from "node:test";
import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { readView, applyView, setThemeKeepingView, handOverView, takeHandedOverView } from "../../modules/PowerShellUniversal.Component.ECharts/Components/viewState.js";

// a chart that answers getOption and the brush model and records the actions it is sent
function fakeChart(option, brushAreas) {
    const actions = [];
    return {
        actions,
        isDisposed: () => false,
        getOption: () => option,
        getModel: () => ({ getComponent: (type) => (type === "brush" && brushAreas ? { areas: brushAreas } : undefined) }),
        dispatchAction: (payload, opt) => actions.push({ payload, opt })
    };
}

test("readView: the zoom of each dataZoom, the legend selection of all legends and the brush areas", () => {
    const chart = fakeChart(
        { dataZoom: [{ start: 40, end: 60 }, { start: 40, end: 60 }], legend: [{ selected: { a: true, b: false } }, { selected: { c: false } }] },
        [{ brushType: "lineX", coordRange: [5, 8], panelId: "grid--0", range: [100, 200], brushStyle: {} }]
    );
    assert.deepEqual(readView(chart), {
        zoom: [{ dataZoomIndex: 0, start: 40, end: 60 }, { dataZoomIndex: 1, start: 40, end: 60 }],
        legend: { a: true, b: false, c: false },
        brush: [{ brushType: "lineX", coordRange: [5, 8], panelId: "grid--0" }]
    });
    // a chart without zoom, legend and brush has nothing to keep; nor has one not drawn yet
    assert.equal(readView(fakeChart({})), null);
    assert.equal(readView(fakeChart({ legend: [{ selected: {} }] })), null);
    assert.equal(readView(null), null);
});

test("applyView: the kept state as silent actions, so no -OnZoom, -OnSelect or -OnLegendChange fires", () => {
    const chart = fakeChart({});
    applyView(chart, { zoom: [{ dataZoomIndex: 0, start: 40, end: 60 }], legend: { a: true, b: false }, brush: [{ brushType: "lineX", coordRange: [5, 8], panelId: "grid--0" }] });
    assert.deepEqual(chart.actions, [
        { payload: { type: "dataZoom", batch: [{ dataZoomIndex: 0, start: 40, end: 60 }] }, opt: { silent: true } },
        { payload: { type: "legendSelect", name: "a" }, opt: { silent: true } },
        { payload: { type: "legendUnSelect", name: "b" }, opt: { silent: true } },
        { payload: { type: "brush", areas: [{ brushType: "lineX", coordRange: [5, 8], panelId: "grid--0" }] }, opt: { silent: true } }
    ]);
    const empty = fakeChart({});
    applyView(empty, null);
    applyView(empty, { zoom: [], legend: {}, brush: [] });
    assert.deepEqual(empty.actions, []);
});

test("handOverView: a chart mounted again at once with the same id in the other mode gets the view; the same mode or later gets nothing", async () => {
    const zoomed = () => fakeChart({ dataZoom: [{ start: 40, end: 60 }] });
    handOverView("chart1", "light", zoomed());
    assert.deepEqual(takeHandedOverView("chart1", "dark"), { zoom: [{ dataZoomIndex: 0, start: 40, end: 60 }], legend: {}, brush: [] });
    // taken once
    assert.equal(takeHandedOverView("chart1", "dark"), null);
    // drawn again in the same mode (a New-UDDynamic that refreshes): starts as built, as before
    handOverView("chart1", "light", zoomed());
    assert.equal(takeHandedOverView("chart1", "light"), null);
    // an id nobody mounts at once (the page was left) is forgotten
    handOverView("chart2", "light", zoomed());
    await new Promise((resolve) => setTimeout(resolve, 5));
    assert.equal(takeHandedOverView("chart2", "dark"), null);
    // no id: nothing to match
    handOverView(undefined, "light", zoomed());
    assert.equal(takeHandedOverView(undefined, "dark"), null);
});

// the same against the real ECharts of the module (server-side rendering, no DOM)
const echartsUrl = new URL("../../modules/PowerShellUniversal.Component.ECharts/node_modules/echarts/index.js", import.meta.url);
test("ECharts: zoom, legend selection and brush survive setTheme and a new instance", { skip: existsSync(echartsUrl) ? false : "the ECharts module's packages are not installed" }, async () => {
    const echarts = await import(echartsUrl);
    const option = {
        animation: false,
        legend: {},
        brush: { xAxisIndex: 0 },
        xAxis: { type: "category", data: Array.from({ length: 20 }, (_, i) => String(i)) },
        yAxis: { type: "value" },
        dataZoom: [{ type: "inside", xAxisIndex: [0], filterMode: "none" }, { type: "slider", xAxisIndex: [0] }],
        series: [{ name: "a", type: "line", data: Array.from({ length: 20 }, (_, i) => i) }, { name: "b", type: "line", data: Array.from({ length: 20 }, (_, i) => 20 - i) }]
    };
    const make = () => {
        const chart = echarts.init(null, null, { renderer: "svg", ssr: true, width: 600, height: 400 });
        chart.setOption(option);
        return chart;
    };
    const state = (chart) => {
        const o = chart.getOption();
        return { zoom: o.dataZoom.map((d) => [d.start, d.end]), selected: o.legend[0].selected, brush: chart.getModel().getComponent("brush").areas.map((a) => a.coordRange) };
    };
    const chart = make();
    chart.dispatchAction({ type: "dataZoom", start: 40, end: 60 });
    chart.dispatchAction({ type: "legendUnSelect", name: "b" });
    chart.dispatchAction({ type: "brush", areas: [{ brushType: "lineX", xAxisIndex: 0, coordRange: [5, 8] }] });
    const expected = { zoom: [[40, 60], [40, 60]], selected: { a: true, b: false }, brush: [[5, 8]] };
    assert.deepEqual(state(chart), expected);
    const events = [];
    ["datazoom", "legendselectchanged"].forEach((name) => chart.on(name, () => events.push(name)));
    // setTheme alone builds the chart from its option again: zoom, legend and brush are gone
    setThemeKeepingView(chart, { color: ["#ff0000", "#00ff00"] });
    assert.deepEqual(state(chart), expected);
    assert.deepEqual(events, []);
    // PSU mounts the chart again on its first theme switch: a new instance of the same id
    handOverView("t", "light", chart);
    chart.dispose();
    const again = make();
    applyView(again, takeHandedOverView("t", "dark"));
    assert.deepEqual(state(again), expected);
    again.dispose();
});
