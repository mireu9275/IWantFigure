using System.Net;
using System.Text;

namespace IWantFigure.Server.Tests.Support;

/// <summary>
/// Stand-in for the network: records every request (URL, headers, body) and answers with
/// whatever the test scripted. Responses are consumed in order; the last one repeats.
/// </summary>
public sealed class FakeHttpMessageHandler : HttpMessageHandler
{
    private readonly Queue<Func<HttpRequestMessage, HttpResponseMessage>> _responders = new();
    private Func<HttpRequestMessage, HttpResponseMessage>? _last;

    public List<HttpRequestMessage> Requests { get; } = new();

    public List<string> Bodies { get; } = new();

    /// <summary>Hooks applied to every scripted response before it is returned (e.g. to add headers).</summary>
    public List<Action<HttpResponseMessage>> Responses { get; } = new();

    public FakeHttpMessageHandler Respond(HttpStatusCode status, string body)
    {
        _responders.Enqueue(_ => new HttpResponseMessage(status)
        {
            Content = new StringContent(body, Encoding.UTF8, "application/json"),
        });
        return this;
    }

    public FakeHttpMessageHandler RespondJson(string body) => Respond(HttpStatusCode.OK, body);

    protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        Requests.Add(request);
        Bodies.Add(request.Content is null ? "" : await request.Content.ReadAsStringAsync(cancellationToken));

        if (_responders.Count > 0)
        {
            _last = _responders.Dequeue();
        }
        if (_last is null)
        {
            throw new InvalidOperationException("no scripted response");
        }
        HttpResponseMessage response = _last(request);
        foreach (Action<HttpResponseMessage> decorate in Responses)
        {
            decorate(response);
        }
        return response;
    }
}
