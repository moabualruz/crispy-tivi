using Crispy.Domain.Interfaces;

namespace Crispy.Domain.Entities;

/// <summary>
/// VOD movie item from an IPTV source or Jellyfin media server.
/// </summary>
public class Movie : BaseEntity, IContentItem
{
    /// <summary>Display title of the movie.</summary>
    public required string Title { get; set; }

    /// <summary>URL of the movie poster image.</summary>
    public string? Thumbnail { get; set; }

    /// <summary>Source that provided this movie.</summary>
    public required int SourceId { get; set; }

    /// <summary>Navigation property to the source.</summary>
    public Source? Source { get; set; }

    /// <summary>Playable stream URL.</summary>
    public string? StreamUrl { get; set; }

    /// <summary>The Movie Database (TMDB) identifier, used for deduplication and metadata.</summary>
    public int? TmdbId { get; set; }

    /// <summary>Brief synopsis / description.</summary>
    public string? Overview { get; set; }

    /// <summary>Release year.</summary>
    public int? Year { get; set; }

    /// <summary>Runtime in minutes.</summary>
    public int? RuntimeMinutes { get; set; }

    /// <summary>Comma-separated genre names.</summary>
    public string? Genres { get; set; }

    /// <summary>Average audience rating (e.g. 7.4).</summary>
    public double? Rating { get; set; }

    /// <summary>Backdrop / banner image URL.</summary>
    public string? BackdropUrl { get; set; }
}
