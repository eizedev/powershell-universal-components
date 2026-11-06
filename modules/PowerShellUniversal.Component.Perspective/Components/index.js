import { withComponentFeatures } from "universal-dashboard";
import Perspective from "./Perspective";

// PSU runs a component's bundle once for every component of that type on the page. The engine and
// its custom elements may be set up only once, so the first run keeps them on window and the others
// reuse them (a require inside the condition runs only there). The engine module waits for its
// WebAssembly (an async module), so what is kept is a promise of it.
if (!window.__psuPerspective) {
    window.__psuPerspective = Promise.resolve(require("./engine")).then((m) => m.default);
}

// The string is the `type` New-UDPerspective returns.
UniversalDashboard.register("ud-perspective", withComponentFeatures(Perspective));
