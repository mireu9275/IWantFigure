using System.Text.Json;
using IWantFigure.Server.Analysis;
using IWantFigure.Server.Contracts;
using IWantFigure.Server.Imaging;
using IWantFigure.Server.Models;
using IWantFigure.Server.Providers;
using IWantFigure.Server.Shared;

namespace IWantFigure.Server.Endpoints;

public static class AnalyzeEndpoints
{
    /// <summary>Name of the rate-limiting policy applied to the analyze endpoint.</summary>
    public const string RateLimitPolicy = "analyze";

    public static IEndpointRouteBuilder MapAnalyzeEndpoints(this IEndpointRouteBuilder app)
    {
        // GET /healthz -> {"status":"ok","provider":"mock|gemini|claude"}
        app.MapGet("/healthz", (IAnalysisProvider provider) =>
            Results.Json(new HealthResponse("ok", provider.Name), ServerJson.Response));

        // POST /api/v1/analyze
        app.MapPost("/api/v1/analyze", AnalyzeAsync)
           .AddEndpointFilter<AppKeyFilter>()
           .RequireRateLimiting(RateLimitPolicy)
           // No .Accepts<>() metadata on purpose: it would short-circuit wrong content types
           // with an empty 415; the handler returns the JSON error envelope instead.
           .Produces<AnalysisResponse>(StatusCodes.Status200OK)
           .Produces<ErrorResponse>(StatusCodes.Status400BadRequest)
           .Produces<ErrorResponse>(StatusCodes.Status401Unauthorized)
           .Produces<ErrorResponse>(StatusCodes.Status415UnsupportedMediaType)
           .Produces<ErrorResponse>(StatusCodes.Status502BadGateway)
           .Produces<ErrorResponse>(StatusCodes.Status503ServiceUnavailable);

        return app;
    }

    private static async Task<IResult> AnalyzeAsync(HttpContext http, AnalysisService service, ILogger<AnalysisService> logger, CancellationToken ct)
    {
        // Read the body ourselves so malformed JSON yields our {"error": ...} envelope
        // instead of the framework's default problem-details page.
        AnalyzeRequest? request;
        try
        {
            request = await http.Request.ReadFromJsonAsync<AnalyzeRequest>(ServerJson.Request, ct);
        }
        catch (JsonException ex)
        {
            return Error(StatusCodes.Status400BadRequest, "invalid_json", ex.Message);
        }
        catch (BadHttpRequestException ex)
        {
            // Body larger than Server:MaxRequestBodyBytes (413) or otherwise unreadable.
            return Error(ex.StatusCode, ex.StatusCode == StatusCodes.Status413PayloadTooLarge ? "request_too_large" : "bad_request", ex.Message);
        }
        catch (InvalidOperationException)
        {
            // ReadFromJsonAsync refuses bodies whose Content-Type is not application/json.
            return Error(StatusCodes.Status415UnsupportedMediaType, "unsupported_media_type", "Content-Type must be application/json");
        }

        if (request is null)
        {
            return Error(StatusCodes.Status400BadRequest, "missing_body", "expected a JSON object body");
        }

        try
        {
            AnalysisResponse response = await service.AnalyzeAsync(request, ct);
            return Results.Json(response, ServerJson.Response);
        }
        catch (InvalidImageException ex)
        {
            return Error(StatusCodes.Status400BadRequest, ex.Code, ex.Message);
        }
        catch (ProviderNotConfiguredException ex)
        {
            logger.LogError("{Message}", ex.Message);
            return Error(StatusCodes.Status503ServiceUnavailable, "provider_not_configured");
        }
        catch (ProviderException ex)
        {
            logger.LogError(ex, "provider call failed");
            return Results.Json(new ErrorResponse("provider_error", providerMessage: ex.Message), ServerJson.Response, statusCode: StatusCodes.Status502BadGateway);
        }
        catch (AnalysisFormatException ex)
        {
            logger.LogError(ex, "provider answer could not be normalized");
            return Results.Json(new ErrorResponse("provider_error", providerMessage: ex.Message), ServerJson.Response, statusCode: StatusCodes.Status502BadGateway);
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested)
        {
            // Client went away; nobody is listening for the body anyway.
            return Results.StatusCode(499);
        }
    }

    private static IResult Error(int status, string code, string? message = null) =>
        Results.Json(new ErrorResponse(code, message), ServerJson.Response, statusCode: status);
}
