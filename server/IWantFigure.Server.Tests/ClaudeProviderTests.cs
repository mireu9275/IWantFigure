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

public class ClaudeProviderTests
{
    private static readonly PreparedImage Image = new(new byte[] { 0xFF, 0xD8, 0xFF, 0x02 }, "image/jpeg", 1456, 971);

    private static ClaudeProvider Make(FakeHttpMessageHandler handler, ClaudeOptions? options = null) =>
        new(new HttpClient(handler), Options.Create(options ?? new ClaudeOptions { ApiKey = "sk-ant-test" }), AnalysisSchema.Embedded, NullLogger<ClaudeProvider>.Instance);

    /// <summary>A Messages API response as documented: content[] with a text block, stop_reason, usage.</summary>
    private static string Canned(string text, string stopReason = "end_turn", string? refusalExplanation = null) => JsonSerializer.Serialize(new
    {
        id = "msg_01",
        type = "message",
        role = "assistant",
        model = "claude-sonnet-5",
        content = new object[] { new { type = "text", text } },
        stop_reason = stopReason,
        stop_details = refusalExplanation is null ? null : new { type = "refusal", category = "other", explanation = refusalExplanation },
        usage = new { input_tokens = 1500, output_tokens = 600, cache_read_input_tokens = 1300, cache_creation_input_tokens = 0 },
    });

    private static AnalyzeRequest Req(string locale = "ja") => new()
    {
        Locale = locale,
        Hints = new AnalyzeHints { ClawCount = 2, Notes = "box tilted a little" },
    };

    [Fact]
    public async Task Sends_documented_messages_api_shape_and_parses_text()
    {
        var handler = new FakeHttpMessageHandler().RespondJson(Canned(SampleJson.ClaudePixels(1456, 971)));
        ClaudeProvider provider = Make(handler);

        ProviderResult result = await provider.AnalyzeAsync(Image, Req(), CancellationToken.None);

        // --- request line & headers
        HttpRequestMessage request = Assert.Single(handler.Requests);
        Assert.Equal(HttpMethod.Post, request.Method);
        Assert.Equal("https://api.anthropic.com/v1/messages", request.RequestUri!.ToString());
        Assert.Equal("sk-ant-test", request.Headers.GetValues("x-api-key").Single());
        Assert.Equal("2023-06-01", request.Headers.GetValues("anthropic-version").Single());
        Assert.Equal("application/json", request.Content!.Headers.ContentType!.MediaType);

        // --- body
        using JsonDocument body = JsonDocument.Parse(handler.Bodies.Single());
        JsonElement root = body.RootElement;

        Assert.Equal("claude-sonnet-5", root.GetProperty("model").GetString());
        Assert.Equal(8192, root.GetProperty("max_tokens").GetInt32());
        Assert.False(root.TryGetProperty("temperature", out _)); // Claude 5 rejects non-default sampling params

        // system prompt: shared prompt + pixel rule, marked cacheable
        JsonElement system = root.GetProperty("system")[0];
        Assert.Equal("text", system.GetProperty("type").GetString());
        Assert.Contains("CraneCoach", system.GetProperty("text").GetString());
        Assert.Contains("absolute pixel coordinates", system.GetProperty("text").GetString());
        Assert.Equal("ephemeral", system.GetProperty("cache_control").GetProperty("type").GetString());

        // user content: image block first, then the per-request text
        JsonElement content = root.GetProperty("messages")[0].GetProperty("content");
        Assert.Equal("user", root.GetProperty("messages")[0].GetProperty("role").GetString());
        Assert.Equal("image", content[0].GetProperty("type").GetString());
        Assert.Equal("base64", content[0].GetProperty("source").GetProperty("type").GetString());
        Assert.Equal("image/jpeg", content[0].GetProperty("source").GetProperty("media_type").GetString());
        Assert.Equal(Convert.ToBase64String(Image.Bytes), content[0].GetProperty("source").GetProperty("data").GetString());
        Assert.Equal("text", content[1].GetProperty("type").GetString());
        string userText = content[1].GetProperty("text").GetString()!;
        Assert.Contains("1456x971", userText);
        Assert.Contains("[x1, y1, x2, y2]", userText);
        Assert.Contains("Japanese", userText);
        Assert.Contains("box tilted a little", userText);

        // structured output: output_config.format = json_schema with the shared schema
        JsonElement format = root.GetProperty("output_config").GetProperty("format");
        Assert.Equal("json_schema", format.GetProperty("type").GetString());
        JsonElement schema = format.GetProperty("schema");
        Assert.False(schema.TryGetProperty("$schema", out _));
        Assert.False(schema.GetProperty("additionalProperties").GetBoolean());
        Assert.Contains("layout_type", schema.GetProperty("required").EnumerateArray().Select(e => e.GetString()));
        Assert.Equal("low", root.GetProperty("output_config").GetProperty("effort").GetString());
        Assert.Equal("adaptive", root.GetProperty("thinking").GetProperty("type").GetString());

        // --- result
        Assert.Equal(CoordinateConvention.AbsolutePixels, result.Convention);
        Assert.Equal(SampleJson.ClaudePixels(1456, 971), result.RawJson);
        Assert.Equal(1500, result.Usage?.InputTokens);
        Assert.Equal(1300, result.Usage?.CacheReadTokens);
    }

    [Fact]
    public async Task Parsed_result_normalizes_end_to_end()
    {
        var handler = new FakeHttpMessageHandler().RespondJson(Canned(SampleJson.ClaudePixels(1456, 971)));
        ProviderResult result = await Make(handler).AnalyzeAsync(Image, Req(), CancellationToken.None);

        AnalysisDocument doc = new AnalysisNormalizer(AnalysisSchema.Embedded).Normalize(result, 1456, 971);

        double[] box = doc.Objects.Single(o => o.Id == "box1").Bbox;
        Assert.InRange(box[0], 0.359, 0.361);
        Assert.InRange(box[1], 0.419, 0.421);
        Assert.InRange(box[2], 0.639, 0.641);
        Assert.InRange(box[3], 0.739, 0.741);
        Assert.Equal("box1", doc.Strategy.TargetObjectId);
    }

    [Fact]
    public async Task Model_max_tokens_effort_and_thinking_are_configurable()
    {
        var handler = new FakeHttpMessageHandler().RespondJson(Canned(SampleJson.ClaudePixels(1456, 971)));
        ClaudeProvider provider = Make(handler, new ClaudeOptions { ApiKey = "k", Model = "claude-opus-5", MaxTokens = 4096, Effort = "", Thinking = "" });

        await provider.AnalyzeAsync(Image, Req(), CancellationToken.None);

        Assert.Equal("claude-opus-5", provider.Model);
        using JsonDocument body = JsonDocument.Parse(handler.Bodies.Single());
        Assert.Equal("claude-opus-5", body.RootElement.GetProperty("model").GetString());
        Assert.Equal(4096, body.RootElement.GetProperty("max_tokens").GetInt32());
        Assert.False(body.RootElement.GetProperty("output_config").TryGetProperty("effort", out _));
        Assert.False(body.RootElement.TryGetProperty("thinking", out _));
    }

    [Fact]
    public async Task Haiku_models_get_neither_effort_nor_thinking()
    {
        var handler = new FakeHttpMessageHandler().RespondJson(Canned(SampleJson.ClaudePixels(1456, 971)));
        ClaudeProvider provider = Make(handler, new ClaudeOptions { ApiKey = "k", Model = "claude-haiku-4-5", Effort = "high", Thinking = "adaptive" });

        await provider.AnalyzeAsync(Image, Req(), CancellationToken.None);

        Assert.True(provider.IsLegacyThinkingModel);
        using JsonDocument body = JsonDocument.Parse(handler.Bodies.Single());
        Assert.Equal("claude-haiku-4-5", body.RootElement.GetProperty("model").GetString());
        Assert.False(body.RootElement.TryGetProperty("thinking", out _));
        Assert.False(body.RootElement.GetProperty("output_config").TryGetProperty("effort", out _));
        Assert.Equal("json_schema", body.RootElement.GetProperty("output_config").GetProperty("format").GetProperty("type").GetString());
    }

    [Fact]
    public async Task Api_key_and_model_are_trimmed()
    {
        // Secrets mounted from files usually end with a newline.
        var handler = new FakeHttpMessageHandler().RespondJson(Canned(SampleJson.ClaudePixels(1456, 971)));
        ClaudeProvider provider = Make(handler, new ClaudeOptions { ApiKey = "  sk-ant-file-secret\n", Model = " claude-sonnet-5\n" });

        await provider.AnalyzeAsync(Image, Req(), CancellationToken.None);

        Assert.Equal("claude-sonnet-5", provider.Model);
        Assert.Equal("sk-ant-file-secret", handler.Requests.Single().Headers.GetValues("x-api-key").Single());
        using JsonDocument body = JsonDocument.Parse(handler.Bodies.Single());
        Assert.Equal("claude-sonnet-5", body.RootElement.GetProperty("model").GetString());
    }

    [Fact]
    public async Task Api_key_with_embedded_newline_fails_clearly_without_sending()
    {
        var handler = new FakeHttpMessageHandler();
        ClaudeProvider provider = Make(handler, new ClaudeOptions { ApiKey = "sk-ant\r\nX-Injected: 1" });

        var ex = await Assert.ThrowsAsync<ProviderNotConfiguredException>(() => provider.AnalyzeAsync(Image, Req(), CancellationToken.None));

        Assert.Empty(handler.Requests);
        Assert.Contains("not valid in an HTTP header", ex.Message);
        Assert.DoesNotContain("sk-ant", ex.Message); // the key must not leak into logs
        Assert.Null(ex.InnerException);
    }

    [Fact]
    public async Task Thinking_disabled_is_sent_when_configured()
    {
        var handler = new FakeHttpMessageHandler().RespondJson(Canned(SampleJson.ClaudePixels(1456, 971)));
        await Make(handler, new ClaudeOptions { ApiKey = "k", Thinking = "disabled" }).AnalyzeAsync(Image, Req(), CancellationToken.None);

        using JsonDocument body = JsonDocument.Parse(handler.Bodies.Single());
        Assert.Equal("disabled", body.RootElement.GetProperty("thinking").GetProperty("type").GetString());
    }

    [Fact]
    public async Task Missing_api_key_throws_not_configured()
    {
        var handler = new FakeHttpMessageHandler();
        await Assert.ThrowsAsync<ProviderNotConfiguredException>(() => Make(handler, new ClaudeOptions { ApiKey = null }).AnalyzeAsync(Image, Req(), CancellationToken.None));
        Assert.Empty(handler.Requests);
    }

    [Fact]
    public async Task Refusal_stop_reason_is_a_non_transient_error()
    {
        var handler = new FakeHttpMessageHandler().RespondJson(Canned("", stopReason: "refusal", refusalExplanation: "policy"));

        var ex = await Assert.ThrowsAsync<ProviderException>(() => Make(handler).AnalyzeAsync(Image, Req(), CancellationToken.None));

        Assert.False(ex.IsTransient);
        Assert.Contains("refused", ex.Message);
        Assert.Contains("policy", ex.Message);
    }

    [Fact]
    public async Task Max_tokens_stop_reason_is_reported_with_a_hint()
    {
        var handler = new FakeHttpMessageHandler().RespondJson(Canned("{\"layout_type\":\"br", stopReason: "max_tokens"));

        var ex = await Assert.ThrowsAsync<ProviderException>(() => Make(handler).AnalyzeAsync(Image, Req(), CancellationToken.None));

        Assert.False(ex.IsTransient);
        Assert.Contains("Claude:MaxTokens", ex.Message);
    }

    [Fact]
    public async Task Overloaded_529_and_429_are_transient_401_is_not()
    {
        var overloaded = new FakeHttpMessageHandler().Respond((HttpStatusCode)529, """{"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}""");
        var tooMany = new FakeHttpMessageHandler().Respond(HttpStatusCode.TooManyRequests, """{"type":"error","error":{"type":"rate_limit_error","message":"slow down"}}""");
        var unauthorized = new FakeHttpMessageHandler().Respond(HttpStatusCode.Unauthorized, """{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}""");

        var ex1 = await Assert.ThrowsAsync<ProviderException>(() => Make(overloaded).AnalyzeAsync(Image, Req(), CancellationToken.None));
        var ex2 = await Assert.ThrowsAsync<ProviderException>(() => Make(tooMany).AnalyzeAsync(Image, Req(), CancellationToken.None));
        var ex3 = await Assert.ThrowsAsync<ProviderException>(() => Make(unauthorized).AnalyzeAsync(Image, Req(), CancellationToken.None));

        Assert.True(ex1.IsTransient);
        Assert.Contains("Overloaded", ex1.Message);
        Assert.True(ex2.IsTransient);
        Assert.False(ex3.IsTransient);
        Assert.Contains("invalid x-api-key", ex3.Message);

        // What the client may see: a fixed phrase with the status, never the upstream body.
        Assert.Equal("upstream returned HTTP 529", ex1.PublicMessage);
        Assert.Equal("upstream returned HTTP 429", ex2.PublicMessage);
        Assert.Equal("upstream returned HTTP 401", ex3.PublicMessage);
        Assert.DoesNotContain("invalid x-api-key", ex3.PublicMessage);
    }

    [Fact]
    public async Task Refusal_and_truncation_have_generic_public_messages()
    {
        var refusal = new FakeHttpMessageHandler().RespondJson(Canned("", stopReason: "refusal", refusalExplanation: "internal detail"));
        var truncated = new FakeHttpMessageHandler().RespondJson(Canned("{\"layout_type\":\"br", stopReason: "max_tokens"));

        var ex1 = await Assert.ThrowsAsync<ProviderException>(() => Make(refusal).AnalyzeAsync(Image, Req(), CancellationToken.None));
        var ex2 = await Assert.ThrowsAsync<ProviderException>(() => Make(truncated).AnalyzeAsync(Image, Req(), CancellationToken.None));

        Assert.Equal("the model declined to analyze this image", ex1.PublicMessage);
        Assert.DoesNotContain("internal detail", ex1.PublicMessage);
        Assert.Equal("upstream output was truncated", ex2.PublicMessage);
    }

    [Fact]
    public async Task Response_without_text_block_is_an_error()
    {
        var handler = new FakeHttpMessageHandler().RespondJson("""{"id":"m","type":"message","content":[{"type":"thinking","thinking":""}],"stop_reason":"end_turn"}""");

        var ex = await Assert.ThrowsAsync<ProviderException>(() => Make(handler).AnalyzeAsync(Image, Req(), CancellationToken.None));

        Assert.Contains("no text block", ex.Message);
    }
}
