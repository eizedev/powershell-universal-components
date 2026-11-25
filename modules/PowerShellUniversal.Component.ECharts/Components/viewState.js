/*
 * What the reader did to a chart and a theme change must not undo: the zoom, the series hidden in the
 * legend and the brushed range. ECharts' setTheme builds the chart from its option again and drops
 * them, and PSU mounts the component again on the first light/dark switch after a page loads. Both
 * read the view before and set it again afterwards, with silent actions, so no -OnZoom, -OnSelect or
 * -OnLegendChange fires. A toolbox switch to line, bar or stack is not kept: the option is set anew.
 */

// the view of a living chart, or null when there is nothing to keep
export function readView(chart) {
    if (!chart || chart.isDisposed()) {
        return null;
    }
    const option = chart.getOption() || {};
    const zoom = (option.dataZoom || []).map((z, dataZoomIndex) => ({ dataZoomIndex, start: z.start, end: z.end }));
    const legend = Object.assign({}, ...(option.legend || []).map((l) => l.selected || {}));
    const brushModel = chart.getModel().getComponent("brush");
    // the range in data values and the grid it is drawn in; ECharts computes the pixels again
    const brush = ((brushModel && brushModel.areas) || []).map((a) => ({ brushType: a.brushType, coordRange: a.coordRange, panelId: a.panelId }));
    return zoom.length || Object.keys(legend).length || brush.length ? { zoom, legend, brush } : null;
}

export function applyView(chart, view) {
    if (!chart || !view) {
        return;
    }
    const silent = { silent: true };
    if (view.zoom.length) {
        chart.dispatchAction({ type: "dataZoom", batch: view.zoom }, silent);
    }
    for (const [name, shown] of Object.entries(view.legend)) {
        chart.dispatchAction({ type: shown ? "legendSelect" : "legendUnSelect", name }, silent);
    }
    if (view.brush.length) {
        chart.dispatchAction({ type: "brush", areas: view.brush }, silent);
    }
}

export function setThemeKeepingView(chart, theme) {
    const view = readView(chart);
    chart.setTheme(theme);
    applyView(chart, view);
}

/*
 * PSU's remount: the old chart hands its view over when it is disposed, the new one of the same id
 * takes it in the same task. Only in the other mode, so a chart drawn again for other reasons (a
 * New-UDDynamic that refreshes) starts as built, as before; an id nobody takes is forgotten.
 */
const handedOver = new Map();

export function handOverView(id, mode, chart) {
    const view = readView(chart);
    if (id === undefined || id === null || !view) {
        return;
    }
    const entry = { mode, view };
    handedOver.set(id, entry);
    setTimeout(() => {
        if (handedOver.get(id) === entry) {
            handedOver.delete(id);
        }
    }, 0);
}

export function takeHandedOverView(id, mode) {
    const entry = handedOver.get(id);
    handedOver.delete(id);
    return entry && entry.mode !== mode ? entry.view : null;
}
