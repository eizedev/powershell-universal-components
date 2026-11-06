/*
 * Labels of a time axis in the chart's locale. ECharts' own labels write the bare day of the month at a
 * day boundary ("22:00, 23:00, 5, 01:00"), which says nothing on its own, and English month names in
 * every locale. Here a boundary gets a date the reader recognises ("5 Nov", "5. Nov."), the ticks in
 * between their time; the boundary keeps ECharts' bold "primary" style.
 */

const FINER_THAN_DAY = new Set(["hour", "minute", "second", "millisecond"]);

// the unit a tick lies on when ECharts gives none (custom ticks): the largest one it starts
function unitOf(date) {
    if (date.getMilliseconds()) return "millisecond";
    if (date.getSeconds()) return "second";
    if (date.getMinutes()) return "minute";
    if (date.getHours()) return "hour";
    if (date.getDate() !== 1) return "day";
    if (date.getMonth() !== 0) return "month";
    return "year";
}

export function timeAxisFormatter(locale) {
    const cache = new Map();
    const fmt = (options) => {
        const key = JSON.stringify(options);
        if (!cache.has(key)) cache.set(key, new Intl.DateTimeFormat(locale, options));
        return cache.get(key);
    };
    const text = {
        millisecond: (d) => `${fmt({ hour: "2-digit", minute: "2-digit", second: "2-digit", hourCycle: "h23" }).format(d)}.${String(d.getMilliseconds()).padStart(3, "0")}`,
        second: (d) => fmt({ hour: "2-digit", minute: "2-digit", second: "2-digit", hourCycle: "h23" }).format(d),
        minute: (d) => fmt({ hour: "2-digit", minute: "2-digit", hourCycle: "h23" }).format(d),
        hour: (d) => fmt({ hour: "2-digit", minute: "2-digit", hourCycle: "h23" }).format(d),
        day: (d) => fmt({ day: "numeric", month: "short" }).format(d),
        month: (d) => fmt({ month: "short" }).format(d),
        dayMonthYear: (d) => fmt({ day: "numeric", month: "short", year: "numeric" }).format(d),
        year: (d) => fmt({ year: "numeric" }).format(d)
    };
    // (value, index, extra): extra.time tells the step of the axis (lowerTimeUnit) and the boundary the
    // tick lies on (upperTimeUnit)
    return (value, index, extra) => {
        const d = new Date(value);
        if (Number.isNaN(d.getTime())) return "";
        const t = extra && extra.time;
        const step = t && t.lowerTimeUnit ? t.lowerTimeUnit : unitOf(d);
        const boundary = t && t.upperTimeUnit ? t.upperTimeUnit : step;
        let label;
        if (boundary === step || !text[boundary]) {
            label = text[step] ? text[step](d) : text.dayMonthYear(d);
        } else if (FINER_THAN_DAY.has(step)) {
            // an axis in hours that crosses midnight: the date, with the year at a year boundary
            label = boundary === "year" ? text.dayMonthYear(d) : text.day(d);
        } else {
            label = text[boundary](d);
        }
        // "{" and "|" would start ECharts' rich text; Intl output has neither, the guard keeps it so
        label = label.replace(/[{}|]/g, "");
        return boundary === step ? label : `{primary|${label}}`;
    };
}
