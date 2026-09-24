using System.Net;
using IWantFigure.Server.Contracts;
using IWantFigure.Server.Imaging;
using IWantFigure.Server.Providers;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;

namespace IWantFigure.Server.Tests.Support;

/// <summary>
/// TestServer has no real socket, so Connection.RemoteIpAddress is null. This startup filter
/// runs before every other middleware (including ForwardedHeaders) and stamps a fake client IP,
/// which is what a request coming through a proxy at that address would look like.
/// </summary>
public sealed class FakeRemoteIpStartupFilter : IStartupFilter
{
    private readonly IPAddress _remoteIp;

    public FakeRemoteIpStartupFilter(string remoteIp)
    {
        _remoteIp = IPAddress.Parse(remoteIp);
    }

    public Action<IApplicationBuilder> Configure(Action<IApplicationBuilder> next) => app =>
    {
        app.Use((context, nextMiddleware) =>
        {
            context.Connection.RemoteIpAddress = _remoteIp;
            return nextMiddleware(context);
        });
        next(app);
    };
}

/// <summary>An IAnalysisProvider that always throws the given exception (endpoint error-path tests).</summary>
public sealed class ThrowingProvider : IAnalysisProvider
{
    private readonly Exception _exception;

    public ThrowingProvider(Exception exception)
    {
        _exception = exception;
    }

    public string Name => "throwing";

    public string Model => "throwing-1";

    public Task<ProviderResult> AnalyzeAsync(PreparedImage image, AnalyzeRequest request, CancellationToken ct) =>
        Task.FromException<ProviderResult>(_exception);
}
