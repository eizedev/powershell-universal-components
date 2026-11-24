// The compiled DataTable converter of ConvertTo-PSUComponentData (see Get-PSUComponentRowConverter).
// Get-PSUComponentTypeSource replaces SUFFIX with a hash of this file, so modules built from
// different versions of it never share a class.
using System;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using System.Management.Automation;

namespace PSUComponentData
{
    public static class RowConverter_SUFFIX
    {
        // The rows (DataRows, or the DataRowViews of a DataView) as ConvertTo-PSUComponentData returns
        // them, or null when a column needs the
        // PowerShell rules (types other than strings, numbers, booleans, GUIDs, dates and
        // TimeSpans) or two names differ only in case (an [ordered] dictionary merges them).
        public static object[] Convert(DataTable table, IEnumerable rows)
        {
            int count = table.Columns.Count;
            string[] names = new string[count];
            int[] kinds = new int[count];
            HashSet<string> seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            for (int c = 0; c < count; c++)
            {
                DataColumn column = table.Columns[c];
                names[c] = column.ColumnName;
                if (!seen.Add(column.ColumnName)) return null;
                Type type = column.DataType;
                if (type.IsPrimitive || type == typeof(string) || type == typeof(decimal) || type == typeof(Guid)) kinds[c] = 0;
                else if (type == typeof(DateTime)) kinds[c] = 1;
                else if (type == typeof(DateTimeOffset)) kinds[c] = 2;
                else if (type == typeof(TimeSpan)) kinds[c] = 3;
                else return null;
            }
            List<object> result = new List<object>();
            foreach (object item in rows)
            {
                DataRowView view = item as DataRowView;
                DataRow row = view != null ? view.Row : (DataRow)item;
                PSObject output = new PSObject();
                for (int c = 0; c < count; c++)
                {
                    object value = row[c];
                    if (value is DBNull) value = null;
                    else if (kinds[c] == 1) value = ((DateTime)value).ToString("o");
                    else if (kinds[c] == 2) value = ((DateTimeOffset)value).ToString("o");
                    else if (kinds[c] == 3) value = ((TimeSpan)value).TotalSeconds;
                    output.Properties.Add(new PSNoteProperty(names[c], value));
                }
                result.Add(output);
            }
            return result.ToArray();
        }
    }
}
