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

    /// <summary>Number of items skipped during parsing (malformed, unsupported format, etc.).</summary>
    public int SkippedCount { get; init; }

    /// <summary>Error message if the parse failed entirely, otherwise null.</summary>
    public string? Error { get; init; }

    /// <summary>Returns true when the parse completed without a fatal error.</summary>
    public bool IsSuccess => Error is null;
}
