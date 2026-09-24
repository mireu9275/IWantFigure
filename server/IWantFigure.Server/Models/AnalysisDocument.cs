using System.Text.Json.Serialization;

namespace IWantFigure.Server.Models;

// ---------------------------------------------------------------------------
// C# mirror of shared/analysis.schema.json. Property names are snake_case on
// the wire (JsonPropertyName) and the JSON order follows the schema.
// The Flutter model (app/lib/models/analysis.dart) parses exactly these names.
// ---------------------------------------------------------------------------

/// <summary>The schema object as produced by the normalizer (no server metadata yet).</summary>
public class AnalysisDocument
{
    [JsonPropertyName("layout_type"), JsonPropertyOrder(10)]
    public string LayoutType { get; set; } = "unknown";

    /// <summary>0..1</summary>
    [JsonPropertyName("confidence"), JsonPropertyOrder(11)]
    public double Confidence { get; set; }

    [JsonPropertyName("machine"), JsonPropertyOrder(12)]
    public MachineInfo Machine { get; set; } = new();

    [JsonPropertyName("objects"), JsonPropertyOrder(13)]
    public List<DetectedObject> Objects { get; set; } = new();

    [JsonPropertyName("strategy"), JsonPropertyOrder(14)]
    public Strategy Strategy { get; set; } = new();

    [JsonPropertyName("explanation"), JsonPropertyOrder(15)]
    public string Explanation { get; set; } = "";

    [JsonPropertyName("needs_more_photos"), JsonPropertyOrder(16)]
    public List<string> NeedsMorePhotos { get; set; } = new();

    [JsonPropertyName("warnings"), JsonPropertyOrder(17)]
    public List<string> Warnings { get; set; } = new();
}

public sealed class MachineInfo
{
    /// <summary>2, 3, or 0 when unknown.</summary>
    [JsonPropertyName("claw_count")]
    public int ClawCount { get; set; }

    [JsonPropertyName("arm_power_estimate")]
    public string ArmPowerEstimate { get; set; } = "unknown";

    [JsonPropertyName("assist_lamp")]
    public string AssistLamp { get; set; } = "unknown";

    [JsonPropertyName("exit_side")]
    public string ExitSide { get; set; } = "unknown";
}

public sealed class DetectedObject
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = "";

    [JsonPropertyName("kind")]
    public string Kind { get; set; } = "other";

    /// <summary>[x1, y1, x2, y2] normalized to 0..1 of the analyzed image, origin top-left.</summary>
    [JsonPropertyName("bbox")]
    public double[] Bbox { get; set; } = new double[4];

    [JsonPropertyName("notes")]
    public string Notes { get; set; } = "";
}

public sealed class Strategy
{
    [JsonPropertyName("technique")]
    public string Technique { get; set; } = "unknown";

    [JsonPropertyName("target_object_id")]
    public string TargetObjectId { get; set; } = "";

    [JsonPropertyName("target_edge")]
    public string TargetEdge { get; set; } = "center";

    [JsonPropertyName("arm")]
    public string Arm { get; set; } = "both";

    [JsonPropertyName("sequence")]
    public List<string> Sequence { get; set; } = new();

    [JsonPropertyName("abort_if")]
    public List<string> AbortIf { get; set; } = new();

    [JsonPropertyName("expected_motion")]
    public string ExpectedMotion { get; set; } = "";
}

/// <summary>
/// The full 200 response: schema fields plus server metadata. Metadata gets negative
/// JsonPropertyOrder values so it is written first.
/// </summary>
public sealed class AnalysisResponse : AnalysisDocument
{
    [JsonPropertyName("analysis_id"), JsonPropertyOrder(1)]
    public string AnalysisId { get; set; } = "";

    [JsonPropertyName("provider"), JsonPropertyOrder(2)]
    public string Provider { get; set; } = "";

    [JsonPropertyName("model"), JsonPropertyOrder(3)]
    public string Model { get; set; } = "";

    /// <summary>End-to-end server time in milliseconds (image prep + model call + normalization).</summary>
    [JsonPropertyName("latency_ms"), JsonPropertyOrder(4)]
    public int LatencyMs { get; set; }

    /// <summary>Pixel size of the image that was actually sent to the model; the bbox values are normalized to it.</summary>
    [JsonPropertyName("image"), JsonPropertyOrder(5)]
    public ImageInfo Image { get; set; } = new();

    /// <summary>Copies the schema fields from a normalized document.</summary>
    public static AnalysisResponse From(AnalysisDocument doc) => new()
    {
        LayoutType = doc.LayoutType,
        Confidence = doc.Confidence,
        Machine = doc.Machine,
        Objects = doc.Objects,
        Strategy = doc.Strategy,
        Explanation = doc.Explanation,
        NeedsMorePhotos = doc.NeedsMorePhotos,
        Warnings = doc.Warnings,
    };
}

public sealed class ImageInfo
{
    [JsonPropertyName("width")]
    public int Width { get; set; }

    [JsonPropertyName("height")]
    public int Height { get; set; }
}
