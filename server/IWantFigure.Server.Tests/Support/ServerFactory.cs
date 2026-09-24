using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;

namespace IWantFigure.Server.Tests.Support;

/// <summary>
/// Boots the real Program.cs in-memory with the mock provider, zero mock delay and a
/// generous rate limit. Extra settings override those defaults (e.g. Server:AppKey), and an
/// optional service hook can swap registrations (e.g. a scripted IAnalysisProvider).
/// </summary>
public sealed class ServerFactory : WebApplicationFactory<Program>
{
    private readonly IReadOnlyDictionary<string, string?> _settings;
    private readonly Action<IServiceCollection>? _configureServices;

    /// <summary>Default configuration (xUnit class fixtures need exactly one public constructor).</summary>
    public ServerFactory() : this(new Dictionary<string, string?>(), null)
    {
    }

    private ServerFactory(IReadOnlyDictionary<string, string?> settings, Action<IServiceCollection>? configureServices)
    {
        _settings = settings;
        _configureServices = configureServices;
    }

    /// <summary>A factory whose configuration overrides the defaults, e.g. Server:AppKey.</summary>
    public static ServerFactory WithSettings(IReadOnlyDictionary<string, string?> settings, Action<IServiceCollection>? configureServices = null) =>
        new(settings, configureServices);

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");

        var all = new Dictionary<string, string?>
        {
            ["Analysis:Provider"] = "mock",
            ["Analysis:MockDelayMs"] = "0",
            ["Analysis:RetryDelayMs"] = "0",
            ["Server:RateLimitPerMinute"] = "1000",
            ["Server:AppKey"] = "",
        };
        foreach (KeyValuePair<string, string?> kv in _settings)
        {
            all[kv.Key] = kv.Value;
        }
        foreach (KeyValuePair<string, string?> kv in all)
        {
            builder.UseSetting(kv.Key, kv.Value);
        }

        if (_configureServices is not null)
        {
            builder.ConfigureServices(_configureServices);
        }
    }
}
