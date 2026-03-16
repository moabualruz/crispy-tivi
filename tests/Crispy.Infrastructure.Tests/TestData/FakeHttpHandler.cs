using System.Net;
using System.Text;

namespace Crispy.Infrastructure.Tests.TestData;

/// <summary>
/// Reusable HTTP mock handler. Routes requests by URL substring and returns
/// pre-configured JSON responses. Falls back to 404 for unmapped URLs.
///
/// Usage:
/// <code>
/// var handler = new FakeHttpHandler()
///     .WithResponse("player_api.php", authJson)
///     .WithResponse("get_live_streams", liveJson, HttpStatusCode.OK);
/// var http = new HttpClient(handler) { BaseAddress = new Uri("http://fake.test") };
/// </code>
/// </summary>
public sealed class FakeHttpHandler : HttpMessageHandler
{
    private readonly List<(string UrlContains, string Json, HttpStatusCode Status)> _routes = [];

    /// <summary>Adds a response rule. The first matching rule wins.</summary>
    public FakeHttpHandler WithResponse(
        string urlContains,
        string json,
        HttpStatusCode status = HttpStatusCode.OK)
    {
        _routes.Add((urlContains, json, status));
        return this;
    }

    protected override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request,
        CancellationToken cancellationToken)
    {
        var url = request.RequestUri?.ToString() ?? string.Empty;

        foreach (var (contains, json, status) in _routes)
        {
            if (url.Contains(contains, StringComparison.OrdinalIgnoreCase))
            {
                return Task.FromResult(new HttpResponseMessage(status)
                {
                    Content = new StringContent(json, Encoding.UTF8, "application/json"),
                });
            }
        }

        // No match — return 404 with empty body
        return Task.FromResult(new HttpResponseMessage(HttpStatusCode.NotFound)
        {
            Content = new StringContent("{}", Encoding.UTF8, "application/json"),
        });
    }
}
