import { withComponentFeatures } from "universal-dashboard";
import PsuPivotReport from "./PivotReport";
import PsuPivotPlaceholder from "./Placeholder";

// The strings are the `type` New-UDPivotReport and New-UDPivotReportPlaceholder return. PSU runs the
// bundle once per component on the page; registering again only replaces the same component, and
// neither keeps global state.
UniversalDashboard.register("ud-pivot-report", withComponentFeatures(PsuPivotReport));
UniversalDashboard.register("ud-pivot-placeholder", withComponentFeatures(PsuPivotPlaceholder));
