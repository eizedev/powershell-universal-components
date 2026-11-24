/*
 * The language of a chart's texts, from -Locale or the browser: ECharts' own texts (locales.js
 * registers their files under these names) and the module's (texts.js). No ECharts import, so the
 * option builder and the unit tests can use it.
 */
export const LANGUAGES = ["DE", "FR", "ES", "IT", "NL", "PL", "CS", "SV", "FI", "nb-NO", "PT-br", "RU", "UK", "TR", "JA", "ZH", "KO"];

// "de-DE" -> "DE", "pt-BR" -> "PT-br", "nb"/"no" -> "nb-NO"; anything unknown -> "EN"
export function echartsLocale(tag) {
    const lower = String(tag || "en").toLowerCase();
    const lang = lower.split("-")[0];
    if (lang === "pt" && lower.includes("br")) {
        return "PT-br";
    }
    if (lang === "nb" || lang === "no" || lang === "nn") {
        return "nb-NO";
    }
    const upper = lang.toUpperCase();
    return LANGUAGES.includes(upper) ? upper : "EN";
}
