/*
 * Documentation site: every example is the PowerShell that produced it (run by Build-Site.ps1 with the
 * real New-UDEChart) and the chart that the same React component draws in PSU. Events that would run
 * a script block on the server show their $EventData here instead.
 */
import React, { useEffect, useState } from "react";
import { createRoot } from "react-dom/client";
import EChart from "../../../modules/PowerShellUniversal.Component.ECharts/Components/EChart.jsx";

const site = JSON.parse(document.getElementById("site-data").textContent);
const EVENTS = { onClick: "-OnClick", onSelect: "-OnSelect", onZoom: "-OnZoom", onLegendChange: "-OnLegendChange" };

function slug(text) {
    return String(text).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
}

function useTheme() {
    const initial = (() => {
        try {
            return localStorage.getItem("site-theme") || (window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light");
        } catch (e) {
            return "light";
        }
    })();
    const [theme, setTheme] = useState(initial);
    useEffect(() => {
        // the attribute PSU uses: the chart component follows it exactly as inside an app
        document.documentElement.setAttribute("data-theme", theme);
        try {
            localStorage.setItem("site-theme", theme);
        } catch (e) {
            // private window: the choice is not remembered
        }
    }, [theme]);
    return [theme, setTheme];
}

function Toast({ toast }) {
    if (!toast) {
        return null;
    }
    return (
        <div className="toast" role="status">
            <strong>{toast.name}</strong> would run on the server with <code>$EventData</code>:
            <pre>{JSON.stringify(toast.data, null, 2)}</pre>
        </div>
    );
}

function Code({ text }) {
    const [copied, setCopied] = useState(false);
    const copy = () => {
        if (navigator.clipboard) {
            navigator.clipboard.writeText(text).then(() => {
                setCopied(true);
                setTimeout(() => setCopied(false), 1500);
            });
        }
    };
    return (
        <div className="code">
            <button type="button" className="copy" onClick={copy}>{copied ? "Copied" : "Copy"}</button>
            <pre><code>{text}</code></pre>
        </div>
    );
}

function Example({ example, onEvent }) {
    const props = { ...example.props, setState: () => {} };
    for (const [key, name] of Object.entries(EVENTS)) {
        if (props[key] === "__event__") {
            props[key] = (data) => onEvent(name, data);
        }
    }
    return (
        <section className="example" id={slug(example.title)}>
            <h3>{example.title}</h3>
            {example.text && <p>{example.text}</p>}
            <div className="chart">
                <EChart {...props} />
            </div>
            <Code text={example.code} />
        </section>
    );
}

function Reference() {
    return (
        <section id="reference">
            <h2>Reference</h2>
            {site.commands.map((command) => (
                <div key={command.name} className="command" id={slug(command.name)}>
                    <h3>{command.name}</h3>
                    <p>{command.synopsis}</p>
                    {command.description && <p className="description">{command.description}</p>}
                    <table>
                        <thead><tr><th>Parameter</th><th>Type</th><th>Description</th></tr></thead>
                        <tbody>
                            {command.parameters.map((p) => (
                                <tr key={p.name}>
                                    <td><code>-{p.name}</code>{p.required ? " (required)" : ""}</td>
                                    <td><code>{p.type}</code></td>
                                    <td>{p.description}</td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            ))}
        </section>
    );
}

function App() {
    const [theme, setTheme] = useTheme();
    const [toast, setToast] = useState(null);
    const sections = [...new Set(site.examples.map((e) => e.section))];
    const onEvent = (name, data) => {
        setToast({ name, data });
        clearTimeout(window.__toastTimer);
        window.__toastTimer = setTimeout(() => setToast(null), 6000);
    };
    return (
        <div className="layout">
            <nav aria-label="Contents">
                <div className="brand">{site.title}</div>
                <button type="button" className="theme" onClick={() => setTheme(theme === "dark" ? "light" : "dark")}>
                    {theme === "dark" ? "Light theme" : "Dark theme"}
                </button>
                <a href="#start">Start</a>
                {sections.map((s) => <a key={s} href={`#${slug(s)}`}>{s}</a>)}
                <a href="#reference">Reference</a>
                <a href={site.repository}>Repository</a>
            </nav>
            <main>
                <section id="start" className="intro">
                    <h1>{site.title}</h1>
                    <p>{site.intro}</p>
                    <Code text={site.install} />
                    <p className="small">Version {site.version}. The charts on this page are drawn by the module's own component; events that would call PowerShell show their <code>$EventData</code> instead.</p>
                </section>
                {sections.map((s) => (
                    <div key={s} id={slug(s)} className="section">
                        <h2>{s}</h2>
                        {site.examples.filter((e) => e.section === s).map((e) => <Example key={e.title} example={e} onEvent={onEvent} />)}
                    </div>
                ))}
                <Reference />
            </main>
            <Toast toast={toast} />
        </div>
    );
}

createRoot(document.getElementById("app")).render(<App />);
