using System.Net;
using System.Text.Json;
using IWantFigure.Server.Analysis;
using IWantFigure.Server.Configuration;
using IWantFigure.Server.Contracts;
using IWantFigure.Server.Imaging;
using IWantFigure.Server.Models;
using IWantFigure.Server.Providers;
using IWantFigure.Server.Tests.Support;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

namespace IWantFigure.Server.Tests;

public class GeminiProviderTests
{
    private static readonly PreparedImage Image = new(new byte[] { 0xFF, 0xD8, 0xFF, 0x01 }, "image/jpeg", 1456, 971);

    private static GeminiProvider Make(FakeHttpMessageHandler handler, GeminiOptions? options = null) =>
        new(new HttpClient(handler), Options.Create(options ?? new GeminiOptions { ApiKey = "test-key" }), AnalysisSchema.Embedded, NullLogger<GeminiProvider>.Instance);

    private static string Canned(string text, string finishReason = "STOP") => JsonSerializer.Serialize(new
    {
        candidates = new[]
        {
            new { content = new { parts = new object[] { new { text } }, role = "model" }, finishReason },
        },
        usageMetadata = new { promptTokenCount = 1000, candidatesTokenCount = 300, thoughtsTokenCount = 0 },
    });

    private static AnalyzeRequest Req(string locale = "ko") => new()
    {
        Locale = locale,
        Hints = new AnalyzeHints { ClawCount = 2, MachineFamily = "Sega UFO Catcher 9", PrizeSizeMm = new[] { 120.0, 90, 160 }, Notes = "moved 1 cm last time" },
    };

    [Fact]
    public async Task Sends_system_instruction_image_schema_and_parses_text()
    {
        var handler = new FakeHttpMessageHandler().RespondJson(Canned(SampleJson.GeminiThousandths()));
        GeminiProvider provider = Make(handler);

        ProviderResult result = await provider.AnalyzeAsync(Image, Req(), CancellationToken.None);

        // --- request line & auth
        HttpRequestMessage request = Assert.Single(handler.Requests);
        Assert.Equal(HttpMethod.Post, request.Method);
        Assert.Equal("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent", request.RequestUri!.ToString());
        Assert.DoesNotContain("key=", request.RequestUri.ToString()); // key must not be in the URL
        Assert.Equal("test-key", request.Headers.GetValues("x-goog-api-key").Single());

        // --- body
        using JsonDocument body = JsonDocument.Parse(handler.Bodies.Single());
        JsonElement root = body.RootElement;

        string systemText = root.GetProperty("systemInstruction").GetProperty("parts")[0].GetProperty("text").GetString()!;
        Assert.Contains("CraneCoach", systemText);
        Assert.Contains("bridge_parallel", systemText);

        JsonElement parts = root.GetProperty("contents")[0].GetProperty("parts");
        Assert.Equal("image/jpeg", parts[0].GetProperty("inline_data").GetProperty("mime_type").GetString());
        Assert.Equal(Convert.ToBase64String(Image.Bytes), parts[0].GetProperty("inline_data").GetProperty("data").GetString());

        string userText = parts[1].GetProperty("text").GetString()!;
        Assert.Contains("[ymin, xmin, ymax, xmax]", userText);
        Assert.Contains("0-1000", userText);
        Assert.Contains("Korean", userText);
        Assert.Contains("1456x971", userText);
        Assert.Contains("claw_count: 2", userText);
        Assert.Contains("[120, 90, 160]", userText);
        Assert.Contains("Sega UFO Catcher 9", userText);

        JsonElement gen = root.GetProperty("generationConfig");
        Assert.Equal("application/json", gen.GetProperty("responseMimeType").GetString());
        Assert.Equal(0.5, gen.GetProperty("temperature").GetDouble());
        Assert.False(gen.TryGetProperty("thinkingConfig", out _)); // off by default

        JsonElement schema = gen.GetProperty("responseSchema");
        Assert.Equal("OBJECT", schema.GetProperty("type").GetString());
        Assert.True(schema.GetProperty("properties").TryGetProperty("layout_type", out _));
        string schemaJson = schema.GetRawText();
        Assert.DoesNotContain("$schema", schemaJson);
        Assert.DoesNotContain("additionalProperties", schemaJson);

        // --- result
        Assert.Equal(CoordinateConvention.NormalizedThousandths, result.Convention);
        Assert.Equal(SampleJson.GeminiThousandths(), result.RawJson);
        Assert.Equal(1000, result.Usage?.InputTokens);
        Assert.Equal(300, result.Usage?.OutputTokens);
    }

    [Fact]
    public async Task Parsed_result_normalizes_end_to_end()
    {
        var handler = new FakeHttpMessageHandler().RespondJson(Canned(SampleJson.GeminiThousandths()));
        ProviderResult result = await Make(handler).AnalyzeAsync(Image, Req(), CancellationToken.None);

        AnalysisDocument doc = new AnalysisNormalizer(AnalysisSchema.Embedded).Normalize(result, Image.Width, Image.Height);

        Assert.Equal(new[] { 0.36, 0.42, 0.64, 0.74 }, doc.Objects.Single(o => o.Id == "box1").Bbox);
    }

    [Fact]
    public async Task Thinking_budget_and_model_are_configurable()
    {
        var handler = new FakeHttpMessageHandler().RespondJson(Canned(SampleJson.GeminiThousandths()));
        GeminiProvider provider = Make(handler, new GeminiOptions { ApiKey = "k", Model = "gemini-3-flash", ThinkingBudget = 0 });

        await provider.AnalyzeAsync(Image, Req(), CancellationToken.None);

        Assert.Contains("/models/gemini-3-flash:generateContent", handler.Requests.Single().RequestUri!.ToString());
        Assert.Equal("gemini-3-flash", provider.Model);
        using JsonDocument body = JsonDocument.Parse(handler.Bodies.Single());
        Assert.Equal(0, body.RootElement.GetProperty("generationConfig").GetProperty("thinkingConfig").GetProperty("thinkingBudget").GetInt32());
    }

    [Fact]
    public async Task Missing_api_key_throws_not_configured_without_calling_the_network()
    {
        var handler = new FakeHttpMessageHandler();
        GeminiProvider provider = Make(handler, new GeminiOptions { ApiKey = "" });

        await Assert.ThrowsAsync<ProviderNotConfiguredException>(() => provider.AnalyzeAsync(Image, Req(), CancellationToken.None));
        Assert.Empty(handler.Requests);
    }

    [Fact]
    public async Task Http_500_is_a_transient_provider_error_with_the_upstream_message()
    {
        var handler = new FakeHttpMessageHandler().Respond(HttpStatusCode.InternalServerError, """{"error":{"code":500,"message":"backend boom","status":"INTERNAL"}}""");

        var ex = await Assert.ThrowsAsync<ProviderException>(() => Make(handler).AnalyzeAsync(Image, Req(), CancellationToken.None));

        Assert.True(ex.IsTransient);
        Assert.Contains("backend boom", ex.Message);
        Assert.Contains("500", ex.Message);
    }

    [Fact]
    public async Task Http_400_is_not_transient()
    {
        var handler = new FakeHttpMessageHandler().Respond(HttpStatusCode.BadRequest, """{"error":{"message":"API key not valid"}}""");

        var ex = await Assert.ThrowsAsync<ProviderException>(() => Make(handler).AnalyzeAsync(Image, Req(), CancellationToken.None));

        Assert.False(ex.IsTransient);
    }

    [Fact]
    public async Task Blocked_prompt_is_not_transient()
    {
        var handler = new FakeHttpMessageHandler().RespondJson("""{"promptFeedback":{"blockReason":"SAFETY"}}""");

        var ex = await Assert.ThrowsAsync<ProviderException>(() => Make(handler).AnalyzeAsync(Image, Req(), CancellationToken.None));

        Assert.False(ex.IsTransient);
        Assert.Contains("SAFETY", ex.Message);
    }

    [Fact]
    public async Task Truncated_output_reports_max_tokens()
    {
        var handler = new FakeHttpMessageHandler().RespondJson(Canned("{\"layout_type\": \"bri", finishReason: "MAX_TOKENS"));

        var ex = await Assert.ThrowsAsync<ProviderException>(() => Make(handler).AnalyzeAsync(Image, Req(), CancellationToken.None));

        Assert.Contains("MAX_TOKENS", ex.Message);
    }
}
