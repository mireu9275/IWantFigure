using IWantFigure.Server.Contracts;
using IWantFigure.Server.Imaging;

namespace IWantFigure.Server.Providers;

/// <summary>
/// Which coordinate system the provider's bbox values are in. The normalizer converts
/// all of them to 0..1 [x1, y1, x2, y2] of the sent image.
/// </summary>
public enum CoordinateConvention
{
    /// <summary>[x1, y1, x2, y2] already in 0..1 (mock sample).</summary>
    NormalizedUnit,

    /// <summary>Gemini's box_2d: [ymin, xmin, ymax, xmax] on a 0..1000 scale.</summary>
    NormalizedThousandths,

    /// <summary>Claude: [x1, y1, x2, y2] in absolute pixels of the image that was sent.</summary>
    AbsolutePixels,
}

/// <summary>Token accounting reported by the provider (null when not reported). Logged for cost tracking.</summary>
public sealed record ProviderUsage(int? InputTokens, int? OutputTokens, int? CacheReadTokens, int? CacheWriteTokens);

/// <summary>What a provider hands back: the raw JSON text and how to read its coordinates.</summary>
public sealed record ProviderResult(string RawJson, CoordinateConvention Convention, ProviderUsage? Usage = null);

/// <summary>One multimodal LLM backend. Exactly one implementation is registered, chosen by Analysis:Provider.</summary>
public interface IAnalysisProvider
{
    /// <summary>"mock" | "gemini" | "claude" - echoed in /healthz and in every response.</summary>
    string Name { get; }

    /// <summary>Model id in use, echoed in every response.</summary>
    string Model { get; }

    /// <summary>
    /// Sends the prepared image + request to the model and returns its raw JSON text.
    /// Throws <see cref="ProviderNotConfiguredException"/> when the API key is missing and
    /// <see cref="ProviderException"/> when the upstream call fails.
    /// </summary>
    Task<ProviderResult> AnalyzeAsync(PreparedImage image, AnalyzeRequest request, CancellationToken ct);
}

/// <summary>The upstream API call failed (HTTP error, network, refusal, truncated output). Mapped to HTTP 502.</summary>
public class ProviderException : Exception
{
    public ProviderException(string message, bool isTransient, Exception? inner = null) : base(message, inner)
    {
        IsTransient = isTransient;
    }

    /// <summary>True for 429 / 5xx / connection errors - worth one retry. False for 4xx, refusals, truncation.</summary>
    public bool IsTransient { get; }
}

/// <summary>The selected provider has no API key. Mapped to HTTP 503 provider_not_configured.</summary>
public sealed class ProviderNotConfiguredException : Exception
{
    public ProviderNotConfiguredException(string provider)
        : base($"provider '{provider}' is selected but its API key is not configured")
    {
        Provider = provider;
    }

    public string Provider { get; }
}
