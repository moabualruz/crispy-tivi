using System.Text.Json;

using Crispy.Domain.Entities;
using Crispy.Domain.Enums;

namespace Crispy.Infrastructure.Tests.TestData;

/// <summary>
/// Loads fake source JSON/text files from TestData/Sources/.
/// Files named *.local.* take precedence over the committed defaults —
/// this lets developers override test data locally without affecting CI.
///
/// For real integration tests, place a sources.local.json in TestData/Sources/
/// with real credentials. The Source factory methods will use those instead of fakes.
/// </summary>
public static class TestSourceProvider
{
    private static readonly string BasePath =
        Path.Combine(AppContext.BaseDirectory, "TestData", "Sources");

    private static readonly Lazy<JsonElement?> LocalSources = new(() =>
    {
        var path = Path.Combine(BasePath, "sources.local.json");
        if (!File.Exists(path)) return null;
        var json = File.ReadAllText(path);
        return JsonDocument.Parse(json).RootElement;
    });

    /// <summary>True when sources.local.json is present — enables integration tests.</summary>
    public static bool HasLocalSources => LocalSources.Value.HasValue;

    /// <summary>Reads the text of a test data file, preferring a *.local.* variant if present.</summary>
    public static string LoadText(string fileName)
    {
        // e.g. "xtream-auth.json" → look for "xtream-auth.local.json" first
        var ext = Path.GetExtension(fileName);
        var stem = Path.GetFileNameWithoutExtension(fileName);
        var localName = $"{stem}.local{ext}";

        var localPath = Path.Combine(BasePath, localName);
        if (File.Exists(localPath))
            return File.ReadAllText(localPath);

        var defaultPath = Path.Combine(BasePath, fileName);
        return File.ReadAllText(defaultPath);
    }

    // ─── Pre-built Source objects ─────────────────────────────────────────────
    // When sources.local.json exists, these return real credentials.
    // Otherwise they return fake data for unit tests.

    /// <summary>A valid Xtream Codes source. Uses real credentials from sources.local.json if present.</summary>
    public static Source XtreamSource()
    {
        if (LocalSources.Value is { } root && root.TryGetProperty("xtream", out var x))
            return new Source
            {
                Name = x.GetProperty("name").GetString() ?? "Local Xtream",
                Url = x.GetProperty("url").GetString() ?? "",
                SourceType = SourceType.XtreamCodes,
                Username = x.GetProperty("username").GetString(),
                Password = x.GetProperty("password").GetString(),
            };

        return new Source
        {
            Name = "Test Xtream",
            Url = "http://fake-xtream.test",
            SourceType = SourceType.XtreamCodes,
            Username = "testuser",
            Password = "testpass",
        };
    }

    /// <summary>An Xtream Codes source with no credentials.</summary>
    public static Source XtreamSourceNoCredentials() => new()
    {
        Name = "Test Xtream (no creds)",
        Url = "http://fake-xtream.test",
        SourceType = SourceType.XtreamCodes,
        Username = null,
        Password = null,
    };

    /// <summary>A valid Stalker Portal source.</summary>
    public static Source StalkerSource() => new()
    {
        Name = "Test Stalker",
        Url = "http://stalker.test",
        SourceType = SourceType.StalkerPortal,
    };

    /// <summary>A valid Jellyfin source. Uses real credentials from sources.local.json if present.</summary>
    public static Source JellyfinSource()
    {
        if (LocalSources.Value is { } root && root.TryGetProperty("jellyfin", out var j))
            return new Source
            {
                Name = j.GetProperty("name").GetString() ?? "Local Jellyfin",
                Url = j.GetProperty("url").GetString() ?? "",
                SourceType = SourceType.Jellyfin,
                Username = j.GetProperty("username").GetString(),
                Password = j.GetProperty("password").GetString(),
            };

        return new Source
        {
            Name = "Test Jellyfin",
            Url = "http://jellyfin.test",
            SourceType = SourceType.Jellyfin,
            Username = "admin",
            Password = "password",
        };
    }

    /// <summary>A Jellyfin source with no credentials.</summary>
    public static Source JellyfinSourceNoCredentials() => new()
    {
        Name = "Test Jellyfin (no creds)",
        Url = "http://jellyfin.test",
        SourceType = SourceType.Jellyfin,
        Username = null,
        Password = null,
    };
}
