/*
 * Live examples on the documentation site (Zensical). Every <div class="psu-example" data-example="id">
 * in a page gets the chart that the module's own React component draws in PSU, with the props that
 * New-UDEChart returned for that example (Build-Site.ps1 writes them to examples.json next to this
 * script). Events that would run a script block on the server show their $EventData instead.
 *
 * PSU switches light and dark with <html data-theme>; Zensical with data-md-color-scheme on <body>
 * ("slate" is dark). The script mirrors the one onto the other, so the component follows the site's
 * palette toggle exactly as it follows PSU's.
 *
 * The pivot report and its placeholder are drawn into a shadow root of the placeholder element, with
 * their stylesheets inside it. The page's typography (Zensical's .md-typeset rules for h2, lists,
 * details, tables and code, and the design's dot before every h2) would otherwise style the report's
 * own headings, field list and admin panel, which PSU's pages leave alone. Perspective's viewer has a
 * shadow root of its own; ECharts draws on a canvas.
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

// the components each example type draws, loaded on demand; pivot ones come with their stylesheets as text
const COMPONENTS = {
    echarts: async () => ({ Component: EChart }),
    perspective: async () => ({ Component: (await import(/* webpackChunkName: "perspective" */ "./perspective.js")).default }),
    pivot: async () => {
        const m = await import(/* webpackChunkName: "pivot" */ "./pivot.js");
        return { Component: m.default, styles: m.styles };
    },
    "pivot-placeholder": async () => {
        const m = await import(/* webpackChunkName: "pivot" */ "./pivot.js");
        return { Component: m.Placeholder, styles: m.styles };
    }
};

// what differs from PSU inside the shadow root: Zensical's root font size is 20 px, PSU's 16 px, and the
// module's admin panel sizes its text in rem
const SITE_STYLES = ".ud-pivot-admin, .ud-pivot-admin h3 { font-size: 0.7rem; }";

// a shadow root with the component's stylesheets and one element to render into
function isolatedContainer(el, styles) {
    const shadow = el.shadowRoot || el.attachShadow({ mode: "open" });
    for (const css of [...styles, SITE_STYLES]) {
        const style = document.createElement("style");
        style.textContent = css;
        shadow.append(style);
    }
    const container = document.createElement("div");
    shadow.append(container);
    return container;
}

async function mount(el) {
    if (roots.has(el)) {
        return;
    }
    roots.set(el, null);
    const id = el.getAttribute("data-example");
    let root = null;
    try {
        const all = await loadExamples();
        const example = all[id];
        if (!example) {
            throw new Error(`no example "${id}" in examples.json`);
        }
        const load = COMPONENTS[example.component] || COMPONENTS.echarts;
        const { Component, styles } = await load();
        root = createRoot(styles ? isolatedContainer(el, styles) : el);
        roots.set(el, root);
        root.render(<Component {...propsOf(example, el)} />);
    } catch (e) {
        if (!root) {
            root = createRoot(el);
            roots.set(el, root);
        }
        root.render(<div role="alert" className="psu-example-error">Example {id}: {String(e && e.message ? e.message : e)}</div>);
    }
}

// pages change without a reload (Zensical's instant navigation): mount new placeholders, free old ones
function scan() {
    for (const [el, root] of roots) {
        if (!el.isConnected) {
            if (root) {
                root.unmount();
            }
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
