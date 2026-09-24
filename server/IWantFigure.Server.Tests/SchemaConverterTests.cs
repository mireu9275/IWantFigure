using System.Text.Json.Nodes;
using IWantFigure.Server.Analysis;
using IWantFigure.Server.Providers;

namespace IWantFigure.Server.Tests;

public class SchemaConverterTests
{
    private static readonly string[] ForbiddenForGemini = { "$schema", "additionalProperties", "title", "$id" };

    [Fact]
    public void Gemini_schema_has_no_unsupported_keywords_anywhere()
    {
        JsonObject converted = GeminiSchemaConverter.Convert(AnalysisSchema.Embedded.Root);

        var keys = new List<string>();
        CollectKeys(converted, keys);

        Assert.DoesNotContain(keys, k => ForbiddenForGemini.Contains(k));
        Assert.DoesNotContain("$schema", converted.ToJsonString());
        Assert.DoesNotContain("additionalProperties", converted.ToJsonString());
    }

    [Fact]
    public void Gemini_schema_keeps_structure_enums_and_required()
    {
        JsonObject converted = GeminiSchemaConverter.Convert(AnalysisSchema.Embedded.Root);

        Assert.Equal("OBJECT", converted["type"]!.GetValue<string>());
        Assert.Equal(8, converted["required"]!.AsArray().Count);
        Assert.Equal(8, converted["propertyOrdering"]!.AsArray().Count);

        JsonNode layout = converted["properties"]!["layout_type"]!;
        Assert.Equal("STRING", layout["type"]!.GetValue<string>());
        Assert.Equal(15, layout["enum"]!.AsArray().Count);
        Assert.Contains("bridge_parallel", layout["enum"]!.AsArray().Select(n => n!.GetValue<string>()));

        JsonNode objects = converted["properties"]!["objects"]!;
        Assert.Equal("ARRAY", objects["type"]!.GetValue<string>());
        Assert.Equal("OBJECT", objects["items"]!["type"]!.GetValue<string>());
        Assert.Equal("NUMBER", objects["items"]!["properties"]!["bbox"]!["items"]!["type"]!.GetValue<string>());
        Assert.Equal("INTEGER", converted["properties"]!["machine"]!["properties"]!["claw_count"]!["type"]!.GetValue<string>());
        Assert.NotNull(converted["description"]); // descriptions are allowed and useful
    }

    [Fact]
    public void Claude_schema_drops_document_keywords_but_keeps_additionalProperties_false()
    {
        JsonObject converted = ClaudeSchemaConverter.Convert(AnalysisSchema.Embedded.Root);

        Assert.False(converted.ContainsKey("$schema"));
        Assert.False(converted.ContainsKey("title"));
        Assert.False(converted["additionalProperties"]!.GetValue<bool>());
        Assert.False(converted["properties"]!["machine"]!["additionalProperties"]!.GetValue<bool>());
        Assert.Equal("object", converted["type"]!.GetValue<string>());
        Assert.Equal(8, converted["required"]!.AsArray().Count);
    }

    private static void CollectKeys(JsonNode? node, List<string> keys)
    {
        switch (node)
        {
            case JsonObject obj:
                foreach (KeyValuePair<string, JsonNode?> kv in obj)
                {
                    keys.Add(kv.Key);
                    CollectKeys(kv.Value, keys);
                }
                break;
            case JsonArray arr:
                foreach (JsonNode? item in arr)
                {
                    CollectKeys(item, keys);
                }
                break;
        }
    }
}
