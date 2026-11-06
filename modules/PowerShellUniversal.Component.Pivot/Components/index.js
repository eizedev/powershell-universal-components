import { withComponentFeatures } from "universal-dashboard";
import PsuPivotReport from "./PivotReport";

// The string is the `type` New-UDPivotReport returns. PSU runs the bundle once per component on the
// page; registering again only replaces the same component, and the report keeps no global state.
UniversalDashboard.register("ud-pivot-report", withComponentFeatures(PsuPivotReport));
