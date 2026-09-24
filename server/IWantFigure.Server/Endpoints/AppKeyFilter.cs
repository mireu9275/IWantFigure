using System.Security.Cryptography;
using System.Text;
using IWantFigure.Server.Configuration;
using IWantFigure.Server.Contracts;
using IWantFigure.Server.Shared;
using Microsoft.Extensions.Options;

namespace IWantFigure.Server.Endpoints;

/// <summary>
/// Endpoint filter: when Server:AppKey is configured, the request must carry the same value
/// in the X-App-Key header, otherwise 401 {"error":"unauthorized"}. No key configured = open.
/// </summary>
public sealed class AppKeyFilter : IEndpointFilter
{
    public const string HeaderName = "X-App-Key";

    private readonly ServerOptions _options;

    public AppKeyFilter(IOptions<ServerOptions> options)
    {
        _options = options.Value;
    }

    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        string? expected = _options.AppKey;
        if (string.IsNullOrEmpty(expected))
        {
            return await next(context);
        }

        string provided = context.HttpContext.Request.Headers[HeaderName].ToString();
        if (!FixedTimeEquals(provided, expected))
        {
            return Results.Json(new ErrorResponse("unauthorized"), ServerJson.Response, statusCode: StatusCodes.Status401Unauthorized);
        }

        return await next(context);
    }

    /// <summary>Constant-time comparison so response timing does not leak how many characters matched.</summary>
    private static bool FixedTimeEquals(string a, string b)
    {
        byte[] x = Encoding.UTF8.GetBytes(a);
        byte[] y = Encoding.UTF8.GetBytes(b);
        return x.Length == y.Length && CryptographicOperations.FixedTimeEquals(x, y);
    }
}
