using Crispy.Domain.Entities;
using Crispy.Domain.Enums;

namespace Crispy.Infrastructure.Tests.TestData;

/// <summary>
/// Loads fake source JSON/text files from TestData/Sources/.
/// Files named *.local.* take precedence over the committed defaults —
/// this lets developers override test data locally without affecting CI.
/// </summary>
public static class TestSourceProvider
{
    private static readonly string BasePath =
        Path.Combine(AppContext.BaseDirectory, "TestData", "Sources");

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

    /// <summary>A valid Xtream Codes source pointing at a fake base URL.</summary>
    public static Source XtreamSource() => new()
    {
        Name = "Test Xtream",
        Url = "http://fake-xtream.test",
        SourceType = SourceType.XtreamCodes,
        Username = "testuser",
        Password = "testpass",
    };

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

    /// <summary>A valid Jellyfin source with plaintext credentials.</summary>
    public static Source JellyfinSource() => new()
    {
        Name = "Test Jellyfin",
        Url = "http://jellyfin.test",
        SourceType = SourceType.Jellyfin,
        Username = "admin",
        Password = "password",
    };

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
