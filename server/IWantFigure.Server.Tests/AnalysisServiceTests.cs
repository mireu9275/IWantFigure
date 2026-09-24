using System.Diagnostics;
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

/// <summary>Retry policy of the orchestration layer, using a scripted in-memory provider.</summary>
public class AnalysisServiceTests
{
    private sealed class ScriptedProvider : IAnalysisProvider
    {
        private readonly Queue<Func<ProviderResult>> _steps;

        public ScriptedProvider(params Func<ProviderResult>[] steps)
        {
            _steps = new Queue<Func<ProviderResult>>(steps);
        }

        public int Calls { get; private set; }

        public string Name => "scripted";

        public string Model => "scripted-1";

        public Task<ProviderResult> AnalyzeAsync(PreparedImage image, AnalyzeRequest request, CancellationToken ct)
        {
            Calls++;
            return Task.FromResult(_steps.Dequeue()());
        }
    }

    private static AnalysisService Service(IAnalysisProvider provider, int retryDelayMs = 0, int maxRetryDelayMs = 5000)
    {
        var options = new AnalysisOptions { RetryDelayMs = retryDelayMs, MaxRetryDelayMs = maxRetryDelayMs };
        return new AnalysisService(
            new ImagePipeline(Options.Create(options)),
            provider,
            new AnalysisNormalizer(AnalysisSchema.Embedded),
            Options.Create(options),
            NullLogger<AnalysisService>.Instance);
    }

    private static AnalyzeRequest Request() => new()
    {
        ImageBase64 = Convert.ToBase64String(TestImages.Jpeg(200, 100)),
        Mime = "image/jpeg",
        Locale = "en",
    };

    private static ProviderResult Good() => new(SampleJson.Normalized, CoordinateConvention.NormalizedUnit);

    [Fact]
    public async Task Transient_failure_is_retried_once_then_succeeds()
    {
        var provider = new ScriptedProvider(
            () => throw new ProviderException("503 from upstream", isTransient: true),
            Good);

        AnalysisResponse response = await Service(provider).AnalyzeAsync(Request(), CancellationToken.None);

        Assert.Equal(2, provider.Calls);
        Assert.Equal("scripted", response.Provider);
        Assert.Equal("scripted-1", response.Model);
        Assert.Equal(200, response.Image.Width);
        Assert.Equal(100, response.Image.Height);
        Assert.True(Guid.TryParse(response.AnalysisId, out _));
        Assert.Equal("bridge_parallel", response.LayoutType);
    }

    [Fact]
    public async Task Retry_waits_the_configured_delay()
    {
        var provider = new ScriptedProvider(
            () => throw new ProviderException("429", isTransient: true),
            Good);
        var stopwatch = Stopwatch.StartNew();

        await Service(provider, retryDelayMs: 300).AnalyzeAsync(Request(), CancellationToken.None);

        Assert.True(stopwatch.ElapsedMilliseconds >= 280, $"only waited {stopwatch.ElapsedMilliseconds} ms");
        Assert.Equal(2, provider.Calls);
    }

    [Fact]
    public async Task Retry_honours_upstream_retry_after_when_longer_than_the_default()
    {
        var provider = new ScriptedProvider(
            () => throw new ProviderException("529 overloaded", isTransient: true, retryAfter: TimeSpan.FromMilliseconds(400)),
            Good);
        var stopwatch = Stopwatch.StartNew();

        await Service(provider, retryDelayMs: 50).AnalyzeAsync(Request(), CancellationToken.None);

        Assert.True(stopwatch.ElapsedMilliseconds >= 380, $"only waited {stopwatch.ElapsedMilliseconds} ms");
    }

    [Fact]
    public async Task Retry_after_is_capped_so_the_phone_is_not_kept_waiting()
    {
        var provider = new ScriptedProvider(
            () => throw new ProviderException("429", isTransient: true, retryAfter: TimeSpan.FromSeconds(120)),
            Good);
        var stopwatch = Stopwatch.StartNew();

        await Service(provider, retryDelayMs: 0, maxRetryDelayMs: 200).AnalyzeAsync(Request(), CancellationToken.None);

        Assert.InRange(stopwatch.ElapsedMilliseconds, 180, 5000);
    }

    [Fact]
    public async Task Unparseable_json_is_retried_once_then_fails()
    {
        var provider = new ScriptedProvider(
            () => new ProviderResult("sorry, no", CoordinateConvention.NormalizedUnit),
            () => new ProviderResult("still no", CoordinateConvention.NormalizedUnit));

        await Assert.ThrowsAsync<AnalysisFormatException>(() => Service(provider).AnalyzeAsync(Request(), CancellationToken.None));

        Assert.Equal(2, provider.Calls);
    }

    [Fact]
    public async Task Non_transient_failure_is_not_retried()
    {
        var provider = new ScriptedProvider(
            () => throw new ProviderException("401 bad key", isTransient: false),
            Good);

        var ex = await Assert.ThrowsAsync<ProviderException>(() => Service(provider).AnalyzeAsync(Request(), CancellationToken.None));

        Assert.Equal(1, provider.Calls);
        Assert.Contains("401", ex.Message);
    }

    [Fact]
    public async Task Two_transient_failures_surface_the_second_error()
    {
        var provider = new ScriptedProvider(
            () => throw new ProviderException("first", isTransient: true),
            () => throw new ProviderException("second", isTransient: true));

        var ex = await Assert.ThrowsAsync<ProviderException>(() => Service(provider).AnalyzeAsync(Request(), CancellationToken.None));

        Assert.Equal(2, provider.Calls);
        Assert.Equal("second", ex.Message);
    }

    [Fact]
    public async Task Not_configured_propagates_without_retry()
    {
        var provider = new ScriptedProvider(() => throw new ProviderNotConfiguredException("scripted"));

        await Assert.ThrowsAsync<ProviderNotConfiguredException>(() => Service(provider).AnalyzeAsync(Request(), CancellationToken.None));

        Assert.Equal(1, provider.Calls);
    }

    [Fact]
    public async Task Data_url_prefix_is_tolerated()
    {
        var provider = new ScriptedProvider(Good);
        AnalyzeRequest request = Request();
        request.ImageBase64 = "data:image/jpeg;base64," + request.ImageBase64;

        AnalysisResponse response = await Service(provider).AnalyzeAsync(request, CancellationToken.None);

        Assert.Equal(200, response.Image.Width);
    }
}
