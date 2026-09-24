namespace IWantFigure.Server.Configuration;

// ---------------------------------------------------------------------------
// Strongly-typed configuration. Values come from appsettings.json and can be
// overridden with environment variables using the standard ASP.NET Core
// double-underscore syntax, e.g.  Analysis__Provider=claude  Claude__ApiKey=sk-...
// ---------------------------------------------------------------------------

/// <summary>HTTP-facing settings ("Server" section).</summary>
public sealed class ServerOptions
{
    public const string Section = "Server";

    /// <summary>
    /// Optional shared secret. When set, POST /api/v1/analyze requires the
    /// header <c>X-App-Key</c> with exactly this value; otherwise 401.
    /// </summary>
    public string? AppKey { get; set; }

    /// <summary>Fixed-window rate limit per client IP for the analyze endpoint.</summary>
    public int RateLimitPerMinute { get; set; } = 30;

    /// <summary>Kestrel request body limit. 12 MB covers a base64 JPEG of ~9 MB.</summary>
    public long MaxRequestBodyBytes { get; set; } = 12 * 1024 * 1024;

    /// <summary>
    /// Set to true when running behind a reverse proxy / load balancer so the
    /// rate limiter sees the real client IP from X-Forwarded-For.
    /// </summary>
    public bool UseForwardedHeaders { get; set; }
}

/// <summary>Pipeline settings ("Analysis" section).</summary>
public sealed class AnalysisOptions
{
    public const string Section = "Analysis";

    /// <summary>mock | gemini | claude</summary>
    public string Provider { get; set; } = "mock";

    /// <summary>Artificial latency of the mock provider, so the app's loading UI can be tested.</summary>
    public int MockDelayMs { get; set; } = 800;

    /// <summary>
    /// Images are downscaled so the long side is at most this many pixels before they are
    /// sent to the model. This is the main cost lever: fewer pixels = fewer image tokens.
    /// </summary>
    public int MaxImageLongSide { get; set; } = 1456;

    /// <summary>JPEG quality used when re-encoding the image for the model.</summary>
    public int JpegQuality { get; set; } = 85;

    /// <summary>Reject images with more pixels than this before decoding (decompression-bomb guard).</summary>
    public long MaxImagePixels { get; set; } = 50_000_000;

    /// <summary>HttpClient timeout for one call to the LLM provider.</summary>
    public int ProviderTimeoutSeconds { get; set; } = 30;
}

/// <summary>Google Gemini settings ("Gemini" section).</summary>
public sealed class GeminiOptions
{
    public const string Section = "Gemini";

    public string? ApiKey { get; set; }

    /// <summary>
    /// Model id used in the REST path. "gemini-2.5-flash" is the default; newer Flash models
    /// (e.g. a gemini-3 flash release) can be set here without code changes as long as they
    /// support responseSchema JSON output.
    /// </summary>
    public string Model { get; set; } = "gemini-2.5-flash";

    /// <summary>
    /// When set (e.g. 0) a thinkingConfig { thinkingBudget } block is sent. Leave null (default)
    /// to not send the block at all - older models reject it.
    /// </summary>
    public int? ThinkingBudget { get; set; }

    public double Temperature { get; set; } = 0.5;

    public int MaxOutputTokens { get; set; } = 8192;

    public string BaseUrl { get; set; } = "https://generativelanguage.googleapis.com";
}

/// <summary>Anthropic Claude settings ("Claude" section).</summary>
public sealed class ClaudeOptions
{
    public const string Section = "Claude";

    public string? ApiKey { get; set; }

    /// <summary>Model id. Exact ids only (no date suffix): claude-sonnet-5, claude-opus-5, claude-haiku-4-5 ...</summary>
    public string Model { get; set; } = "claude-sonnet-5";

    /// <summary>
    /// Hard cap on output tokens. NOTE: on Claude Sonnet 5 / Opus 5 this cap covers
    /// thinking + the JSON answer, so raise it if you raise <see cref="Effort"/>.
    /// </summary>
    public int MaxTokens { get; set; } = 2048;

    /// <summary>
    /// output_config.effort: low | medium | high | xhigh | max. Empty = do not send (API default "high").
    /// "low" keeps the thinking short enough to fit the default MaxTokens for a single-photo analysis.
    /// </summary>
    public string? Effort { get; set; } = "low";

    /// <summary>
    /// "adaptive" (default, the only "on" mode for Claude 4.6+ / 5 models), "disabled",
    /// or empty to omit the parameter entirely (needed for models that use budget_tokens, e.g. Haiku 4.5).
    /// </summary>
    public string? Thinking { get; set; } = "adaptive";

    /// <summary>Value of the required anthropic-version header.</summary>
    public string AnthropicVersion { get; set; } = "2023-06-01";

    public string BaseUrl { get; set; } = "https://api.anthropic.com";
}
