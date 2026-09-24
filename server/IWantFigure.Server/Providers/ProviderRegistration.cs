using IWantFigure.Server.Configuration;

namespace IWantFigure.Server.Providers;

public static class ProviderRegistration
{
    /// <summary>
    /// Registers exactly one IAnalysisProvider based on Analysis:Provider. The REST providers
    /// are typed HttpClients (pooled handlers, configurable timeout). The factory's default
    /// request logging is removed so URLs/headers never reach the logs; providers log their
    /// own one-line summaries instead.
    /// </summary>
    public static IServiceCollection AddAnalysisProvider(this IServiceCollection services, IConfiguration configuration)
    {
        string providerName = (configuration["Analysis:Provider"] ?? "mock").Trim().ToLowerInvariant();
        int timeoutSeconds = configuration.GetValue<int?>("Analysis:ProviderTimeoutSeconds") ?? 30;
        TimeSpan timeout = TimeSpan.FromSeconds(Math.Clamp(timeoutSeconds, 5, 300));

        switch (providerName)
        {
            case "mock":
                services.AddSingleton<IAnalysisProvider, MockProvider>();
                break;

            case "gemini":
                services.AddHttpClient<IAnalysisProvider, GeminiProvider>(client => client.Timeout = timeout)
                        .RemoveAllLoggers();
                break;

            case "claude":
                services.AddHttpClient<IAnalysisProvider, ClaudeProvider>(client => client.Timeout = timeout)
                        .RemoveAllLoggers();
                break;

            default:
                throw new InvalidOperationException($"Unknown Analysis:Provider '{providerName}'. Use mock, gemini or claude.");
        }

        return services;
    }
}
