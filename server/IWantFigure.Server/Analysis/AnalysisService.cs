using System.Diagnostics;
using IWantFigure.Server.Contracts;
using IWantFigure.Server.Imaging;
using IWantFigure.Server.Models;
using IWantFigure.Server.Providers;

namespace IWantFigure.Server.Analysis;

/// <summary>
/// Orchestrates one analysis: validate + prepare the image, call the provider (with one
/// retry), normalize, attach metadata. Registered as scoped; the provider it wraps is
/// whatever Analysis:Provider selected.
/// </summary>
public sealed class AnalysisService
{
    private static readonly HashSet<string> AllowedMimes = new(StringComparer.OrdinalIgnoreCase)
    {
        "image/jpeg", "image/png", "image/webp",
    };

    private readonly ImagePipeline _pipeline;
    private readonly IAnalysisProvider _provider;
    private readonly AnalysisNormalizer _normalizer;
    private readonly ILogger<AnalysisService> _logger;

    public AnalysisService(ImagePipeline pipeline, IAnalysisProvider provider, AnalysisNormalizer normalizer, ILogger<AnalysisService> logger)
    {
        _pipeline = pipeline;
        _provider = provider;
        _normalizer = normalizer;
        _logger = logger;
    }

    public async Task<AnalysisResponse> AnalyzeAsync(AnalyzeRequest request, CancellationToken ct)
    {
        var stopwatch = Stopwatch.StartNew();
        string analysisId = Guid.NewGuid().ToString();

        byte[] sourceBytes = DecodeImage(request);
        PreparedImage image = _pipeline.Prepare(sourceBytes);
        _logger.LogDebug("analysis {AnalysisId}: image prepared {Width}x{Height} ({Bytes} bytes) in {ElapsedMs} ms",
            analysisId, image.Width, image.Height, image.Bytes.Length, stopwatch.ElapsedMilliseconds);

        // One retry: a transient upstream failure (429/5xx/network) or an answer that is not
        // valid JSON gets a second chance. Everything else (auth errors, refusals, truncation)
        // fails immediately - repeating those only burns money.
        const int maxAttempts = 2;
        AnalysisDocument? document = null;
        ProviderUsage? usage = null;
        int attempt = 0;

        while (document is null)
        {
            attempt++;
            try
            {
                ProviderResult result = await _provider.AnalyzeAsync(image, request, ct).ConfigureAwait(false);
                usage = result.Usage;
                document = _normalizer.Normalize(result, image.Width, image.Height);
            }
            catch (ProviderException ex) when (ex.IsTransient && attempt < maxAttempts)
            {
                _logger.LogWarning(ex, "analysis {AnalysisId}: provider {Provider} transient failure on attempt {Attempt}, retrying", analysisId, _provider.Name, attempt);
            }
            catch (AnalysisFormatException ex) when (attempt < maxAttempts)
            {
                _logger.LogWarning(ex, "analysis {AnalysisId}: provider {Provider} returned unusable JSON on attempt {Attempt}, retrying", analysisId, _provider.Name, attempt);
            }
        }

        stopwatch.Stop();
        AnalysisResponse response = AnalysisResponse.From(document);
        response.AnalysisId = analysisId;
        response.Provider = _provider.Name;
        response.Model = _provider.Model;
        response.LatencyMs = (int)Math.Min(int.MaxValue, stopwatch.ElapsedMilliseconds);
        response.Image = new ImageInfo { Width = image.Width, Height = image.Height };

        // Structured log line: latency, provider, tokens. Never the image, never keys.
        _logger.LogInformation(
            "analysis {AnalysisId} ok provider={Provider} model={Model} latency_ms={LatencyMs} attempts={Attempts} image={Width}x{Height} layout={LayoutType} confidence={Confidence} objects={ObjectCount} tokens_in={TokensIn} tokens_out={TokensOut} cache_read={CacheRead}",
            analysisId, _provider.Name, _provider.Model, response.LatencyMs, attempt, image.Width, image.Height,
            document.LayoutType, document.Confidence, document.Objects.Count,
            usage?.InputTokens, usage?.OutputTokens, usage?.CacheReadTokens);

        return response;
    }

    /// <summary>Validates mime + base64 and returns the raw file bytes. Throws InvalidImageException (HTTP 400).</summary>
    internal static byte[] DecodeImage(AnalyzeRequest request)
    {
        string? b64 = request.ImageBase64;
        if (string.IsNullOrWhiteSpace(b64))
        {
            throw new InvalidImageException("missing_image", "image_base64 is required");
        }

        string? mime = request.Mime?.Trim().ToLowerInvariant();
        if (mime == "image/jpg")
        {
            mime = "image/jpeg"; // common misspelling
        }
        if (!string.IsNullOrEmpty(mime) && !AllowedMimes.Contains(mime))
        {
            throw new InvalidImageException("unsupported_mime", $"mime '{mime}' is not supported; use image/jpeg, image/png or image/webp");
        }

        // Tolerate "data:image/jpeg;base64,...." as produced by some client libraries.
        if (b64.StartsWith("data:", StringComparison.OrdinalIgnoreCase))
        {
            int comma = b64.IndexOf(',');
            if (comma > 0)
            {
                b64 = b64[(comma + 1)..];
            }
        }

        try
        {
            return Convert.FromBase64String(b64);
        }
        catch (FormatException ex)
        {
            throw new InvalidImageException("invalid_base64", "image_base64 is not valid base64", ex);
        }
    }
}
