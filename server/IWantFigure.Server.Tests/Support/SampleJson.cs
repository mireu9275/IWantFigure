using System.Text.Json.Nodes;
using IWantFigure.Server.Shared;

namespace IWantFigure.Server.Tests.Support;

/// <summary>Variants of shared/samples/bridge_parallel.json in the providers' native coordinate conventions.</summary>
public static class SampleJson
{
    /// <summary>The sample as-is (0..1 [x1,y1,x2,y2]).</summary>
    public static string Normalized => SharedResources.SampleBridgeParallelJson;

    /// <summary>The sample rewritten as Gemini box_2d: [ymin, xmin, ymax, xmax] on 0..1000.</summary>
    public static string GeminiThousandths()
    {
        JsonObject root = JsonNode.Parse(Normalized)!.AsObject();
        foreach (JsonNode? obj in root["objects"]!.AsArray())
        {
            JsonArray b = obj!["bbox"]!.AsArray();
            double x1 = b[0]!.GetValue<double>(), y1 = b[1]!.GetValue<double>(), x2 = b[2]!.GetValue<double>(), y2 = b[3]!.GetValue<double>();
            obj["bbox"] = new JsonArray(Math.Round(y1 * 1000), Math.Round(x1 * 1000), Math.Round(y2 * 1000), Math.Round(x2 * 1000));
        }
        return root.ToJsonString();
    }

    /// <summary>The sample rewritten as absolute pixels of a width x height image: [x1, y1, x2, y2].</summary>
    public static string ClaudePixels(int width, int height)
    {
        JsonObject root = JsonNode.Parse(Normalized)!.AsObject();
        foreach (JsonNode? obj in root["objects"]!.AsArray())
        {
            JsonArray b = obj!["bbox"]!.AsArray();
            double x1 = b[0]!.GetValue<double>(), y1 = b[1]!.GetValue<double>(), x2 = b[2]!.GetValue<double>(), y2 = b[3]!.GetValue<double>();
            obj["bbox"] = new JsonArray(Math.Round(x1 * width), Math.Round(y1 * height), Math.Round(x2 * width), Math.Round(y2 * height));
        }
        return root.ToJsonString();
    }
}
