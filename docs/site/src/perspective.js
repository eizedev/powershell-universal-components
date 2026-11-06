// The Perspective component for the documentation site, loaded only on pages that show one (a lazy
// chunk of charts.js, about 7 MB with Perspective's WebAssembly). The module's index.js sets the engine
// up the same way inside PSU.
if (!window.__psuPerspective) {
    window.__psuPerspective = import("../../../modules/PowerShellUniversal.Component.Perspective/Components/engine.js").then((m) => m.default);
}

export { default } from "../../../modules/PowerShellUniversal.Component.Perspective/Components/Perspective.jsx";
