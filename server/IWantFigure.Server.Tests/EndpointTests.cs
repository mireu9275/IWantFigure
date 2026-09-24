using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using IWantFigure.Server.Tests.Support;

namespace IWantFigure.Server.Tests;

/// <summary>Black-box tests through the real HTTP pipeline (Program.cs) with the mock provider.</summary>
public class EndpointTests : IClassFixture<ServerFactory>
{
    private readonly HttpClient _client;

    public EndpointTests(ServerFactory factory)
    {
        _client = factory.CreateClient();
    }

    private static object Request(byte[] image, string mime = "image/jpeg", string locale = "ko", object? hints = null) => new
    {
        image_base64 = Convert.ToBase64String(image),
        mime,
        locale,
        hints,
    };

    private static async Task<JsonDocument> ReadJson(HttpResponseMessage response) =>
        JsonDocument.Parse(await response.Content.ReadAsStringAsync());

    [Fact]
    public async Task Healthz_reports_ok_and_provider()
    {
        HttpResponseMessage response = await _client.GetAsync("/healthz");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        using JsonDocument json = await ReadJson(response);
        Assert.Equal("ok", json.RootElement.GetProperty("status").GetString());
        Assert.Equal("mock", json.RootElement.GetProperty("provider").GetString());
    }

    [Fact]
    public async Task Analyze_returns_schema_document_plus_metadata()
    {
        HttpResponseMessage response = await _client.PostAsJsonAsync("/api/v1/analyze", Request(TestImages.Jpeg(640, 480)));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("application/json", response.Content.Headers.ContentType?.MediaType);

        using JsonDocument json = await ReadJson(response);
        JsonElement root = json.RootElement;

        // metadata
        Assert.True(Guid.TryParse(root.GetProperty("analysis_id").GetString(), out _));
        Assert.Equal("mock", root.GetProperty("provider").GetString());
        Assert.False(string.IsNullOrEmpty(root.GetProperty("model").GetString()));
        Assert.True(root.GetProperty("latency_ms").GetInt32() >= 0);
        Assert.Equal(640, root.GetProperty("image").GetProperty("width").GetInt32());
        Assert.Equal(480, root.GetProperty("image").GetProperty("height").GetInt32());

        // every required schema key, snake_case
        foreach (string key in new[] { "layout_type", "confidence", "machine", "objects", "strategy", "explanation", "needs_more_photos", "warnings" })
        {
            Assert.True(root.TryGetProperty(key, out _), $"missing {key}");
        }
        Assert.Equal("bridge_parallel", root.GetProperty("layout_type").GetString());
        Assert.Equal(2, root.GetProperty("machine").GetProperty("claw_count").GetInt32());
        Assert.Equal(5, root.GetProperty("objects").GetArrayLength());

        JsonElement box1 = root.GetProperty("objects")[0];
        Assert.Equal("box1", box1.GetProperty("id").GetString());
        Assert.Equal("box", box1.GetProperty("kind").GetString());
        Assert.Equal(new[] { 0.36, 0.42, 0.64, 0.74 }, box1.GetProperty("bbox").EnumerateArray().Select(e => e.GetDouble()));

        JsonElement strategy = root.GetProperty("strategy");
        Assert.Equal("box1", strategy.GetProperty("target_object_id").GetString());
        Assert.Equal("back_right", strategy.GetProperty("target_edge").GetString());
        Assert.Equal(3, strategy.GetProperty("sequence").GetArrayLength());

        // Japanese text must survive the round trip
        Assert.Contains("橋渡し", root.GetProperty("explanation").GetString());
    }

    [Fact]
    public async Task Analyze_reports_the_resized_image_size()
    {
        HttpResponseMessage response = await _client.PostAsJsonAsync("/api/v1/analyze", Request(TestImages.Jpeg(3000, 2000)));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        using JsonDocument json = await ReadJson(response);
        Assert.Equal(1456, json.RootElement.GetProperty("image").GetProperty("width").GetInt32());
        Assert.Equal(971, json.RootElement.GetProperty("image").GetProperty("height").GetInt32());
    }

    [Fact]
    public async Task Analyze_accepts_png_and_webp_mimes()
    {
        HttpResponseMessage response = await _client.PostAsJsonAsync("/api/v1/analyze", Request(TestImages.Png(300, 200), mime: "image/png"));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task Analyze_without_image_is_400()
    {
        HttpResponseMessage response = await _client.PostAsJsonAsync("/api/v1/analyze", new { mime = "image/jpeg", locale = "ko" });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        using JsonDocument json = await ReadJson(response);
        Assert.Equal("missing_image", json.RootElement.GetProperty("error").GetString());
    }

    [Fact]
    public async Task Analyze_with_unknown_mime_is_400()
    {
        HttpResponseMessage response = await _client.PostAsJsonAsync("/api/v1/analyze", Request(TestImages.Jpeg(64, 64), mime: "image/gif"));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        using JsonDocument json = await ReadJson(response);
        Assert.Equal("unsupported_mime", json.RootElement.GetProperty("error").GetString());
    }

    [Fact]
    public async Task Analyze_with_bad_base64_is_400()
    {
        HttpResponseMessage response = await _client.PostAsJsonAsync("/api/v1/analyze", new { image_base64 = "@@not base64@@", mime = "image/jpeg" });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        using JsonDocument json = await ReadJson(response);
        Assert.Equal("invalid_base64", json.RootElement.GetProperty("error").GetString());
    }

    [Fact]
    public async Task Analyze_with_non_image_bytes_is_400()
    {
        HttpResponseMessage response = await _client.PostAsJsonAsync("/api/v1/analyze", Request("hello world"u8.ToArray()));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        using JsonDocument json = await ReadJson(response);
        Assert.Equal("invalid_image", json.RootElement.GetProperty("error").GetString());
    }

    [Fact]
    public async Task Analyze_with_malformed_json_is_400()
    {
        HttpResponseMessage response = await _client.PostAsync("/api/v1/analyze", new StringContent("{not json", System.Text.Encoding.UTF8, "application/json"));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        using JsonDocument json = await ReadJson(response);
        Assert.Equal("invalid_json", json.RootElement.GetProperty("error").GetString());
    }

    [Fact]
    public async Task Analyze_with_non_json_content_type_is_415()
    {
        HttpResponseMessage response = await _client.PostAsync("/api/v1/analyze", new StringContent("image=...", System.Text.Encoding.UTF8, "text/plain"));

        Assert.Equal(HttpStatusCode.UnsupportedMediaType, response.StatusCode);
        using JsonDocument json = await ReadJson(response);
        Assert.Equal("unsupported_media_type", json.RootElement.GetProperty("error").GetString());
    }

    [Fact]
    public async Task Hints_notes_containing_unknown_return_the_unknown_variant()
    {
        object body = Request(TestImages.Jpeg(640, 480), hints: new { claw_count = 2, notes = "still unknown after three plays" });

        HttpResponseMessage response = await _client.PostAsJsonAsync("/api/v1/analyze", body);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        using JsonDocument json = await ReadJson(response);
        Assert.Equal("unknown", json.RootElement.GetProperty("layout_type").GetString());
        Assert.True(json.RootElement.GetProperty("needs_more_photos").GetArrayLength() > 0);
        Assert.Equal("unknown", json.RootElement.GetProperty("strategy").GetProperty("technique").GetString());
    }
}

/// <summary>Separate factory: Server:AppKey configured.</summary>
public class AppKeyTests
{
    private static ServerFactory Factory() => ServerFactory.WithSettings(new Dictionary<string, string?> { ["Server:AppKey"] = "s3cret" });

    private static object Body() => new { image_base64 = Convert.ToBase64String(TestImages.Jpeg(64, 48)), mime = "image/jpeg", locale = "en" };

    [Fact]
    public async Task Missing_header_is_401()
    {
        using ServerFactory factory = Factory();
        HttpClient client = factory.CreateClient();

        HttpResponseMessage response = await client.PostAsJsonAsync("/api/v1/analyze", Body());

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        using JsonDocument json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        Assert.Equal("unauthorized", json.RootElement.GetProperty("error").GetString());
    }

    [Fact]
    public async Task Wrong_header_is_401()
    {
        using ServerFactory factory = Factory();
        HttpClient client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-App-Key", "wrong");

        HttpResponseMessage response = await client.PostAsJsonAsync("/api/v1/analyze", Body());

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Correct_header_is_200()
    {
        using ServerFactory factory = Factory();
        HttpClient client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-App-Key", "s3cret");

        HttpResponseMessage response = await client.PostAsJsonAsync("/api/v1/analyze", Body());

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task Healthz_does_not_require_the_key()
    {
        using ServerFactory factory = Factory();
        HttpResponseMessage response = await factory.CreateClient().GetAsync("/healthz");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }
}

/// <summary>Separate factory: provider selected but no key -> 503.</summary>
public class ProviderNotConfiguredTests
{
    [Theory]
    [InlineData("gemini")]
    [InlineData("claude")]
    public async Task Selected_provider_without_key_is_503(string provider)
    {
        using ServerFactory factory = ServerFactory.WithSettings(new Dictionary<string, string?>
        {
            ["Analysis:Provider"] = provider,
            ["Gemini:ApiKey"] = "",
            ["Claude:ApiKey"] = "",
        });
        HttpClient client = factory.CreateClient();

        HttpResponseMessage health = await client.GetAsync("/healthz");
        using JsonDocument healthJson = JsonDocument.Parse(await health.Content.ReadAsStringAsync());
        Assert.Equal(provider, healthJson.RootElement.GetProperty("provider").GetString());

        HttpResponseMessage response = await client.PostAsJsonAsync("/api/v1/analyze",
            new { image_base64 = Convert.ToBase64String(TestImages.Jpeg(64, 48)), mime = "image/jpeg" });

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        using JsonDocument json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        Assert.Equal("provider_not_configured", json.RootElement.GetProperty("error").GetString());
    }
}
