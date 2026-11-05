/*
 * ECharts' own texts (toolbox titles, "restore", data view, aria descriptions) in the user's language.
 * English is built in; these are registered once. The chart picks the language from -Locale or the
 * browser (de-DE -> DE).
 */
import DE from "echarts/lib/i18n/langDE.js";
import FR from "echarts/lib/i18n/langFR.js";
import ES from "echarts/lib/i18n/langES.js";
import IT from "echarts/lib/i18n/langIT.js";
import NL from "echarts/lib/i18n/langNL.js";
import PL from "echarts/lib/i18n/langPL.js";
import CS from "echarts/lib/i18n/langCS.js";
import SV from "echarts/lib/i18n/langSV.js";
import FI from "echarts/lib/i18n/langFI.js";
import NB from "echarts/lib/i18n/langnb-NO.js";
import PTBR from "echarts/lib/i18n/langPT-br.js";
import RU from "echarts/lib/i18n/langRU.js";
import UK from "echarts/lib/i18n/langUK.js";
import TR from "echarts/lib/i18n/langTR.js";
import JA from "echarts/lib/i18n/langJA.js";
import ZH from "echarts/lib/i18n/langZH.js";
import KO from "echarts/lib/i18n/langKO.js";

const LOCALES = { DE, FR, ES, IT, NL, PL, CS, SV, FI, "nb-NO": NB, "PT-br": PTBR, RU, UK, TR, JA, ZH, KO };
let registered = false;

export function registerLocales(echarts) {
    if (registered) {
        return;
    }
    for (const [name, obj] of Object.entries(LOCALES)) {
        echarts.registerLocale(name, obj);
    }
    registered = true;
}

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
    return upper in LOCALES ? upper : "EN";
}
