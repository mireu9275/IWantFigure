using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace IWantFigure.Server.Shared;

/// <summary>Shared System.Text.Json settings so every endpoint serializes the same way.</summary>
public static class ServerJson
{
    /// <summary>For reading request bodies: forgiving about casing and trailing commas.</summary>
    public static JsonSerializerOptions Request { get; } = new()
    {
        PropertyNameCaseInsensitive = true,
        AllowTrailingCommas = true,
        ReadCommentHandling = JsonCommentHandling.Skip,
        NumberHandling = JsonNumberHandling.AllowReadingFromString,
    };

    /// <summary>
    /// For writing responses. UnsafeRelaxedJsonEscaping keeps Japanese/Korean text readable
    /// instead of \uXXXX escapes; it is safe here because the body is application/json, never HTML.
    /// </summary>
    public static JsonSerializerOptions Response { get; } = new()
    {
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        WriteIndented = false,
    };
}
