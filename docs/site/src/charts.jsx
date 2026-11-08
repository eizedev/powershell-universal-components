/*
 * Live examples on the documentation site (Zensical). Every <div class="psu-example" data-example="id">
 * in a page gets the chart that the module's own React component draws in PSU, with the props that
 * New-UDEChart returned for that example (Build-Site.ps1 writes them to examples.json next to this
 * script). Events that would run a script block on the server show their $EventData instead.
 *
 * PSU switches light and dark with <html data-theme>; Zensical with data-md-color-scheme on <body>
 * ("slate" is dark). The script mirrors the one onto the other, so the component follows the site's
 * palette toggle exactly as it follows PSU's.
 */
import React from "react";
import { createRoot } from "react-dom/client";
import EChart from "../../../modules/PowerShellUniversal.Component.ECharts/Components/EChart.jsx";

const EVENTS = {
    onClick: "-OnClick", onSelect: "-OnSelect", onZoom: "-OnZoom", onLegendChange: "-OnLegendChange",
    onViewChange: "-OnViewChange", onCellClick: "-OnCellClick", onSaveTemplate: "-OnSaveTemplate", onDeleteTemplate: "-OnDeleteTemplate", onPublishTemplate: "-OnPublishTemplate"
};
// where this script was loaded from: examples.json and the Perspective and pivot chunks lie next to it
const base = new URL(".", document.currentScript ? document.currentScript.src : window.location.href).href;
// webpack loads lazy chunks (Perspective, pivot) from the same folder
// eslint-disable-next-line no-undef, camelcase
__webpack_public_path__ = base;

let examples = null;
function loadExamples() {
    if (!examples) {
        examples = fetch(new URL("examples.json", base)).then((r) => {
            if (!r.ok) {
                throw new Error(`examples.json: HTTP ${r.status}`);
            }
            return r.json();
        });
    }
    return examples;
}

function syncTheme() {
    const scheme = document.body ? document.body.getAttribute("data-md-color-scheme") : null;
    document.documentElement.setAttribute("data-theme", scheme === "slate" ? "dark" : "light");
}

// the $EventData an event would send to PowerShell, shown right below the example that fired it
function showEvent(el, name, data) {
    let panel = el.nextElementSibling && el.nextElementSibling.classList.contains("psu-event") ? el.nextElementSibling : null;
    if (!panel) {
        panel = document.createElement("div");
        panel.className = "psu-event";
        panel.setAttribute("role", "status");
        el.after(panel);
    }
    const close = document.createElement("button");
    close.type = "button";
    close.className = "psu-event-close";
    close.setAttribute("aria-label", "Close");
    close.textContent = "\u00d7";
    close.addEventListener("click", () => panel.remove());
    const title = document.createElement("strong");
    title.textContent = name;
    const pre = document.createElement("pre");
    pre.textContent = JSON.stringify(data, null, 2);
    panel.replaceChildren(close, title, document.createTextNode(" would run on the server with $EventData:"), pre);
}

function propsOf(example, el) {
    const props = { ...example.props, setState: () => {} };
    for (const [key, name] of Object.entries(EVENTS)) {
        if (props[key] === "__event__") {
            props[key] = (data) => showEvent(el, name, data);
        }
    }
    return props;
}

const roots = new Map();

async function mount(el) {
    if (roots.has(el)) {
        return;
    }
    const root = createRoot(el);
    roots.set(el, root);
    const id = el.getAttribute("data-example");
    try {
        const all = await loadExamples();
        const example = all[id];
        if (!example) {
            throw new Error(`no example "${id}" in examples.json`);
        }
        if (example.component === "perspective") {
            const { default: Perspective } = await import(/* webpackChunkName: "perspective" */ "./perspective.js");
            root.render(<Perspective {...propsOf(example, el)} />);
        } else if (example.component === "pivot") {
            const { default: PivotReport } = await import(/* webpackChunkName: "pivot" */ "./pivot.js");
            root.render(<PivotReport {...propsOf(example, el)} />);
        } else if (example.component === "pivot-placeholder") {
            const { Placeholder } = await import(/* webpackChunkName: "pivot" */ "./pivot.js");
            root.render(<Placeholder {...propsOf(example, el)} />);
        } else {
            root.render(<EChart {...propsOf(example, el)} />);
        }
    } catch (e) {
        root.render(<div role="alert" className="psu-example-error">Example {id}: {String(e && e.message ? e.message : e)}</div>);
    }
}

// pages change without a reload (Zensical's instant navigation): mount new placeholders, free old ones
function scan() {
    for (const [el, root] of roots) {
        if (!el.isConnected) {
            root.unmount();
            roots.delete(el);
        }
    }
    document.querySelectorAll(".psu-example[data-example]").forEach(mount);
}

function start() {
    syncTheme();
    new MutationObserver(syncTheme).observe(document.body, { attributes: true, attributeFilter: ["data-md-color-scheme"] });
    new MutationObserver(scan).observe(document.body, { childList: true, subtree: true });
    scan();
}

if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start);
} else {
    start();
}
