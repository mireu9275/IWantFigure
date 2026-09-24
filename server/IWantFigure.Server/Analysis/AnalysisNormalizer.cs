using System.Globalization;
using System.Text.Json;
using System.Text.Json.Nodes;
using IWantFigure.Server.Models;
using IWantFigure.Server.Providers;
using IWantFigure.Server.Shared;

namespace IWantFigure.Server.Analysis;

/// <summary>
/// Turns the raw LLM text into a schema-valid <see cref="AnalysisDocument"/>:
///  1. parse JSON (tolerating ```json fences and leading chatter),
///  2. convert bounding boxes from the provider's coordinate convention to normalized 0..1 [x1,y1,x2,y2],
///  3. clamp, drop empty boxes, replace invalid enum values with safe fallbacks,
///  4. make sure strategy.target_object_id points at an existing object,
///  5. validate the result against the embedded schema.
/// Anything that cannot be repaired throws <see cref="AnalysisFormatException"/>.
/// </summary>
public sealed class AnalysisNormalizer
{
    private readonly AnalysisSchema _schema;

    public AnalysisNormalizer(AnalysisSchema schema)
    {
        _schema = schema;
    }

    /// <param name="result">Raw provider output.</param>
    /// <param name="imageWidth">Width in pixels of the image that was sent to the model.</param>
    /// <param name="imageHeight">Height in pixels of the image that was sent to the model.</param>
    public AnalysisDocument Normalize(ProviderResult result, int imageWidth, int imageHeight)
    {
        if (imageWidth <= 0 || imageHeight <= 0)
        {
            throw new ArgumentException("image size must be positive");
        }

        JsonObject root = ParseObject(result.RawJson);
        var doc = new AnalysisDocument
        {
            LayoutType = EnumOrDefault(root["layout_type"], _schema.LayoutTypes, "unknown"),
            Confidence = Clamp01(NumberOrDefault(root["confidence"], 0)),
            Explanation = StringOrEmpty(root["explanation"]),
            NeedsMorePhotos = StringList(root["needs_more_photos"]),
            Warnings = StringList(root["warnings"]),
        };

        // ---- machine ----------------------------------------------------------------
        JsonObject? machine = root["machine"] as JsonObject;
        doc.Machine = new MachineInfo
        {
            ClawCount = Math.Max(0, (int)Math.Round(NumberOrDefault(machine?["claw_count"], 0))),
            ArmPowerEstimate = EnumOrDefault(machine?["arm_power_estimate"], _schema.ArmPower, "unknown"),
            AssistLamp = EnumOrDefault(machine?["assist_lamp"], _schema.AssistLamps, "unknown"),
            ExitSide = EnumOrDefault(machine?["exit_side"], _schema.ExitSides, "unknown"),
        };

        // ---- objects ----------------------------------------------------------------
        var usedIds = new HashSet<string>(StringComparer.Ordinal);
        if (root["objects"] is JsonArray objects)
        {
            int index = 0;
            foreach (JsonNode? item in objects)
            {
                index++;
                if (item is not JsonObject o)
                {
                    continue;
                }

                // Gemini models sometimes name the field box_2d even when asked for bbox.
                double[]? bbox = ConvertBox(o["bbox"] ?? o["box_2d"], result.Convention, imageWidth, imageHeight);
                if (bbox is null)
                {
                    continue; // empty / malformed box: the app cannot draw it, drop the object
                }

                string id = StringOrEmpty(o["id"]).Trim();
                if (id.Length == 0)
                {
                    id = $"obj{index}";
                }
                id = MakeUnique(id, usedIds);

                doc.Objects.Add(new DetectedObject
                {
                    Id = id,
                    Kind = EnumOrDefault(o["kind"], _schema.ObjectKinds, "other"),
                    Bbox = bbox,
                    Notes = StringOrEmpty(o["notes"]),
                });
            }
        }

        // ---- strategy ---------------------------------------------------------------
        JsonObject? strategy = root["strategy"] as JsonObject;
        doc.Strategy = new Strategy
        {
            Technique = EnumOrDefault(strategy?["technique"], _schema.Techniques, "unknown"),
            TargetObjectId = RepairTargetId(StringOrEmpty(strategy?["target_object_id"]), doc.Objects),
            TargetEdge = EnumOrDefault(strategy?["target_edge"], _schema.TargetEdges, "center"),
            Arm = EnumOrDefault(strategy?["arm"], _schema.Arms, "both"),
            Sequence = StringList(strategy?["sequence"]),
            AbortIf = StringList(strategy?["abort_if"]),
            ExpectedMotion = StringOrEmpty(strategy?["expected_motion"]),
        };

        // ---- final schema check -----------------------------------------------------
        JsonNode? asNode = JsonSerializer.SerializeToNode(doc, ServerJson.Response);
        IReadOnlyList<string> errors = SchemaValidator.Validate(_schema.Root, asNode);
        if (errors.Count > 0)
        {
            throw new AnalysisFormatException("normalized document does not match analysis.schema.json: " + string.Join("; ", errors));
        }

        return doc;
    }

    // =====================================================================================
    // Parsing helpers
    // =====================================================================================

    /// <summary>Parses the model text as a JSON object, stripping code fences / surrounding prose.</summary>
    internal static JsonObject ParseObject(string raw)
    {
        if (string.IsNullOrWhiteSpace(raw))
        {
            throw new AnalysisFormatException("provider returned empty text");
        }

        string text = raw.Trim();

        // Structured-output modes should never do this, but plain-text fallbacks might wrap JSON in ```json fences
        // or add a sentence before/after. Cut to the outermost { ... }.
        int start = text.IndexOf('{');
        int end = text.LastIndexOf('}');
        if (start < 0 || end <= start)
        {
            throw new AnalysisFormatException("provider text does not contain a JSON object: " + Preview(text));
        }
        text = text.Substring(start, end - start + 1);

        JsonNode? node;
        try
        {
            node = JsonNode.Parse(text, documentOptions: new JsonDocumentOptions
            {
                AllowTrailingCommas = true,
                CommentHandling = JsonCommentHandling.Skip,
            });
        }
        catch (JsonException ex)
        {
            throw new AnalysisFormatException("provider returned invalid JSON: " + ex.Message, ex);
        }

        return node as JsonObject ?? throw new AnalysisFormatException("provider JSON is not an object");
    }

    private static string Preview(string text) => text.Length <= 120 ? text : text[..120] + "...";

    private static string EnumOrDefault(JsonNode? node, IReadOnlySet<string> allowed, string fallback)
    {
        string value = StringOrEmpty(node).Trim();
        return allowed.Contains(value) ? value : fallback;
    }

    private static string StringOrEmpty(JsonNode? node)
    {
        if (node is not JsonValue v)
        {
            return "";
        }
        if (v.TryGetValue(out string? s))
        {
            return s ?? "";
        }
        // number / bool: keep a textual form rather than throwing the whole answer away
        return v.ToJsonString();
    }

    private static double NumberOrDefault(JsonNode? node, double fallback)
    {
        if (node is not JsonValue v)
        {
            return fallback;
        }
        if (v.TryGetValue(out double d))
        {
            return double.IsFinite(d) ? d : fallback;
        }
        // Some models quote numbers: "0.8"
        if (v.TryGetValue(out string? s) && double.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out double parsed) && double.IsFinite(parsed))
        {
            return parsed;
        }
        return fallback;
    }

    private static List<string> StringList(JsonNode? node)
    {
        var list = new List<string>();
        if (node is JsonArray arr)
        {
            foreach (JsonNode? item in arr)
            {
                string s = StringOrEmpty(item);
                if (s.Length > 0)
                {
                    list.Add(s);
                }
            }
        }
        else if (node is JsonValue)
        {
            // A single string where an array was expected: wrap it.
            string s = StringOrEmpty(node);
            if (s.Length > 0)
            {
                list.Add(s);
            }
        }
        return list;
    }

    private static double Clamp01(double v) => Math.Clamp(v, 0.0, 1.0);

    private static string MakeUnique(string id, HashSet<string> used)
    {
        string candidate = id;
        int n = 2;
        while (!used.Add(candidate))
        {
            candidate = $"{id}_{n++}";
        }
        return candidate;
    }

    /// <summary>
    /// The strategy must reference an object the app can highlight. If the id is missing or
    /// was dropped (empty box), fall back to the first prize (box/plush), else "".
    /// </summary>
    private static string RepairTargetId(string requested, List<DetectedObject> objects)
    {
        if (requested.Length > 0 && objects.Any(o => o.Id == requested))
        {
            return requested;
        }
        DetectedObject? prize = objects.FirstOrDefault(o => o.Kind is "box" or "plush");
        return prize?.Id ?? "";
    }

    // =====================================================================================
    // Coordinate conversion
    // =====================================================================================

    /// <summary>
    /// Converts a 4-number box from the provider convention into normalized [x1, y1, x2, y2]
    /// (0..1, origin top-left). Returns null for malformed or empty boxes.
    /// </summary>
    internal static double[]? ConvertBox(JsonNode? node, CoordinateConvention convention, int imageWidth, int imageHeight)
    {
        if (node is not JsonArray arr || arr.Count != 4)
        {
            return null;
        }

        var v = new double[4];
        for (int i = 0; i < 4; i++)
        {
            double d = NumberOrDefault(arr[i], double.NaN);
            if (!double.IsFinite(d))
            {
                return null;
            }
            v[i] = d;
        }

        // Safety net: if a provider ignored the requested convention and already returned
        // 0..1 values, do not divide them again into nothing.
        bool looksNormalized = v.All(x => x is >= 0.0 and <= 1.0) && v.Any(x => x > 0.0);

        double x1, y1, x2, y2;
        switch (convention)
        {
            case CoordinateConvention.NormalizedThousandths when !looksNormalized:
                // Gemini: [ymin, xmin, ymax, xmax] on 0..1000
                y1 = v[0] / 1000.0; x1 = v[1] / 1000.0; y2 = v[2] / 1000.0; x2 = v[3] / 1000.0;
                break;
            case CoordinateConvention.AbsolutePixels when !looksNormalized:
                // Claude: [x1, y1, x2, y2] in pixels of the sent image
                x1 = v[0] / imageWidth; y1 = v[1] / imageHeight; x2 = v[2] / imageWidth; y2 = v[3] / imageHeight;
                break;
            default:
                // NormalizedUnit (mock / already normalized): [x1, y1, x2, y2] in 0..1
                x1 = v[0]; y1 = v[1]; x2 = v[2]; y2 = v[3];
                break;
        }

        // Order corners, clamp to the image, round for a tidy wire format.
        double ax = Math.Clamp(Math.Min(x1, x2), 0, 1);
        double bx = Math.Clamp(Math.Max(x1, x2), 0, 1);
        double ay = Math.Clamp(Math.Min(y1, y2), 0, 1);
        double by = Math.Clamp(Math.Max(y1, y2), 0, 1);

        ax = Math.Round(ax, 4); bx = Math.Round(bx, 4); ay = Math.Round(ay, 4); by = Math.Round(by, 4);

        if (bx - ax <= 0 || by - ay <= 0)
        {
            return null; // zero width or height: nothing to draw / aim at
        }

        return new[] { ax, ay, bx, by };
    }
}
