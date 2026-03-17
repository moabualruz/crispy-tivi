using Crispy.Domain.Entities;

namespace Crispy.Application.Sources;

/// <summary>
/// Result of parsing a single content source.
/// </summary>
public sealed class ParseResult
{
    /// <summary>Live/linear channels parsed from the source.</summary>
    public IReadOnlyList<Channel> Channels { get; init; } = [];

    /// <summary>
    /// Stream endpoints for the parsed channels.
    /// Indexed in the same order as <see cref="Channels"/> — one endpoint per channel.
    /// ChannelId is set to 0 here; the sync pipeline resolves real IDs after upsert.
    /// </summary>
    public IReadOnlyList<StreamEndpoint> StreamEndpoints { get; init; } = [];

    /// <summary>VOD movies parsed from the source.</summary>
    public IReadOnlyList<Movie> Movies { get; init; } = [];

    /// <summary>TV series parsed from the source.</summary>
    public IReadOnlyList<Series> Series { get; init; } = [];

    /// <summary>Episodes parsed from the source (e.g. Jellyfin). SeriesId is a placeholder until resolved by SyncPipeline.</summary>
    public IReadOnlyList<Episode> Episodes { get; init; } = [];

    /// <summary>
    /// Maps each episode (by index in <see cref="Episodes"/>) to its parent series title.
    /// Used by SyncPipeline to resolve real SeriesId after series upsert.
    /// </summary>
    public IReadOnlyDictionary<int, string> EpisodeSeriesNames { get; init; } =
        new Dictionary<int, string>();

    /// <summary>Number of items skipped during parsing (malformed, unsupported format, etc.).</summary>
    public int SkippedCount { get; init; }

    /// <summary>Error message if the parse failed entirely, otherwise null.</summary>
    public string? Error { get; init; }

    /// <summary>Returns true when the parse completed without a fatal error.</summary>
    public bool IsSuccess => Error is null;
}
