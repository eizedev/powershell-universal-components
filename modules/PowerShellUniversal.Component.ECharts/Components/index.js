import { withComponentFeatures } from "universal-dashboard";
import EChart from "./EChart";

// The string is the `type` New-UDEChart returns.
UniversalDashboard.register("ud-echart", withComponentFeatures(EChart));
