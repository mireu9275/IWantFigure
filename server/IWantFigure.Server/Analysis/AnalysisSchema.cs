using System.Text.Json;
using IWantFigure.Server.Shared;

namespace IWantFigure.Server.Analysis;

/// <summary>
/// The embedded shared/analysis.schema.json, parsed once. Besides the raw schema (sent to the
/// providers as the structured-output contract) it exposes the enum lists, so the normalizer
/// validates enum values against the same file the app uses - no duplicated string lists.
/// </summary>
public sealed class AnalysisSchema
{
    // Kept alive for the lifetime of the object; Root is a view into it.
    private readonly JsonDocument _document;

    public AnalysisSchema(string schemaJson)
    {
        _document = JsonDocument.Parse(schemaJson);

        LayoutTypes = EnumOf("properties", "layout_type");
        ArmPower = EnumOf("properties", "machine", "properties", "arm_power_estimate");
        AssistLamps = EnumOf("properties", "machine", "properties", "assist_lamp");
        ExitSides = EnumOf("properties", "machine", "properties", "exit_side");
        ObjectKinds = EnumOf("properties", "objects", "items", "properties", "kind");
        Techniques = EnumOf("properties", "strategy", "properties", "technique");
        TargetEdges = EnumOf("properties", "strategy", "properties", "target_edge");
        Arms = EnumOf("properties", "strategy", "properties", "arm");
    }

    /// <summary>The schema loaded from the embedded resource (process-wide singleton).</summary>
    public static AnalysisSchema Embedded { get; } = new(SharedResources.SchemaJson);

    /// <summary>The root schema element (JSON Schema 2020-12).</summary>
    public JsonElement Root => _document.RootElement;

    public IReadOnlySet<string> LayoutTypes { get; }
    public IReadOnlySet<string> ArmPower { get; }
    public IReadOnlySet<string> AssistLamps { get; }
    public IReadOnlySet<string> ExitSides { get; }
    public IReadOnlySet<string> ObjectKinds { get; }
    public IReadOnlySet<string> Techniques { get; }
    public IReadOnlySet<string> TargetEdges { get; }
    public IReadOnlySet<string> Arms { get; }

    /// <summary>Walks the given property path and returns the "enum" array found there.</summary>
    private HashSet<string> EnumOf(params string[] path)
    {
        JsonElement node = _document.RootElement;
        foreach (string segment in path)
        {
            if (!node.TryGetProperty(segment, out node))
            {
                throw new InvalidOperationException($"Schema path '{string.Join('/', path)}' not found in analysis.schema.json");
            }
        }

        if (!node.TryGetProperty("enum", out JsonElement values) || values.ValueKind != JsonValueKind.Array)
        {
            throw new InvalidOperationException($"Schema path '{string.Join('/', path)}' has no enum");
        }

        var set = new HashSet<string>(StringComparer.Ordinal);
        foreach (JsonElement v in values.EnumerateArray())
        {
            set.Add(v.GetString() ?? "");
        }
        return set;
    }
}
