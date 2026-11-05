/*
 * Named value formats. PowerShell cannot send functions, so labels, axes, tooltips and exports refer
 * to a format by name and this registry turns the name into a function. A name never runs as code.
 *
 *   number[:decimals]     1.234,5           (locale grouping and decimal separator)
 *   integer               1.235
 *   currency[:CODE]       1.234,50 €        (default EUR)
 *   percent[:decimals]    25 %              (value is a fraction: 0.25)
 *   percent100[:decimals] 25 %              (value is already in percent: 25)
 *   compact               1,2 Mio.          (locale short form)
 *   bytes                 1,5 MB            (powers of 1024, B KB MB GB TB)
 *   duration[:unit]       2 h 5 min         (value in s by default; unit ms|s|min|h|d)
 *   date | datetime | time                  (ISO strings or epoch milliseconds)
 *   text                                    (as it is)
 */

const DURATION_SECONDS = { ms: 0.001, s: 1, min: 60, h: 3600, d: 86400 };

export function parseFormat(spec) {
    if (!spec) {
        return null;
    }
    const [name, arg] = String(spec).split(":");
    return { name: name.trim().toLowerCase(), arg: arg === undefined ? undefined : arg.trim() };
}

function toNumber(value) {
    if (value === null || value === undefined || value === "") {
        return NaN;
    }
    return typeof value === "number" ? value : Number(value);
}

function toDate(value) {
    if (value instanceof Date) {
        return value;
    }
    if (typeof value === "number") {
        return new Date(value);
    }
    const d = new Date(value);
    return isNaN(d.getTime()) ? null : d;
}

export function formatDuration(seconds, locale) {
    if (!isFinite(seconds)) {
        return "";
    }
    const sign = seconds < 0 ? "-" : "";
    const total = Math.abs(seconds);
    if (total < 60) {
        return `${sign}${new Intl.NumberFormat(locale, { maximumFractionDigits: 1 }).format(total)} s`;
    }
    // The largest unit that fits, plus the next one when it is not zero: "2 h 5 min", "3 d 4 h"
    const units = [["d", 86400], ["h", 3600], ["min", 60], ["s", 1]];
    const first = units.findIndex(([, size]) => total >= size);
    const [bigLabel, bigSize] = units[first];
    const big = Math.floor(total / bigSize);
    const parts = [`${big} ${bigLabel}`];
    const next = units[first + 1];
    if (next) {
        const small = Math.floor((total - big * bigSize) / next[1]);
        if (small > 0) {
            parts.push(`${small} ${next[0]}`);
        }
    }
    return sign + parts.join(" ");
}

export function formatBytes(bytes, locale) {
    if (!isFinite(bytes)) {
        return "";
    }
    const units = ["B", "KB", "MB", "GB", "TB", "PB"];
    let value = Math.abs(bytes);
    let i = 0;
    while (value >= 1024 && i < units.length - 1) {
        value /= 1024;
        i++;
    }
    const n = new Intl.NumberFormat(locale, { maximumFractionDigits: i === 0 ? 0 : 1 }).format(value);
    return `${bytes < 0 ? "-" : ""}${n} ${units[i]}`;
}

/*
 * A function value -> string for the given format name and locale. Unknown names fall back to
 * locale numbers, so a typo shows numbers instead of breaking the chart.
 */
export function formatter(spec, locale) {
    const f = parseFormat(spec);
    if (!f) {
        return null;
    }
    const decimals = f.arg !== undefined && /^\d+$/.test(f.arg) ? Number(f.arg) : undefined;
    const nf = (options) => {
        const fmt = new Intl.NumberFormat(locale, options);
        return (v) => {
            const n = toNumber(v);
            return isNaN(n) ? (v === null || v === undefined ? "" : String(v)) : fmt.format(n);
        };
    };
    switch (f.name) {
        case "text":
            return (v) => (v === null || v === undefined ? "" : String(v));
        case "integer":
            return nf({ maximumFractionDigits: 0 });
        case "currency":
            return nf({ style: "currency", currency: (f.arg || "EUR").toUpperCase() });
        case "percent":
            return nf({ style: "percent", maximumFractionDigits: decimals ?? 1 });
        case "percent100": {
            const p = nf({ style: "percent", maximumFractionDigits: decimals ?? 1 });
            return (v) => p(toNumber(v) / 100);
        }
        case "compact":
            return nf({ notation: "compact", maximumFractionDigits: 1 });
        case "bytes":
            return (v) => formatBytes(toNumber(v), locale);
        case "duration": {
            const factor = DURATION_SECONDS[f.arg || "s"] ?? 1;
            return (v) => formatDuration(toNumber(v) * factor, locale);
        }
        case "date":
        case "datetime":
        case "time": {
            const opts = f.name === "date" ? { dateStyle: "medium" } : f.name === "time" ? { timeStyle: "short" } : { dateStyle: "medium", timeStyle: "short" };
            const df = new Intl.DateTimeFormat(locale, opts);
            return (v) => {
                const d = toDate(v);
                return d ? df.format(d) : v === null || v === undefined ? "" : String(v);
            };
        }
        case "number":
        default:
            return nf(decimals === undefined ? { maximumFractionDigits: 2 } : { minimumFractionDigits: decimals, maximumFractionDigits: decimals });
    }
}

export function defaultLocale(requested) {
    if (requested) {
        return requested;
    }
    return (typeof navigator !== "undefined" && navigator.language) || "en-US";
}
