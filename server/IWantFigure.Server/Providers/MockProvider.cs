using System.Text.Json.Nodes;
using IWantFigure.Server.Configuration;
using IWantFigure.Server.Contracts;
using IWantFigure.Server.Imaging;
using IWantFigure.Server.Shared;
using Microsoft.Extensions.Options;

namespace IWantFigure.Server.Providers;

/// <summary>
/// No network, no key: returns shared/samples/bridge_parallel.json after Analysis:MockDelayMs.
/// If hints.notes contains "unknown" it returns a layout_type "unknown" variant with a
/// needs_more_photos entry, so the app's "take another photo" flow can be exercised.
/// </summary>
public sealed class MockProvider : IAnalysisProvider
{
    private static readonly Lazy<string> UnknownVariantJson = new(BuildUnknownVariant);

    private readonly AnalysisOptions _options;

    public MockProvider(IOptions<AnalysisOptions> options)
    {
        _options = options.Value;
    }

    public string Name => "mock";

    public string Model => "sample/bridge_parallel";

    public async Task<ProviderResult> AnalyzeAsync(PreparedImage image, AnalyzeRequest request, CancellationToken ct)
    {
        if (_options.MockDelayMs > 0)
        {
            await Task.Delay(_options.MockDelayMs, ct).ConfigureAwait(false);
        }

        bool wantUnknown = request.Hints?.Notes?.Contains("unknown", StringComparison.OrdinalIgnoreCase) == true;
        string json = wantUnknown ? UnknownVariantJson.Value : SharedResources.SampleBridgeParallelJson;

        // The sample is already normalized 0..1, so no coordinate conversion is needed.
        return new ProviderResult(json, CoordinateConvention.NormalizedUnit);
    }

    /// <summary>Derives the "cannot tell, need another photo" variant from the sample so it stays schema-valid.</summary>
    private static string BuildUnknownVariant()
    {
        JsonObject root = JsonNode.Parse(SharedResources.SampleBridgeParallelJson)!.AsObject();
        root["layout_type"] = "unknown";
        root["confidence"] = 0.35;
        root["strategy"]!["technique"] = "unknown";
        root["strategy"]!["sequence"] = new JsonArray();
        root["strategy"]!["abort_if"] = new JsonArray();
        root["strategy"]!["expected_motion"] = "";
        root["explanation"] = "The claw and the contact points of the box are not clearly visible, so the setup cannot be classified yet. Please take another photo.";
        root["needs_more_photos"] = new JsonArray("side view level with the bars", "closer front view including the claw");
        root["warnings"] = new JsonArray("Mock provider: 'unknown' variant requested through hints.notes.");
        return root.ToJsonString();
    }
}
