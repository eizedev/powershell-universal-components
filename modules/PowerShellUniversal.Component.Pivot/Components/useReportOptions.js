import { useMemo } from "react";
import { fieldDefaultsFromSchema } from "pivotkit-core";
import { exportDataLabels, exportDataOf, MAX_OPTIONS_LENGTH, MAX_SCHEMA_LENGTH, mergeFieldDefaults, parseJsonObject, schemaUrlOf, sourceOf, tipsOf } from "./prepare";

/*
 * What -Schema says about the fields (pivotkit-core's fieldDefaultsFromSchema: names, descriptions,
 * https links, types, orders), or undefined. A schema it cannot read is reported in the console and
 * left out; the report works without it.
 */
function schemaDefaults(text, name) {
    const schema = parseJsonObject(text, MAX_SCHEMA_LENGTH);
    if (!schema) return undefined;
    try {
        const { defaults, issues } = fieldDefaultsFromSchema(schema, typeof name === "string" && name ? { schema: name } : {});
        if (issues.length) console.warn("New-UDPivotReport -Schema:", issues.map((i) => `${i.path}: ${i.message}`).join("; "));
        return defaults;
    } catch (e) {
        console.warn("New-UDPivotReport -Schema left out:", e instanceof Error ? e.message : String(e));
        return undefined;
    }
}

// The report's settings from the props: fields, chart options, tips, source, schema address, exports.
export function useReportOptions(props) {
    // ---- fields: -Schema, then -FieldDefaults and -FieldDescriptions over it ---------------------
    const columnsKey = JSON.stringify(props.columnNames ?? null);
    const fieldDefaults = useMemo(
        () => mergeFieldDefaults(schemaDefaults(props.schema, props.schemaName), parseJsonObject(props.fieldDefaults, MAX_SCHEMA_LENGTH), JSON.parse(columnsKey)),
        [props.schema, props.schemaName, props.fieldDefaults, columnsKey]
    );
    const chartOptions = useMemo(() => parseJsonObject(props.chartOptions, MAX_OPTIONS_LENGTH), [props.chartOptions]);
    const tipsKey = JSON.stringify(props.tips ?? null);
    const tips = useMemo(() => tipsOf(JSON.parse(tipsKey)), [tipsKey]);
    const sourceKey = JSON.stringify(props.source ?? null);
    const source = useMemo(() => sourceOf(JSON.parse(sourceKey)), [sourceKey]);
    const schemaUrl = schemaUrlOf(props.schemaUrl);
    const exportDataKey = JSON.stringify(props.exportData ?? null);
    const exportData = useMemo(() => exportDataOf(JSON.parse(exportDataKey)), [exportDataKey]);
    const labelsKey = JSON.stringify(props.labels ?? null);
    const labels = useMemo(() => exportDataLabels(JSON.parse(labelsKey) || undefined, exportData, props.locale), [labelsKey, exportData, props.locale]);
    return { fieldDefaults, chartOptions, tips, source, schemaUrl, exportData, labels };
}
