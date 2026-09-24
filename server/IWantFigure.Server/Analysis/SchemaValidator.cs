using System.Globalization;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace IWantFigure.Server.Analysis;

/// <summary>
/// A deliberately small JSON-Schema checker: type, required, enum, properties,
/// additionalProperties:false and items. That is everything analysis.schema.json uses,
/// so we do not need a full validator package. Returns a list of human-readable errors
/// (empty = valid).
/// </summary>
public static class SchemaValidator
{
    public static IReadOnlyList<string> Validate(JsonElement schema, JsonNode? instance)
    {
        var errors = new List<string>();
        Check(schema, instance, "$", errors);
        return errors;
    }

    private static void Check(JsonElement schema, JsonNode? node, string path, List<string> errors)
    {
        // -- type ------------------------------------------------------------------
        if (schema.TryGetProperty("type", out JsonElement typeEl) && typeEl.ValueKind == JsonValueKind.String)
        {
            string expected = typeEl.GetString() ?? "";
            if (!MatchesType(expected, node))
            {
                errors.Add($"{path}: expected {expected}, got {Describe(node)}");
                return; // no point checking children of the wrong type
            }
        }

        // -- enum ------------------------------------------------------------------
        if (schema.TryGetProperty("enum", out JsonElement enumEl) && enumEl.ValueKind == JsonValueKind.Array)
        {
            string? actual = node is JsonValue v && v.TryGetValue(out string? s) ? s : null;
            bool found = false;
            foreach (JsonElement allowed in enumEl.EnumerateArray())
            {
                if (allowed.ValueKind == JsonValueKind.String && allowed.GetString() == actual)
                {
                    found = true;
                    break;
                }
            }
            if (!found)
            {
                errors.Add($"{path}: '{actual}' is not one of the allowed enum values");
            }
        }

        // -- object keywords -------------------------------------------------------
        if (node is JsonObject obj)
        {
            if (schema.TryGetProperty("required", out JsonElement requiredEl) && requiredEl.ValueKind == JsonValueKind.Array)
            {
                foreach (JsonElement req in requiredEl.EnumerateArray())
                {
                    string key = req.GetString() ?? "";
                    if (!obj.ContainsKey(key))
                    {
                        errors.Add($"{path}: missing required property '{key}'");
                    }
                }
            }

            bool hasProps = schema.TryGetProperty("properties", out JsonElement propsEl) && propsEl.ValueKind == JsonValueKind.Object;
            bool noExtras = schema.TryGetProperty("additionalProperties", out JsonElement apEl) && apEl.ValueKind == JsonValueKind.False;

            foreach (KeyValuePair<string, JsonNode?> kv in obj)
            {
                if (hasProps && propsEl.TryGetProperty(kv.Key, out JsonElement propSchema))
                {
                    Check(propSchema, kv.Value, $"{path}.{kv.Key}", errors);
                }
                else if (noExtras)
                {
                    errors.Add($"{path}: unexpected property '{kv.Key}'");
                }
            }
        }

        // -- array keywords --------------------------------------------------------
        if (node is JsonArray arr && schema.TryGetProperty("items", out JsonElement itemsEl) && itemsEl.ValueKind == JsonValueKind.Object)
        {
            for (int i = 0; i < arr.Count; i++)
            {
                Check(itemsEl, arr[i], $"{path}[{i}]", errors);
            }
        }
    }

    private static bool MatchesType(string expected, JsonNode? node)
    {
        switch (expected)
        {
            case "object": return node is JsonObject;
            case "array": return node is JsonArray;
            case "null": return node is null;
            case "string": return node is JsonValue sv && sv.GetValueKind() == JsonValueKind.String;
            case "boolean":
                return node is JsonValue bv && bv.GetValueKind() is JsonValueKind.True or JsonValueKind.False;
            case "number": return node is JsonValue nv && nv.GetValueKind() == JsonValueKind.Number;
            case "integer":
                if (node is not JsonValue iv || iv.GetValueKind() != JsonValueKind.Number) return false;
                // Accept 2 and 2.0 but not 2.5.
                return iv.TryGetValue(out double d) && Math.Abs(d - Math.Round(d)) < double.Epsilon
                    || long.TryParse(iv.ToJsonString(), NumberStyles.Integer, CultureInfo.InvariantCulture, out _);
            default: return true; // unknown type keyword: don't fail
        }
    }

    private static string Describe(JsonNode? node) => node switch
    {
        null => "null",
        JsonObject => "object",
        JsonArray => "array",
        JsonValue v => v.GetValueKind().ToString().ToLowerInvariant(),
        _ => node.GetType().Name,
    };
}
