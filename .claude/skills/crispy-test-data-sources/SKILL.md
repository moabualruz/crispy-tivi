---
name: crispy-test-data-sources
description: Test source parsers (Xtream, Stalker, M3U, Jellyfin) using fake data fixtures with .local credential override. Use whenever writing parser tests, setting up test data for sources, or when user asks about testing with real IPTV subscriptions. Prevents credential leaks by enforcing gitignored .local files.
---

## Test Data Sources

### Directory

```
tests/Crispy.Infrastructure.Tests/TestData/Sources/
  xtream_categories.json    # fake live categories response
  xtream_streams.json       # fake live streams response
  xtream_vod.json           # fake VOD list
  m3u_playlist.m3u          # fake M3U8 playlist
  stalker_channels.json     # fake Stalker channels response
  xmltv_epg.xml             # fake XMLTV EPG data
  sources.local.json        # GITIGNORED — real credentials (never committed)
```

Committed fake fixtures live here. `.local.*` files in the same directory are gitignored and hold real credentials for local integration testing.

### NEVER Hardcode Credentials

> **NEVER** hardcode credentials as `const string` or inline literals in test files. Always use `TestSourceProvider`. Hardcoded credentials will be committed sooner or later.

```csharp
// WRONG — will eventually leak
const string Url = "http://my-iptv-provider.com:8080";
const string User = "myuser";

// CORRECT
var source = TestSourceProvider.XtreamSource();
```

### TestSourceProvider

```csharp
// Check if local credentials are available
if (TestSourceProvider.HasLocalSources) { ... }

// Get source config (real creds if .local exists, fake defaults otherwise)
var xtream = TestSourceProvider.XtreamSource();
var jellyfin = TestSourceProvider.JellyfinSource();
```

### sources.local.json Format

Create this file at `tests/Crispy.Infrastructure.Tests/TestData/Sources/sources.local.json` (gitignored):

```json
{
  "xtream": {
    "name": "My IPTV",
    "url": "http://provider.example.com:8080",
    "username": "myuser",
    "password": "mypass"
  },
  "jellyfin": {
    "name": "Home Jellyfin",
    "url": "http://192.168.1.100:8096",
    "apiKey": "abc123"
  }
}
```

**NEVER commit `.local` files.** Verify `.gitignore` contains `*.local.*` or `sources.local.json` before any commit.

### FakeHttpHandler

For unit tests that need HTTP responses without real network calls.

**Note: NSubstitute and Moq are NOT available in `Crispy.Infrastructure.Tests`** — NuGet restore is broken and neither was added to this project. Use `FakeHttpHandler` for all HTTP stubbing.

```csharp
var handler = new FakeHttpHandler()
    .WithResponse("get.php?action=get_live_categories", categoriesJson, HttpStatusCode.OK)
    .WithResponse("get.php?action=get_live_streams", streamsJson, HttpStatusCode.OK);

var httpClient = new HttpClient(handler);
var parser = new XtreamParser(httpClient);
```

Builder pattern:
- `.WithResponse(urlContains, responseBody, statusCode)` — matches if URL contains the string
- Multiple calls chain — first matching rule wins
- Unmatched URLs return 404 by default

### Skipping Integration Tests Without Local Creds

```csharp
[Fact]
public async Task GetChannels_ReturnsChannels_WhenRealServerAvailable()
{
    Skip.IfNot(TestSourceProvider.HasLocalSources, "No local credentials — skipping integration test");

    var source = TestSourceProvider.XtreamSource();
    // ... test against real server
}
```

Uses `Xunit.Skip` from `xunit.extensions.ordering` or `xunit` — available in Infrastructure.Tests.

### Usage Pattern for Unit Tests

```csharp
[Trait("Category", "Unit")]
public class XtreamParserTests
{
    [Fact]
    public async Task ParseChannels_ReturnsAllChannels_WhenValidResponse()
    {
        var json = await File.ReadAllTextAsync(
            Path.Combine("TestData", "Sources", "xtream_streams.json"));
        var handler = new FakeHttpHandler()
            .WithResponse("get_live_streams", json, HttpStatusCode.OK);
        var parser = new XtreamParser(new HttpClient(handler));

        var channels = await parser.GetLiveChannelsAsync(TestSourceProvider.XtreamSource());

        channels.Should().NotBeEmpty();
    }
}
```

### Rules

- Unit tests use `FakeHttpHandler` — no real network
- Integration tests use `TestSourceProvider` with `.HasLocalSources` guard
- Never hardcode credentials as const strings or inline literals
- Always use `NullLogger<T>.Instance` — not a real logger
- No Moq or NSubstitute in Infrastructure.Tests — use FakeHttpHandler and hand-written fakes
