using System.Net;
using System.Text.Json;

namespace IWantFigure.Server.Providers;

/// <summary>
/// Shared HTTP plumbing for the REST providers: send, read, classify errors.
/// The single retry lives in <see cref="Analysis.AnalysisService"/> (one loop covers transport
/// errors and unparseable answers alike), so this helper never retries by itself.
/// </summary>
internal static class ProviderHttp
{
    /// <summary>Status codes that usually succeed on an immediate retry.</summary>
    private static bool IsTransientStatus(HttpStatusCode status) => (int)status switch
    {
        408 or 429 or 500 or 502 or 503 or 504 or 529 => true, // 529 = Anthropic "overloaded"
        _ => false,
    };

    /// <summary>
    /// Sends the request and returns the response body as text. Non-2xx responses and
    /// network failures become <see cref="ProviderException"/> with an IsTransient flag.
    /// </summary>
    public static async Task<string> SendAsync(HttpClient http, HttpRequestMessage request, string providerName, CancellationToken ct)
    {
        HttpResponseMessage response;
        try
        {
            response = await http.SendAsync(request, HttpCompletionOption.ResponseContentRead, ct).ConfigureAwait(false);
        }
        catch (HttpRequestException ex)
        {
            throw new ProviderException($"{providerName}: network error: {ex.Message}", isTransient: true, ex);
        }
        catch (TaskCanceledException ex) when (!ct.IsCancellationRequested)
        {
            // HttpClient.Timeout elapsed (the caller did not cancel). A second 30 s wait rarely helps a phone user.
            throw new ProviderException($"{providerName}: request timed out after {http.Timeout.TotalSeconds:0} s", isTransient: false, ex);
        }

        using (response)
        {
            string body = await response.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
            if (response.IsSuccessStatusCode)
            {
                return body;
            }

            string detail = ExtractErrorMessage(body);
            throw new ProviderException(
                $"{providerName}: HTTP {(int)response.StatusCode} {response.ReasonPhrase}: {detail}",
                IsTransientStatus(response.StatusCode));
        }
    }

    /// <summary>Both Google and Anthropic wrap errors as {"error": {"message": "..."}}. Fall back to a short body preview.</summary>
    private static string ExtractErrorMessage(string body)
    {
        if (string.IsNullOrWhiteSpace(body))
        {
            return "(empty body)";
        }
        try
        {
            using JsonDocument doc = JsonDocument.Parse(body);
            if (doc.RootElement.ValueKind == JsonValueKind.Object &&
                doc.RootElement.TryGetProperty("error", out JsonElement err))
            {
                if (err.ValueKind == JsonValueKind.Object && err.TryGetProperty("message", out JsonElement msg) && msg.ValueKind == JsonValueKind.String)
                {
                    return msg.GetString() ?? "";
                }
                if (err.ValueKind == JsonValueKind.String)
                {
                    return err.GetString() ?? "";
                }
            }
        }
        catch (JsonException)
        {
            // not JSON - fall through
        }
        return body.Length <= 300 ? body : body[..300] + "...";
    }

    /// <summary>Parses a provider response body; a non-JSON body is treated as a transient upstream glitch.</summary>
    public static JsonDocument ParseJson(string responseText, string providerName)
    {
        try
        {
            return JsonDocument.Parse(responseText);
        }
        catch (JsonException ex)
        {
            throw new ProviderException($"{providerName}: response is not JSON: {ex.Message}", isTransient: true, ex);
        }
    }

    /// <summary>Reads an optional integer property (null when absent or not a number).</summary>
    public static int? OptionalInt(JsonElement obj, string name)
    {
        if (obj.ValueKind == JsonValueKind.Object && obj.TryGetProperty(name, out JsonElement v) && v.ValueKind == JsonValueKind.Number && v.TryGetInt32(out int i))
        {
            return i;
        }
        return null;
    }
}
