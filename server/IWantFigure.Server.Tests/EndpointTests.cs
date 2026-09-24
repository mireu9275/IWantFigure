using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using IWantFigure.Server.Providers;
using IWantFigure.Server.Tests.Support;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

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

/// <summary>
/// X-Forwarded-For handling: the header must only be honoured when it comes from a configured
/// proxy. Every request in these tests arrives from 10.0.0.5 (the "proxy") with limit 1/min.
/// </summary>
public class ForwardedHeadersTests
{
    private const string ProxyIp = "10.0.0.5";

    private static ServerFactory Factory(IDictionary<string, string?> extra)
    {
        var settings = new Dictionary<string, string?>
        {
            ["Server:UseForwardedHeaders"] = "true",
            ["Server:RateLimitPerMinute"] = "1",
        };
        foreach (KeyValuePair<string, string?> kv in extra)
        {
            settings[kv.Key] = kv.Value;
        }
        return ServerFactory.WithSettings(settings, services =>
            services.AddSingleton<IStartupFilter>(new FakeRemoteIpStartupFilter(ProxyIp)));
    }

    private static Task<HttpResponseMessage> Post(HttpClient client, string forwardedFor)
    {
        var request = new HttpRequestMessage(HttpMethod.Post, "/api/v1/analyze")
        {
            Content = JsonContent.Create(new { image_base64 = Convert.ToBase64String(TestImages.Jpeg(64, 48)), mime = "image/jpeg" }),
        };
        request.Headers.Add("X-Forwarded-For", forwardedFor);
        return client.SendAsync(request);
    }

    [Fact]
    public async Task Known_proxy_by_ip_makes_the_rate_limit_per_forwarded_client()
    {
        using ServerFactory factory = Factory(new Dictionary<string, string?> { ["Server:KnownProxies:0"] = ProxyIp });
        HttpClient client = factory.CreateClient();

        HttpResponseMessage first = await Post(client, "203.0.113.1");
        HttpResponseMessage second = await Post(client, "203.0.113.2");

        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        Assert.Equal(HttpStatusCode.OK, second.StatusCode); // different client -> own bucket
    }

    [Fact]
    public async Task Known_network_cidr_also_trusts_the_proxy()
    {
        using ServerFactory factory = Factory(new Dictionary<string, string?> { ["Server:KnownNetworks:0"] = "10.0.0.0/8" });
        HttpClient client = factory.CreateClient();

        Assert.Equal(HttpStatusCode.OK, (await Post(client, "203.0.113.1")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await Post(client, "203.0.113.2")).StatusCode);
    }

    [Fact]
    public async Task Same_forwarded_client_is_still_limited()
    {
        using ServerFactory factory = Factory(new Dictionary<string, string?> { ["Server:KnownProxies:0"] = ProxyIp });
        HttpClient client = factory.CreateClient();

        Assert.Equal(HttpStatusCode.OK, (await Post(client, "203.0.113.1")).StatusCode);
        Assert.Equal(HttpStatusCode.TooManyRequests, (await Post(client, "203.0.113.1")).StatusCode);
    }

    [Fact]
    public async Task Without_a_known_proxy_the_header_is_ignored_and_everyone_shares_one_bucket()
    {
        using ServerFactory factory = Factory(new Dictionary<string, string?>());
        HttpClient client = factory.CreateClient();

        HttpResponseMessage first = await Post(client, "203.0.113.1");
        HttpResponseMessage second = await Post(client, "203.0.113.2");

        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        Assert.Equal(HttpStatusCode.TooManyRequests, second.StatusCode);
        Assert.Equal("60", second.Headers.RetryAfter?.ToString());
        using JsonDocument json = JsonDocument.Parse(await second.Content.ReadAsStringAsync());
        Assert.Equal("rate_limited", json.RootElement.GetProperty("error").GetString());
    }
}

/// <summary>What the client sees when the provider fails: a generic phrase, never upstream diagnostics.</summary>
public class ProviderErrorResponseTests
{
    private static ServerFactory Factory(Exception exception) =>
        ServerFactory.WithSettings(new Dictionary<string, string?>(), services =>
        {
            services.RemoveAll<IAnalysisProvider>();
            services.AddSingleton<IAnalysisProvider>(new ThrowingProvider(exception));
        });

    private static object Body() => new { image_base64 = Convert.ToBase64String(TestImages.Jpeg(64, 48)), mime = "image/jpeg" };

    [Fact]
    public async Task Provider_error_returns_502_with_the_generic_public_message_only()
    {
        const string secretBody = "{\"error\":{\"message\":\"invalid x-api-key sk-ant-SECRET\"}}";
        using ServerFactory factory = Factory(new ProviderException(
            "claude: HTTP 401 Unauthorized: " + secretBody, isTransient: false, publicMessage: "upstream returned HTTP 401"));

        HttpResponseMessage response = await factory.CreateClient().PostAsJsonAsync("/api/v1/analyze", Body());

        Assert.Equal(HttpStatusCode.BadGateway, response.StatusCode);
        string text = await response.Content.ReadAsStringAsync();
        using JsonDocument json = JsonDocument.Parse(text);
        Assert.Equal("provider_error", json.RootElement.GetProperty("error").GetString());
        Assert.Equal("upstream returned HTTP 401", json.RootElement.GetProperty("provider_message").GetString());
        Assert.DoesNotContain("SECRET", text);
        Assert.DoesNotContain("Unauthorized", text);
    }

    [Fact]
    public async Task Provider_error_without_public_message_falls_back_to_a_fixed_phrase()
    {
        using ServerFactory factory = Factory(new ProviderException("gemini: something with a body <html>...</html>", isTransient: false));

        HttpResponseMessage response = await factory.CreateClient().PostAsJsonAsync("/api/v1/analyze", Body());

        Assert.Equal(HttpStatusCode.BadGateway, response.StatusCode);
        using JsonDocument json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        Assert.Equal(ProviderException.DefaultPublicMessage, json.RootElement.GetProperty("provider_message").GetString());
    }
}
