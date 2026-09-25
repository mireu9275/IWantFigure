using System.Text.Json.Nodes;
using IWantFigure.Server.Analysis;
using IWantFigure.Server.Models;
using IWantFigure.Server.Providers;
using IWantFigure.Server.Tests.Support;

namespace IWantFigure.Server.Tests;

public class NormalizerTests
{
    private static readonly AnalysisNormalizer Normalizer = new(AnalysisSchema.Embedded);

    private static AnalysisDocument Run(string json, CoordinateConvention convention, int w = 1456, int h = 971) =>
        Normalizer.Normalize(new ProviderResult(json, convention), w, h);

    private static DetectedObject Obj(AnalysisDocument doc, string id) => Assert.Single(doc.Objects, o => o.Id == id);

    // ---------------------------------------------------------------- coordinate conventions

    [Fact]
    public void Mock_sample_passes_through_unchanged()
    {
        AnalysisDocument doc = Run(SampleJson.Normalized, CoordinateConvention.NormalizedUnit);

        Assert.Equal("bridge_parallel", doc.LayoutType);
        Assert.Equal(0.82, doc.Confidence, 6);
        Assert.Equal(5, doc.Objects.Count);
        Assert.Equal(new[] { 0.36, 0.42, 0.64, 0.74 }, Obj(doc, "box1").Bbox);
        Assert.Equal("box1", doc.Strategy.TargetObjectId);
        Assert.Equal("tate_hame", doc.Strategy.Technique);
    }

    [Fact]
    public void Gemini_thousandths_ymin_xmin_ymax_xmax_become_normalized_x1y1x2y2()
    {
        AnalysisDocument doc = Run(SampleJson.GeminiThousandths(), CoordinateConvention.NormalizedThousandths);

        Assert.Equal(new[] { 0.36, 0.42, 0.64, 0.74 }, Obj(doc, "box1").Bbox);
        Assert.Equal(new[] { 0.12, 0.70, 0.88, 0.73 }, Obj(doc, "bar_front").Bbox);
    }

    [Fact]
    public void Gemini_box_2d_alias_is_accepted()
    {
        const string json = """
        {"layout_type":"floor_box","confidence":0.6,
         "machine":{"claw_count":2,"arm_power_estimate":"unknown","assist_lamp":"none","exit_side":"front"},
         "objects":[{"id":"b","kind":"box","box_2d":[100,200,500,600],"notes":""}],
         "strategy":{"technique":"mochiage","target_object_id":"b","target_edge":"front","arm":"left","sequence":[],"abort_if":[],"expected_motion":""},
         "explanation":"","needs_more_photos":[],"warnings":[]}
        """;
        AnalysisDocument doc = Run(json, CoordinateConvention.NormalizedThousandths);

        Assert.Equal(new[] { 0.2, 0.1, 0.6, 0.5 }, Obj(doc, "b").Bbox);
    }

    [Fact]
    public void Gemini_values_already_in_0_1_keep_geminis_axis_order()
    {
        // The model skipped the x1000 scale but still answered in its native [ymin, xmin, ymax, xmax] order.
        JsonObject root = JsonNode.Parse(SampleJson.Normalized)!.AsObject();
        root["objects"]![0]!["bbox"] = new JsonArray(0.42, 0.36, 0.74, 0.64);

        AnalysisDocument doc = Run(root.ToJsonString(), CoordinateConvention.NormalizedThousandths);

        Assert.Equal(new[] { 0.36, 0.42, 0.64, 0.74 }, Obj(doc, "box1").Bbox);
    }

    [Fact]
    public void Claude_pixels_are_divided_by_sent_image_size()
    {
        const int w = 1456, h = 971;
        AnalysisDocument doc = Run(SampleJson.ClaudePixels(w, h), CoordinateConvention.AbsolutePixels, w, h);

        double[] box = Obj(doc, "box1").Bbox;
        Assert.Equal(Math.Round(Math.Round(0.36 * w) / w, 4), box[0], 4);
        Assert.Equal(Math.Round(Math.Round(0.42 * h) / h, 4), box[1], 4);
        Assert.Equal(Math.Round(Math.Round(0.64 * w) / w, 4), box[2], 4);
        Assert.Equal(Math.Round(Math.Round(0.74 * h) / h, 4), box[3], 4);
        // sanity: within 1 px of the original normalized value
        Assert.InRange(box[0], 0.36 - 1.0 / w, 0.36 + 1.0 / w);
        Assert.InRange(box[3], 0.74 - 1.0 / h, 0.74 + 1.0 / h);
    }

    [Fact]
    public void Claude_values_that_are_already_normalized_are_not_divided_again()
    {
        // The model ignored the pixel instruction and answered in 0..1 - keep them usable.
        JsonObject root = JsonNode.Parse(SampleJson.Normalized)!.AsObject();
        AnalysisDocument doc = Run(root.ToJsonString(), CoordinateConvention.AbsolutePixels);

        Assert.Equal(new[] { 0.36, 0.42, 0.64, 0.74 }, Obj(doc, "box1").Bbox);
    }

    // ---------------------------------------------------------------- clamping & cleanup

    [Fact]
    public void Boxes_are_clamped_and_corners_ordered()
    {
        JsonObject root = JsonNode.Parse(SampleJson.Normalized)!.AsObject();
        root["objects"]![0]!["bbox"] = new JsonArray(1.4, 0.9, -0.2, 0.5); // x2<x1, y2<y1, out of range
        root["confidence"] = 1.7;

        AnalysisDocument doc = Run(root.ToJsonString(), CoordinateConvention.NormalizedUnit);

        Assert.Equal(new[] { 0.0, 0.5, 1.0, 0.9 }, Obj(doc, "box1").Bbox);
        Assert.Equal(1.0, doc.Confidence);
    }

    [Fact]
    public void Negative_confidence_becomes_zero_and_claw_count_never_negative()
    {
        JsonObject root = JsonNode.Parse(SampleJson.Normalized)!.AsObject();
        root["confidence"] = -0.3;
        root["machine"]!["claw_count"] = -2;

        AnalysisDocument doc = Run(root.ToJsonString(), CoordinateConvention.NormalizedUnit);

        Assert.Equal(0.0, doc.Confidence);
        Assert.Equal(0, doc.Machine.ClawCount);
    }

    [Theory]
    [InlineData(1e12, 5)]      // would saturate to int.MaxValue without clamping on the double
    [InlineData(3.4, 3)]
    [InlineData(2.6, 3)]
    [InlineData(99, 5)]
    [InlineData(-7, 0)]
    public void Claw_count_is_clamped_to_0_5(double input, int expected)
    {
        JsonObject root = JsonNode.Parse(SampleJson.Normalized)!.AsObject();
        root["machine"]!["claw_count"] = input;

        AnalysisDocument doc = Run(root.ToJsonString(), CoordinateConvention.NormalizedUnit);

        Assert.Equal(expected, doc.Machine.ClawCount);
    }

    [Fact]
    public void Objects_with_empty_boxes_are_dropped()
    {
        JsonObject root = JsonNode.Parse(SampleJson.Normalized)!.AsObject();
        root["objects"]![1]!["bbox"] = new JsonArray(0.5, 0.2, 0.5, 0.9);      // zero width
        root["objects"]![2]!["bbox"] = new JsonArray(0.1, 0.2, 0.9);           // 3 numbers
        root["objects"]![3]!["bbox"] = new JsonArray("a", "b", "c", "d");      // not numbers

        AnalysisDocument doc = Run(root.ToJsonString(), CoordinateConvention.NormalizedUnit);

        Assert.Equal(new[] { "box1", "hole1" }, doc.Objects.Select(o => o.Id));
    }

    // ---------------------------------------------------------------- enums

    [Theory]
    [InlineData("bridge_four")]
    [InlineData("bridge_mixed")]
    [InlineData("hang_string")]
    public void Newer_layout_types_pass_through(string layoutType)
    {
        JsonObject root = JsonNode.Parse(SampleJson.Normalized)!.AsObject();
        root["layout_type"] = layoutType;

        AnalysisDocument doc = Run(root.ToJsonString(), CoordinateConvention.NormalizedUnit);

        Assert.Equal(layoutType, doc.LayoutType);
    }

    [Fact]
    public void Invalid_enum_values_fall_back_to_safe_defaults()
    {
        JsonObject root = JsonNode.Parse(SampleJson.Normalized)!.AsObject();
        root["layout_type"] = "bridge_paralel";
        root["machine"]!["arm_power_estimate"] = "hulk";
        root["machine"]!["assist_lamp"] = "purple";
        root["machine"]!["exit_side"] = "top";
        root["objects"]![0]!["kind"] = "cardboard";
        root["strategy"]!["technique"] = "grab";
        root["strategy"]!["target_edge"] = "top";
        root["strategy"]!["arm"] = "middle";

        AnalysisDocument doc = Run(root.ToJsonString(), CoordinateConvention.NormalizedUnit);

        Assert.Equal("unknown", doc.LayoutType);
        Assert.Equal("unknown", doc.Machine.ArmPowerEstimate);
        Assert.Equal("unknown", doc.Machine.AssistLamp);
        Assert.Equal("unknown", doc.Machine.ExitSide);
        Assert.Equal("other", Obj(doc, "box1").Kind);
        Assert.Equal("unknown", doc.Strategy.Technique);
        Assert.Equal("center", doc.Strategy.TargetEdge);
        Assert.Equal("both", doc.Strategy.Arm);
    }

    // ---------------------------------------------------------------- target id repair

    [Fact]
    public void Unknown_target_id_is_replaced_by_first_prize_object()
    {
        JsonObject root = JsonNode.Parse(SampleJson.Normalized)!.AsObject();
        root["strategy"]!["target_object_id"] = "ghost";

        AnalysisDocument doc = Run(root.ToJsonString(), CoordinateConvention.NormalizedUnit);

        Assert.Equal("box1", doc.Strategy.TargetObjectId);
    }

    [Fact]
    public void Target_dropped_for_empty_box_falls_back_to_next_prize_or_empty()
    {
        JsonObject root = JsonNode.Parse(SampleJson.Normalized)!.AsObject();
        root["objects"]![0]!["bbox"] = new JsonArray(0.3, 0.3, 0.3, 0.3); // box1 becomes empty

        AnalysisDocument doc = Run(root.ToJsonString(), CoordinateConvention.NormalizedUnit);

        Assert.DoesNotContain(doc.Objects, o => o.Id == "box1");
        Assert.Equal("", doc.Strategy.TargetObjectId); // no other box/plush left
    }

    [Fact]
    public void Duplicate_object_ids_are_made_unique()
    {
        JsonObject root = JsonNode.Parse(SampleJson.Normalized)!.AsObject();
        root["objects"]![1]!["id"] = "box1";
        root["objects"]![2]!["id"] = "box1";

        AnalysisDocument doc = Run(root.ToJsonString(), CoordinateConvention.NormalizedUnit);

        Assert.Equal(new[] { "box1", "box1_2", "box1_3", "claw1", "hole1" }, doc.Objects.Select(o => o.Id));
    }

    // ---------------------------------------------------------------- robustness

    [Fact]
    public void Missing_sections_are_filled_with_defaults_and_still_validate()
    {
        const string json = """{"layout_type":"pile","confidence":"0.4"}""";

        AnalysisDocument doc = Run(json, CoordinateConvention.AbsolutePixels);

        Assert.Equal("pile", doc.LayoutType);
        Assert.Equal(0.4, doc.Confidence, 6);
        Assert.Equal(0, doc.Machine.ClawCount);
        Assert.Empty(doc.Objects);
        Assert.Equal("", doc.Strategy.TargetObjectId);
        Assert.Empty(doc.Strategy.Sequence);
        Assert.Empty(doc.NeedsMorePhotos);
        Assert.Empty(doc.Warnings);
    }

    [Fact]
    public void Code_fences_and_surrounding_prose_are_tolerated()
    {
        string json = "Here you go:\n```json\n" + SampleJson.Normalized + "\n```\nHope that helps!";

        AnalysisDocument doc = Run(json, CoordinateConvention.NormalizedUnit);

        Assert.Equal("bridge_parallel", doc.LayoutType);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("I cannot see a crane game in this picture.")]
    [InlineData("{\"layout_type\": ")]
    [InlineData("[1,2,3]")]
    public void Unparseable_text_throws_AnalysisFormatException(string text)
    {
        Assert.Throws<AnalysisFormatException>(() => Run(text, CoordinateConvention.NormalizedUnit));
    }

    [Fact]
    public void Schema_validator_rejects_a_document_with_a_bad_enum()
    {
        JsonNode? node = JsonNode.Parse(SampleJson.Normalized);
        node!["strategy"]!["arm"] = "middle";

        IReadOnlyList<string> errors = SchemaValidator.Validate(AnalysisSchema.Embedded.Root, node);

        Assert.Contains(errors, e => e.Contains("strategy.arm"));
    }

    [Fact]
    public void Schema_validator_accepts_the_sample()
    {
        IReadOnlyList<string> errors = SchemaValidator.Validate(AnalysisSchema.Embedded.Root, JsonNode.Parse(SampleJson.Normalized));

        Assert.Empty(errors);
    }
}
