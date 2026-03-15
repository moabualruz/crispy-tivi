namespace Crispy.UI.Navigation;

/// <summary>
/// Result of parsing a crispy:// deep link URI.
/// </summary>
public sealed record DeepLinkResult(
    string Screen,
    string? Id,
    Dictionary<string, string>? Query);

/// <summary>
/// Parses crispy:// URI scheme into navigation targets.
/// </summary>
public static class DeepLinkParser
{
    private const string Scheme = "crispy";

    /// <summary>
    /// Parses a crispy:// URI into a DeepLinkResult.
    /// Returns null for invalid or non-crispy URIs.
    /// </summary>
    public static DeepLinkResult? Parse(string? uri)
    {
        if (string.IsNullOrWhiteSpace(uri))
        {
            return null;
        }

        if (!Uri.TryCreate(uri, UriKind.Absolute, out var parsed) || parsed.Scheme != Scheme)
        {
            return null;
        }

        // Uri treats first segment after :// as Host, rest as AbsolutePath.
        // Combine: crispy://live/channel/123 -> Host="live", Path="/channel/123"
        // We want segments: ["live", "channel", "123"]
        var allSegments = new List<string>();
        if (!string.IsNullOrEmpty(parsed.Host))
        {
            allSegments.Add(parsed.Host);
        }

        allSegments.AddRange(
            parsed.AbsolutePath.Split('/', StringSplitOptions.RemoveEmptyEntries));

        var query = ParseQuery(parsed.Query);

        if (allSegments.Count == 0)
        {
            return null;
        }

        // Route: live/channel/{id}
        if (allSegments.Count >= 2 && allSegments[0] == "live" && allSegments[1] == "channel")
        {
            var id = allSegments.Count > 2 ? allSegments[2] : null;
            return new DeepLinkResult("LiveTv", id, query);
        }

        // Route: vod/movie/{id}
        if (allSegments.Count >= 2 && allSegments[0] == "vod" && allSegments[1] == "movie")
        {
            var id = allSegments.Count > 2 ? allSegments[2] : null;
            return new DeepLinkResult("Movies", id, query);
        }

        // Route: vod/series/{id}
        if (allSegments.Count >= 2 && allSegments[0] == "vod" && allSegments[1] == "series")
        {
            var id = allSegments.Count > 2 ? allSegments[2] : null;
            return new DeepLinkResult("Series", id, query);
        }

        // Route: search?q={query}
        if (allSegments[0] == "search")
        {
            return new DeepLinkResult("Search", null, query);
        }

        // Route: settings or settings/{category}
        if (allSegments[0] == "settings")
        {
            var id = allSegments.Count > 1 ? allSegments[1] : null;
            return new DeepLinkResult("Settings", id, query);
        }

        // Route: home
        if (allSegments[0] == "home")
        {
            return new DeepLinkResult("Home", null, query);
        }

        return null;
    }

    private static Dictionary<string, string>? ParseQuery(string queryString)
    {
        if (string.IsNullOrEmpty(queryString))
        {
            return null;
        }

        var query = queryString.TrimStart('?');
        if (string.IsNullOrEmpty(query))
        {
            return null;
        }

        var result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var pair in query.Split('&', StringSplitOptions.RemoveEmptyEntries))
        {
            var parts = pair.Split('=', 2);
            var key = Uri.UnescapeDataString(parts[0]);
            var value = parts.Length > 1 ? Uri.UnescapeDataString(parts[1]) : string.Empty;
            result[key] = value;
        }

        return result.Count > 0 ? result : null;
    }
}
