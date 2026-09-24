using System.Net;
using System.Threading.RateLimiting;
using IWantFigure.Server.Analysis;
using IWantFigure.Server.Configuration;
using IWantFigure.Server.Endpoints;
using IWantFigure.Server.Imaging;
using IWantFigure.Server.Providers;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.RateLimiting;

// ---------------------------------------------------------------------------
// IWantFigure server - one endpoint that turns a crane-game photo into a
// "where to aim" analysis via a multimodal LLM. See README.md for how to run.
// ---------------------------------------------------------------------------

WebApplicationBuilder builder = WebApplication.CreateBuilder(args);

// ---- configuration --------------------------------------------------------
builder.Services.Configure<ServerOptions>(builder.Configuration.GetSection(ServerOptions.Section));
builder.Services.Configure<AnalysisOptions>(builder.Configuration.GetSection(AnalysisOptions.Section));
builder.Services.Configure<GeminiOptions>(builder.Configuration.GetSection(GeminiOptions.Section));
builder.Services.Configure<ClaudeOptions>(builder.Configuration.GetSection(ClaudeOptions.Section));

ServerOptions serverOptions = builder.Configuration.GetSection(ServerOptions.Section).Get<ServerOptions>() ?? new ServerOptions();

// ---- listen address: default http://localhost:8080 ---------------------------
// Only applied when nothing else configured a URL, so ASPNETCORE_URLS, --urls and
// launchSettings.json keep working the standard way.
if (string.IsNullOrWhiteSpace(builder.Configuration[WebHostDefaults.ServerUrlsKey]))
{
    builder.WebHost.UseUrls("http://localhost:8080");
}

// ---- Kestrel: 12 MB body limit (base64 image + JSON envelope) --------------
builder.WebHost.ConfigureKestrel(kestrel => kestrel.Limits.MaxRequestBodySize = serverOptions.MaxRequestBodyBytes);

// ---- rate limiting: fixed window per client IP for the analyze endpoint ----
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddPolicy(AnalyzeEndpoints.RateLimitPolicy, httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = Math.Max(1, serverOptions.RateLimitPerMinute),
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0, // reject instead of queueing - the phone is waiting
            }));
    options.OnRejected = async (context, token) =>
    {
        // The window is one minute, so tell well-behaved clients when to come back.
        context.HttpContext.Response.Headers.RetryAfter = "60";
        context.HttpContext.Response.ContentType = "application/json";
        await context.HttpContext.Response.WriteAsync("{\"error\":\"rate_limited\"}", token);
    };
});

// ---- application services --------------------------------------------------
builder.Services.AddSingleton(AnalysisSchema.Embedded);
builder.Services.AddSingleton<ImagePipeline>();
builder.Services.AddSingleton<AnalysisNormalizer>();
builder.Services.AddScoped<AnalysisService>();
builder.Services.AddAnalysisProvider(builder.Configuration); // mock | gemini | claude

WebApplication app = builder.Build();

if (serverOptions.UseForwardedHeaders)
{
    // Behind nginx / a cloud load balancer: trust X-Forwarded-For so rate limiting is per real client.
    // ASP.NET's defaults only trust loopback (KnownProxies = [::1], KnownNetworks = 127.0.0.0/8), so the
    // header would be silently ignored for a proxy on another host and every user would share one
    // rate-limit bucket. The operator lists the proxies explicitly; the loopback defaults are kept.
    var forwarded = new ForwardedHeadersOptions
    {
        ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto,
    };
    foreach (string entry in serverOptions.KnownProxies)
    {
        if (!IPAddress.TryParse(entry.Trim(), out IPAddress? proxy))
        {
            throw new InvalidOperationException($"Server:KnownProxies entry '{entry}' is not a valid IP address");
        }
        forwarded.KnownProxies.Add(proxy);
    }
    foreach (string entry in serverOptions.KnownNetworks)
    {
        if (!System.Net.IPNetwork.TryParse(entry.Trim(), out System.Net.IPNetwork network))
        {
            throw new InvalidOperationException($"Server:KnownNetworks entry '{entry}' is not a valid CIDR network (e.g. 10.0.0.0/8)");
        }
        forwarded.KnownIPNetworks.Add(network);
    }
    if (serverOptions.KnownProxies.Length == 0 && serverOptions.KnownNetworks.Length == 0)
    {
        app.Logger.LogWarning("Server:UseForwardedHeaders is on but no Server:KnownProxies / Server:KnownNetworks are configured; X-Forwarded-For will only be trusted from loopback");
    }
    app.UseForwardedHeaders(forwarded);
}

app.UseRateLimiter();
app.MapAnalyzeEndpoints();

app.Logger.LogInformation("IWantFigure server starting with provider={Provider}", (builder.Configuration["Analysis:Provider"] ?? "mock").ToLowerInvariant());
app.Run();

/// <summary>Makes the implicit Program class visible to WebApplicationFactory in the test project.</summary>
public partial class Program
{
}
