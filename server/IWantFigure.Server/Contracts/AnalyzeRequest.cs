using System.Text.Json.Serialization;

namespace IWantFigure.Server.Contracts;

/// <summary>
/// Body of POST /api/v1/analyze. Field names are snake_case on the wire to match the app.
/// </summary>
public sealed class AnalyzeRequest
{
    /// <summary>Base64 of a JPEG / PNG / WebP file. A "data:image/...;base64," prefix is tolerated.</summary>
    [JsonPropertyName("image_base64")]
    public string? ImageBase64 { get; set; }

    /// <summary>image/jpeg | image/png | image/webp. When omitted the bytes are sniffed.</summary>
    [JsonPropertyName("mime")]
    public string? Mime { get; set; }

    /// <summary>"ko" | "ja" | "en" - language of the free-text fields in the answer.</summary>
    [JsonPropertyName("locale")]
    public string? Locale { get; set; }

    [JsonPropertyName("hints")]
    public AnalyzeHints? Hints { get; set; }
}

/// <summary>Optional player-supplied hints. All fields are optional.</summary>
public sealed class AnalyzeHints
{
    [JsonPropertyName("machine_family")]
    public string? MachineFamily { get; set; }

    [JsonPropertyName("claw_count")]
    public int? ClawCount { get; set; }

    /// <summary>[width, depth, height] of the prize box in millimetres.</summary>
    [JsonPropertyName("prize_size_mm")]
    public double[]? PrizeSizeMm { get; set; }

    /// <summary>Free text about previous plays. The mock provider returns the "unknown" variant when it contains "unknown".</summary>
    [JsonPropertyName("notes")]
    public string? Notes { get; set; }
}

/// <summary>Error envelope: {"error": "...", "provider_message": "..."}.</summary>
public sealed class ErrorResponse
{
    public ErrorResponse(string error, string? message = null, string? providerMessage = null)
    {
        Error = error;
        Message = message;
        ProviderMessage = providerMessage;
    }

    /// <summary>Machine-readable code, e.g. "invalid_image", "unauthorized", "provider_error".</summary>
    [JsonPropertyName("error")]
    public string Error { get; }

    /// <summary>Optional human-readable detail for 4xx errors.</summary>
    [JsonPropertyName("message")]
    public string? Message { get; }

    /// <summary>Set for 502 provider_error: what the upstream LLM API said (never contains keys or the image).</summary>
    [JsonPropertyName("provider_message")]
    public string? ProviderMessage { get; }
}

/// <summary>GET /healthz body.</summary>
public sealed class HealthResponse
{
    public HealthResponse(string status, string provider)
    {
        Status = status;
        Provider = provider;
    }

    [JsonPropertyName("status")]
    public string Status { get; }

    [JsonPropertyName("provider")]
    public string Provider { get; }
}
