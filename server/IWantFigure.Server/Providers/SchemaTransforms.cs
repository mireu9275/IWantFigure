using System.Text.Json;
using System.Text.Json.Nodes;

namespace IWantFigure.Server.Providers;

/// <summary>
/// Converts analysis.schema.json into the OpenAPI-3.0 subset Gemini accepts in
/// generationConfig.responseSchema. Kept keywords: type (upper-cased), description, format,
/// nullable, enum, items, properties, required. Dropped: $schema, title,
/// additionalProperties and everything else Gemini rejects. propertyOrdering is added so
/// the model writes the keys in schema order.
/// </summary>
public static class GeminiSchemaConverter
{
    public static JsonObject Convert(JsonElement schema) => ConvertNode(schema);

    private static JsonObject ConvertNode(JsonElement el)
    {
        var result = new JsonObject();
        foreach (JsonProperty p in el.EnumerateObject())
        {
            switch (p.Name)
            {
                case "type":
                    result["type"] = (p.Value.GetString() ?? "object").ToUpperInvariant();
                    break;

                case "description":
                case "format":
                case "nullable":
                case "enum":
                case "required":
                    result[p.Name] = JsonNode.Parse(p.Value.GetRawText());
                    break;

                case "items":
                    result["items"] = ConvertNode(p.Value);
                    break;

                case "properties":
                    var props = new JsonObject();
                    var order = new JsonArray();
                    foreach (JsonProperty child in p.Value.EnumerateObject())
                    {
                        props[child.Name] = ConvertNode(child.Value);
                        order.Add(child.Name);
                    }
                    result["properties"] = props;
                    result["propertyOrdering"] = order;
                    break;

                default:
                    // $schema, title, additionalProperties, $id, examples, ... - not part of Gemini's Schema type.
                    break;
            }
        }
        return result;
    }
}

/// <summary>
/// Prepares the schema for Claude's structured outputs (output_config.format.schema).
/// Claude accepts standard JSON Schema with additionalProperties:false on every object
/// (which analysis.schema.json already has); only the document-level "$schema" and "title"
/// keywords are removed.
/// </summary>
public static class ClaudeSchemaConverter
{
    public static JsonObject Convert(JsonElement schema)
    {
        JsonObject root = JsonNode.Parse(schema.GetRawText())!.AsObject();
        root.Remove("$schema");
        root.Remove("title");
        return root;
    }
}
