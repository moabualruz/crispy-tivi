using Crispy.Domain.Enums;

namespace Crispy.Infrastructure.Parsers.M3U;

/// <summary>
/// Resolves catchup/timeshift URL templates by substituting all 14 standard placeholders.
/// </summary>
public static class CatchupUrlResolver
{
    /// <summary>
    /// Resolves a catchup URL template for the given time window.
    /// </summary>
    /// <param name="template">URL template with optional placeholders.</param>
    /// <param name="type">Catchup type — controls how the URL is constructed.</param>
    /// <param name="start">Programme start time.</param>
    /// <param name="end">Programme end time.</param>
    /// <returns>Resolved catchup URL.</returns>
    public static string Resolve(string template, CatchupType type, DateTimeOffset start, DateTimeOffset end)
    {
        if (type == CatchupType.Append)
        {
            var sep = template.Contains('?') ? '&' : '?';
            return $"{template}{sep}utc={start.ToUnixTimeSeconds()}&lutc={start.ToUnixTimeSeconds()}";
        }

        return SubstitutePlaceholders(template, start, end);
    }

    private static string SubstitutePlaceholders(string template, DateTimeOffset start, DateTimeOffset end)
    {
        var duration = (long)(end - start).TotalSeconds;
        var startUnix = start.ToUnixTimeSeconds();
        var endUnix = end.ToUnixTimeSeconds();
        var startUtc = start.UtcDateTime;
        var endUtc = end.UtcDateTime;

        // Offset in hours (signed, e.g. "+1" or "-5")
        var offsetHours = (int)start.Offset.TotalHours;
        var offsetStr = offsetHours >= 0 ? $"+{offsetHours}" : offsetHours.ToString();

        return template
            .Replace("{start}", startUnix.ToString(), StringComparison.Ordinal)
            .Replace("{end}", endUnix.ToString(), StringComparison.Ordinal)
            .Replace("{duration}", duration.ToString(), StringComparison.Ordinal)
            .Replace("{utcstart}", startUtc.ToString("yyyyMMddHHmmss"), StringComparison.Ordinal)
            .Replace("{utcend}", endUtc.ToString("yyyyMMddHHmmss"), StringComparison.Ordinal)
            .Replace("{lutcstart}", startUnix.ToString(), StringComparison.Ordinal)
            .Replace("{lutcend}", endUnix.ToString(), StringComparison.Ordinal)
            .Replace("{Y}", startUtc.ToString("yyyy"), StringComparison.Ordinal)
            .Replace("{m}", startUtc.ToString("MM"), StringComparison.Ordinal)
            .Replace("{d}", startUtc.ToString("dd"), StringComparison.Ordinal)
            .Replace("{H}", startUtc.ToString("HH"), StringComparison.Ordinal)
            .Replace("{M}", startUtc.ToString("mm"), StringComparison.Ordinal)
            .Replace("{S}", startUtc.ToString("ss"), StringComparison.Ordinal)
            .Replace("{offset}", offsetStr, StringComparison.Ordinal);
    }
}
