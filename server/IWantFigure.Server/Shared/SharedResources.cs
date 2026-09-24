using System.Reflection;

namespace IWantFigure.Server.Shared;

/// <summary>
/// Reads the files from /shared that are linked into this assembly as embedded resources
/// (see the .csproj). Loaded once, on first use.
/// </summary>
public static class SharedResources
{
    /// <summary>shared/analysis.schema.json - the response contract (JSON Schema 2020-12).</summary>
    public static string SchemaJson { get; } = Read("IWantFigure.Shared.analysis.schema.json");

    /// <summary>shared/prompt/system_prompt.md - the fixed CraneCoach system prompt.</summary>
    public static string SystemPrompt { get; } = Read("IWantFigure.Shared.system_prompt.md");

    /// <summary>shared/samples/bridge_parallel.json - the mock provider's canned answer.</summary>
    public static string SampleBridgeParallelJson { get; } = Read("IWantFigure.Shared.bridge_parallel.json");

    private static string Read(string logicalName)
    {
        Assembly asm = typeof(SharedResources).Assembly;
        using Stream stream = asm.GetManifestResourceStream(logicalName)
            ?? throw new InvalidOperationException(
                $"Embedded resource '{logicalName}' not found. Available: {string.Join(", ", asm.GetManifestResourceNames())}");
        using var reader = new StreamReader(stream);
        return reader.ReadToEnd();
    }
}
