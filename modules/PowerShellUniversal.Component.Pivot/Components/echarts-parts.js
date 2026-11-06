/*
 * WORKAROUND (pivotkit-react 0.1.0): the report loads Apache ECharts with import("echarts/charts"),
 * import("echarts/components") and import("echarts/renderers") and uses four charts, four components
 * and the canvas renderer of them. A namespace import keeps webpack from leaving the rest out, so the
 * bundle would carry every chart of ECharts. webpack.config.js points those three imports here, at
 * exactly the parts the report uses. Remove when pivotkit-react imports only what it uses.
 */
export { install as BarChart } from "echarts/lib/chart/bar/install.js";
export { install as LineChart } from "echarts/lib/chart/line/install.js";
export { install as PieChart } from "echarts/lib/chart/pie/install.js";
export { install as HeatmapChart } from "echarts/lib/chart/heatmap/install.js";
export { install as GridComponent } from "echarts/lib/component/grid/install.js";
export { install as TooltipComponent } from "echarts/lib/component/tooltip/install.js";
export { install as LegendComponent } from "echarts/lib/component/legend/install.js";
export { install as VisualMapComponent } from "echarts/lib/component/visualMap/install.js";
export { install as CanvasRenderer } from "echarts/lib/renderer/installCanvasRenderer.js";
