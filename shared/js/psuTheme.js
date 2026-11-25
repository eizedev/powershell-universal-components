import { useEffect, useState } from "react";

/*
 * PowerShell Universal gives custom components no theme object (UniversalDashboard.design is false,
 * measured on 2026.3.4). Light or dark is the attribute data-theme on <html>, switched live by the
 * app's toggle; the colours are whatever PSU's MUI styles computed on the page.
 */

function cssColor(element, property) {
    if (!element) {
        return undefined;
    }
    const value = getComputedStyle(element)[property];
    // transparent backgrounds say nothing about the theme
    return value && value !== "rgba(0, 0, 0, 0)" && value !== "transparent" ? value : undefined;
}

export function readPsuTheme() {
    const root = document.documentElement;
    const mode = root.getAttribute("data-theme") === "dark" ? "dark" : "light";
    const body = document.body;
    const paper = document.querySelector(".MuiCard-root, .MuiPaper-root:not(.MuiAppBar-root)");
    const bar = document.querySelector(".MuiAppBar-root");
    return {
        mode,
        background: cssColor(body, "backgroundColor"),
        surface: cssColor(paper, "backgroundColor"),
        text: cssColor(body, "color"),
        primary: cssColor(bar, "backgroundColor"),
        fontFamily: getComputedStyle(body).fontFamily
    };
}

// Re-renders the caller whenever PSU switches between light and dark.
export function usePsuTheme() {
    const [theme, setTheme] = useState(readPsuTheme);
    useEffect(() => {
        // the same colours again (data-theme set to the value it has) keep the object: no new render,
        // and effects that depend on the theme do not run again
        const observer = new MutationObserver(() => {
            const next = readPsuTheme();
            setTheme((previous) => (JSON.stringify(previous) === JSON.stringify(next) ? previous : next));
        });
        observer.observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] });
        return () => observer.disconnect();
    }, []);
    return theme;
}

/*
 * The effective mode of a component: "auto" follows PSU, "light"/"dark" pin it.
 */
export function effectiveMode(requested, psuTheme) {
    if (requested === "light" || requested === "dark") {
        return requested;
    }
    return psuTheme.mode;
}
