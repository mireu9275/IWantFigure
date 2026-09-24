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
/// Google Gemini via the REST generateContent endpoint with JSON-mode output
/// (responseMimeType + responseSchema). Bounding boxes come back in Gemini's native
/// box_2d convention: [ymin, xmin, ymax, xmax] on a 0..1000 scale.
/// </summary>
public sealed class GeminiProvider : IAnalysisProvider
{
    private const string CoordinateInstruction =
        "Coordinates: give every object's bbox in the box_2d convention as [ymin, xmin, ymax, xmax] on a 0-1000 scale of this image.";

    private readonly HttpClient _http;
    private readonly GeminiOptions _options;
    private readonly ILogger<GeminiProvider> _logger;
    private readonly JsonObject _responseSchema;

    public GeminiProvider(HttpClient http, IOptions<GeminiOptions> options, AnalysisSchema schema, ILogger<GeminiProvider> logger)
    {
        _http = http;
        _options = options.Value;
        _logger = logger;
        _responseSchema = GeminiSchemaConverter.Convert(schema.Root);
    }

    public string Name => "gemini";

    public string Model => _options.Model;

    public async Task<ProviderResult> AnalyzeAsync(PreparedImage image, AnalyzeRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(_options.ApiKey))
        {
            throw new ProviderNotConfiguredException(Name);
        }

        var generationConfig = new JsonObject
        {
            ["responseMimeType"] = "application/json",
            ["responseSchema"] = _responseSchema.DeepClone(), // a JsonNode can only have one parent
            ["temperature"] = _options.Temperature,
            ["maxOutputTokens"] = _options.MaxOutputTokens,
        };
        if (_options.ThinkingBudget is int budget)
        {
            // Only sent when configured: models before 2.5 reject the field.
            generationConfig["thinkingConfig"] = new JsonObject { ["thinkingBudget"] = budget };
        }

        var body = new JsonObject
        {
            ["systemInstruction"] = new JsonObject
            {
                ["parts"] = new JsonArray(new JsonObject { ["text"] = SharedResources.SystemPrompt }),
            },
            ["contents"] = new JsonArray(new JsonObject
            {
                ["role"] = "user",
                ["parts"] = new JsonArray(
                    new JsonObject
                    {
                        ["inline_data"] = new JsonObject
                        {
                            ["mime_type"] = image.Mime,
                            ["data"] = image.ToBase64(),
                        },
                    },
                    new JsonObject { ["text"] = PromptBuilder.BuildUserText(request, image, CoordinateInstruction) }),
            }),
            ["generationConfig"] = generationConfig,
        };

        // The key goes in a header, not in "?key=" - URLs end up in logs and proxies, headers do not.
        string url = $"{_options.BaseUrl.TrimEnd('/')}/v1beta/models/{Uri.EscapeDataString(_options.Model)}:generateContent";
        using var httpRequest = new HttpRequestMessage(HttpMethod.Post, url)
        {
            Content = new StringContent(body.ToJsonString(), Encoding.UTF8, "application/json"),
        };
        httpRequest.Headers.TryAddWithoutValidation("x-goog-api-key", _options.ApiKey);

        string responseText = await ProviderHttp.SendAsync(_http, httpRequest, Name, ct).ConfigureAwait(false);
        return ParseResponse(responseText);
    }

    /// <summary>Extracts candidates[0].content.parts[0].text and the usage block.</summary>
    internal ProviderResult ParseResponse(string responseText)
    {
        using JsonDocument doc = ProviderHttp.ParseJson(responseText, Name);

        JsonElement root = doc.RootElement;

        // Safety block on the prompt itself: no candidates at all.
        if (root.TryGetProperty("promptFeedback", out JsonElement feedback) &&
            feedback.TryGetProperty("blockReason", out JsonElement blockReason))
        {
            throw new ProviderException($"gemini: prompt blocked ({blockReason.GetString()})", isTransient: false);
        }

        if (!root.TryGetProperty("candidates", out JsonElement candidates) ||
            candidates.ValueKind != JsonValueKind.Array || candidates.GetArrayLength() == 0)
        {
            throw new ProviderException("gemini: response has no candidates", isTransient: true);
        }

        JsonElement first = candidates[0];
        string finishReason = first.TryGetProperty("finishReason", out JsonElement fr) ? fr.GetString() ?? "" : "";

        string? text = null;
        if (first.TryGetProperty("content", out JsonElement content) &&
            content.TryGetProperty("parts", out JsonElement parts) && parts.ValueKind == JsonValueKind.Array)
        {
            foreach (JsonElement part in parts.EnumerateArray())
            {
                // Skip "thought" parts if a thinking model returns them.
                if (part.TryGetProperty("thought", out JsonElement thought) && thought.ValueKind == JsonValueKind.True)
                {
                    continue;
                }
                if (part.TryGetProperty("text", out JsonElement t) && t.ValueKind == JsonValueKind.String)
                {
                    text = t.GetString();
                    break;
                }
            }
        }

        if (string.IsNullOrWhiteSpace(text))
        {
            throw new ProviderException($"gemini: candidate has no text (finishReason={finishReason})", isTransient: finishReason is "" or "OTHER");
        }
        if (finishReason == "MAX_TOKENS")
        {
            throw new ProviderException("gemini: output truncated (MAX_TOKENS); raise Gemini:MaxOutputTokens", isTransient: false);
        }

        ProviderUsage? usage = null;
        if (root.TryGetProperty("usageMetadata", out JsonElement um))
        {
            usage = new ProviderUsage(
                ProviderHttp.OptionalInt(um, "promptTokenCount"),
                ProviderHttp.OptionalInt(um, "candidatesTokenCount"),
                ProviderHttp.OptionalInt(um, "cachedContentTokenCount"),
                null);
            _logger.LogDebug("gemini usage prompt={Prompt} candidates={Candidates} thoughts={Thoughts}",
                usage.InputTokens, usage.OutputTokens, ProviderHttp.OptionalInt(um, "thoughtsTokenCount"));
        }

        return new ProviderResult(text, CoordinateConvention.NormalizedThousandths, usage);
    }
}
