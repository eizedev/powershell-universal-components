// The pivot report and its placeholder for the documentation site, loaded only on pages that show one (a lazy
// chunk of charts.js; ECharts for its chart is a chunk of its own, loaded on the first chart). Their
// stylesheets come as text (see webpack.config.cjs): charts.jsx puts them into the shadow root it draws
// the report in, so the page's own styles stay outside.
import pivotkitStyles from "pivotkit-react/styles.css";
import moduleStyles from "../../../modules/PowerShellUniversal.Component.Pivot/Components/psu.css";

export { default } from "../../../modules/PowerShellUniversal.Component.Pivot/Components/PivotReport.jsx";
export { default as Placeholder } from "../../../modules/PowerShellUniversal.Component.Pivot/Components/Placeholder.jsx";
export const styles = [pivotkitStyles, moduleStyles];
