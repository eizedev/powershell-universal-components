using System;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using System.Globalization;
using System.Management.Automation;
using System.Text.Json;
namespace PivotReportTable
{
    public static class Writer_SUFFIX
    {
        // Each row as a JSON array of its values in the columns' order: a DataRow (or DataRowView) by
        // position, anything else by property name. Returns the rows written, or -1 as soon as the
        // writer holds more than maxBytes (0: no cap), checked every 256 rows.
        public static long WriteRows(Utf8JsonWriter writer, string[] columns, IEnumerable rows, long maxBytes, ICollection<string> dropped)
        {
            HashSet<string> known = new HashSet<string>(columns, StringComparer.OrdinalIgnoreCase);
            long count = 0;
            foreach (object item in rows)
            {
                object row = item is PSObject wrapped ? wrapped.BaseObject : item;
                if (row is DataRowView view) row = view.Row;
                // a row deleted but not yet accepted has no values to read (ItemArray throws): left out
                if (row is DataRow gone && (gone.RowState == DataRowState.Deleted || gone.RowState == DataRowState.Detached)) continue;
                writer.WriteStartArray();
                if (row is DataRow dataRow)
                {
                    foreach (object value in dataRow.ItemArray) WriteValue(writer, value);
                }
                else
                {
                    PSObject properties = PSObject.AsPSObject(item);
                    foreach (string column in columns)
                    {
                        PSPropertyInfo property = properties.Properties[column];
                        WriteValue(writer, property == null ? null : property.Value);
                    }
                    foreach (PSPropertyInfo property in properties.Properties)
                    {
                        if (!known.Contains(property.Name)) dropped.Add(property.Name);
                    }
                }
                writer.WriteEndArray();
                count++;
                if (maxBytes > 0 && (count & 255) == 0 && writer.BytesCommitted + writer.BytesPending > maxBytes) return -1;
            }
            return count;
        }

        // whether every row is a PSCustomObject (Select-Object, Invoke-RestMethod, Import-Csv): those are
        // written by property name as they are, without ConvertTo-PSUComponentData's copy of each row
        public static bool AllCustomObjects(IEnumerable rows)
        {
            bool any = false;
            foreach (object item in rows)
            {
                if (!(item is PSObject wrapped) || !(wrapped.BaseObject is PSCustomObject)) return false;
                any = true;
            }
            return any;
        }

        // text, a finite number, true, false or null; dates as ISO 8601 text, TimeSpans as seconds;
        // anything else as PowerShell's [string] makes it (a list joined with spaces, an object as
        // @{x=1; y=z}), so a report says the same whichever writer wrote its rows
        public static void WriteValue(Utf8JsonWriter writer, object value)
        {
            if (value is PSObject wrapped && !(wrapped.BaseObject is PSCustomObject)) value = wrapped.BaseObject;
            switch (value)
            {
                case null: writer.WriteNullValue(); break;
                case DBNull _: writer.WriteNullValue(); break;
                case string text: writer.WriteStringValue(text); break;
                case bool flag: writer.WriteBooleanValue(flag); break;
                case double d: if (double.IsNaN(d) || double.IsInfinity(d)) writer.WriteNullValue(); else writer.WriteNumberValue(d); break;
                case float f: if (float.IsNaN(f) || float.IsInfinity(f)) writer.WriteNullValue(); else writer.WriteNumberValue((double)f); break;
                case int i: writer.WriteNumberValue(i); break;
                case long l: writer.WriteNumberValue(l); break;
                case short s: writer.WriteNumberValue(s); break;
                case byte b: writer.WriteNumberValue(b); break;
                case sbyte sb: writer.WriteNumberValue(sb); break;
                case ushort us: writer.WriteNumberValue(us); break;
                case uint ui: writer.WriteNumberValue(ui); break;
                case ulong ul: writer.WriteNumberValue(ul); break;
                case decimal m: writer.WriteNumberValue(m); break;
                case DateTime date: writer.WriteStringValue(date.ToString("o", CultureInfo.InvariantCulture)); break;
                case DateTimeOffset offset: writer.WriteStringValue(offset.ToString("o", CultureInfo.InvariantCulture)); break;
                case TimeSpan span: writer.WriteNumberValue(span.TotalSeconds); break;
                default: writer.WriteStringValue(LanguagePrimitives.ConvertTo<string>(value) ?? string.Empty); break;
            }
        }
    }
}
