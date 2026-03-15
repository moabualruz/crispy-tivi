using System.Net;
using System.Text;

using Crispy.Infrastructure.Parsers.Xtream;

using FluentAssertions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Parsers;

public class XtreamClientTests
{
    [Fact]
    public async Task AuthenticateAsync_StoresServerTimezone()
    {
        const string json = """
            {
              "user_info": {
                "username": "testuser",
                "password": "testpass",
                "status": "Active",
                "exp_date": "1800000000",
                "max_connections": "2",
                "active_cons": "1"
              },
              "server_info": {
                "url": "test.example.com",
                "port": "8080",
                "https_port": "8443",
                "server_protocol": "http",
                "timezone": "Europe/London"
              }
            }
            """;

        var client = new HttpClient(new FakeMessageHandler(json))
        {
            BaseAddress = new Uri("http://test.example.com")
        };

        var xtreamClient = new XtreamClient(client);
        var result = await xtreamClient.AuthenticateAsync("testuser", "testpass");

        result.Should().NotBeNull();
        result!.ServerInfo.Should().NotBeNull();
        result.ServerInfo!.Timezone.Should().Be("Europe/London");
    }

    [Fact]
    public async Task AuthenticateAsync_ExpiringSoon_AuthResponseReturned()
    {
        // exp_date = 5 days from now (Unix timestamp)
        var expDate = DateTimeOffset.UtcNow.AddDays(5).ToUnixTimeSeconds();
        var json = $$"""
            {
              "user_info": {
                "username": "testuser",
                "password": "testpass",
                "status": "Active",
                "exp_date": "{{expDate}}",
                "max_connections": "2",
                "active_cons": "1"
              },
              "server_info": {
                "url": "test.example.com",
                "port": "8080",
                "https_port": "8443",
                "server_protocol": "http",
                "timezone": "UTC"
              }
            }
            """;

        var client = new HttpClient(new FakeMessageHandler(json))
        {
            BaseAddress = new Uri("http://test.example.com")
        };

        var xtreamClient = new XtreamClient(client);
        var result = await xtreamClient.AuthenticateAsync("testuser", "testpass");

        result.Should().NotBeNull();
        // Subscription expires in 5 days — within the 7-day warning window
        result!.UserInfo.Should().NotBeNull();
        result.UserInfo!.ExpDate.Should().NotBeNull();
        result.UserInfo.DaysUntilExpiry.Should().BeGreaterThanOrEqualTo(4).And.BeLessThanOrEqualTo(6);
    }

    private sealed class FakeMessageHandler : HttpMessageHandler
    {
        private readonly string _json;
        private readonly HttpStatusCode _status;

        public FakeMessageHandler(string json, HttpStatusCode status = HttpStatusCode.OK)
        {
            _json = json;
            _status = status;
        }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(new HttpResponseMessage(_status)
            {
                Content = new StringContent(_json, Encoding.UTF8, "application/json")
            });
        }
    }
}
