using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using IWantFigure.Server.Analysis;
using IWantFigure.Server.Configuration;
using IWantFigure.Server.Contracts;
using IWantFigure.Server.Imaging;
using IWantFigure.Server.Shared;
using Microsoft.Extensions.Options;

namespace IWantFigure.Server.Providers;

/// <summary>
/// Anthropic Claude via the Messages API (POST /v1/messages) over plain HttpClient.
///
/// Request shape (per the Claude API reference):
///  - headers  x-api-key, anthropic-version: 2023-06-01
///  - system   [{ type: "text", text: &lt;shared prompt + pixel-coordinate rule&gt;, cache_control: { type: "ephemeral" } }]
///             The system text is constant across requests, so the prefix is served from the prompt cache.
///  - messages [{ role: "user", content: [ { type: "image", source: { type: "base64", media_type, data } },
///                                          { type: "text", text: &lt;image size, locale, hints&gt; } ] }]
///  - output_config.format = { type: "json_schema", schema: analysis.schema.json } -> the first text block is guaranteed JSON.
///  - thinking { type: "adaptive" } and output_config.effort are configurable; no temperature (Claude 5 rejects non-default sampling params).
///
/// Boxes come back as absolute pixel coordinates of the sent image: [x1, y1, x2, y2].
/// </summary>
public sealed class ClaudeProvider : IAnalysisProvider
{
    /// <summary>Appended to the shared prompt. Static text only - per-request values would break the cache prefix.</summary>
    internal const string CoordinateInstruction =
        "\n\nCOORDINATE CONVENTION FOR THIS DEPLOYMENT\n" +
        "- Give every bbox as absolute pixel coordinates of the image you were given: [x1, y1, x2, y2] with the origin at the top-left corner, x to the right, y downward, x1 < x2 and y1 < y2.\n" +
        "- The user message states the image size in pixels; never exceed it.";

    private const string UserCoordinateInstruction =
        "Coordinates: absolute pixels of this image, bbox = [x1, y1, x2, y2], origin top-left.";

    private readonly HttpClient _http;
    private readonly ClaudeOptions _options;
    private readonly ILogger<ClaudeProvider> _logger;
    private readonly JsonObject _outputSchema;

    public ClaudeProvider(HttpClient http, IOptions<ClaudeOptions> options, AnalysisSchema schema, ILogger<ClaudeProvider> logger)
    {
        _http = http;
        _options = options.Value;
        _logger = logger;
        _outputSchema = ClaudeSchemaConverter.Convert(schema.Root);
    }

    public string Name => "claude";

    public string Model => _options.Model;

    public async Task<ProviderResult> AnalyzeAsync(PreparedImage image, AnalyzeRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(_options.ApiKey))
        {
            throw new ProviderNotConfiguredException(Name);
        }

        JsonObject body = BuildRequestBody(image, request);

        string url = $"{_options.BaseUrl.TrimEnd('/')}/v1/messages";
        using var httpRequest = new HttpRequestMessage(HttpMethod.Post, url)
        {
            Content = new StringContent(body.ToJsonString(), Encoding.UTF8, "application/json"),
        };
        httpRequest.Headers.TryAddWithoutValidation("x-api-key", _options.ApiKey);
        httpRequest.Headers.TryAddWithoutValidation("anthropic-version", _options.AnthropicVersion);

        string responseText = await ProviderHttp.SendAsync(_http, httpRequest, Name, ct).ConfigureAwait(false);
        return ParseResponse(responseText);
    }

    internal JsonObject BuildRequestBody(PreparedImage image, AnalyzeRequest request)
    {
        var outputConfig = new JsonObject
        {
            ["format"] = new JsonObject
            {
                ["type"] = "json_schema",
                ["schema"] = _outputSchema.DeepClone(),
            },
        };
        if (!string.IsNullOrWhiteSpace(_options.Effort))
        {
            outputConfig["effort"] = _options.Effort.Trim().ToLowerInvariant();
        }

        var body = new JsonObject
        {
            ["model"] = _options.Model,
            ["max_tokens"] = _options.MaxTokens,
            ["system"] = new JsonArray(new JsonObject
            {
                ["type"] = "text",
                ["text"] = SharedResources.SystemPrompt + CoordinateInstruction,
                ["cache_control"] = new JsonObject { ["type"] = "ephemeral" },
            }),
            ["messages"] = new JsonArray(new JsonObject
            {
                ["role"] = "user",
                ["content"] = new JsonArray(
                    new JsonObject
                    {
                        ["type"] = "image",
                        ["source"] = new JsonObject
                        {
                            ["type"] = "base64",
                            ["media_type"] = image.Mime,
                            ["data"] = image.ToBase64(),
                        },
                    },
                    new JsonObject
                    {
                        ["type"] = "text",
                        ["text"] = PromptBuilder.BuildUserText(request, image, UserCoordinateInstruction),
                    }),
            }),
            ["output_config"] = outputConfig,
        };

        string thinking = (_options.Thinking ?? "").Trim().ToLowerInvariant();
        if (thinking is "adaptive" or "disabled")
        {
            body["thinking"] = new JsonObject { ["type"] = thinking };
        }
        // else: omit the parameter (older models such as Haiku 4.5 use a different thinking shape).

        return body;
    }

    /// <summary>Checks stop_reason, then returns the first text block (guaranteed JSON by output_config.format).</summary>
    internal ProviderResult ParseResponse(string responseText)
    {
        using JsonDocument doc = ProviderHttp.ParseJson(responseText, Name);

        JsonElement root = doc.RootElement;
        string stopReason = root.TryGetProperty("stop_reason", out JsonElement sr) && sr.ValueKind == JsonValueKind.String
            ? sr.GetString() ?? ""
            : "";

        switch (stopReason)
        {
            case "refusal":
                // Safety classifiers declined; the body will not match the schema. Not retryable.
                string explanation = root.TryGetProperty("stop_details", out JsonElement sd) &&
                                     sd.TryGetProperty("explanation", out JsonElement ex) && ex.ValueKind == JsonValueKind.String
                    ? ex.GetString() ?? ""
                    : "";
                throw new ProviderException("claude: the model refused to analyze this image" + (explanation.Length > 0 ? ": " + explanation : ""), isTransient: false);

            case "max_tokens":
                throw new ProviderException($"claude: output truncated at max_tokens={_options.MaxTokens}; raise Claude:MaxTokens or lower Claude:Effort", isTransient: false);
        }

        string? text = null;
        if (root.TryGetProperty("content", out JsonElement content) && content.ValueKind == JsonValueKind.Array)
        {
            foreach (JsonElement block in content.EnumerateArray())
            {
                if (block.TryGetProperty("type", out JsonElement type) && type.GetString() == "text" &&
                    block.TryGetProperty("text", out JsonElement t) && t.ValueKind == JsonValueKind.String)
                {
                    text = t.GetString();
                    break;
                }
            }
        }

        if (string.IsNullOrWhiteSpace(text))
        {
            throw new ProviderException($"claude: response has no text block (stop_reason={stopReason})", isTransient: false);
        }

        ProviderUsage? usage = null;
        if (root.TryGetProperty("usage", out JsonElement u))
        {
            usage = new ProviderUsage(
                ProviderHttp.OptionalInt(u, "input_tokens"),
                ProviderHttp.OptionalInt(u, "output_tokens"),
                ProviderHttp.OptionalInt(u, "cache_read_input_tokens"),
                ProviderHttp.OptionalInt(u, "cache_creation_input_tokens"));
            // cache_read > 0 on the second request onwards proves the system prompt is being served from cache.
            _logger.LogDebug("claude usage input={Input} output={Output} cache_read={CacheRead} cache_write={CacheWrite}",
                usage.InputTokens, usage.OutputTokens, usage.CacheReadTokens, usage.CacheWriteTokens);
        }

        return new ProviderResult(text, CoordinateConvention.AbsolutePixels, usage);
    }
}
