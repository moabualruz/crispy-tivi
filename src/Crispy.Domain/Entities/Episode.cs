using Crispy.Domain.Interfaces;

namespace Crispy.Domain.Entities;

/// <summary>
/// A single episode belonging to a series.
/// </summary>
public class Episode : BaseEntity, IContentItem
{
    /// <summary>Display title (episode title or "S{s}E{e}" fallback).</summary>
    public required string Title { get; set; }

    /// <summary>Episode thumbnail / still image URL.</summary>
    public string? Thumbnail { get; set; }

    /// <summary>Source that provided this episode.</summary>
    public required int SourceId { get; set; }

    /// <summary>Navigation property to the source.</summary>
    public Source? Source { get; set; }

    /// <summary>FK to the parent series.</summary>
    public required int SeriesId { get; set; }

    /// <summary>Navigation property to the parent series.</summary>
    public Series? Series { get; set; }

    /// <summary>Season number (1-based).</summary>
    public int SeasonNumber { get; set; }

    /// <summary>Episode number within the season (1-based).</summary>
    public int EpisodeNumber { get; set; }

    /// <summary>Playable stream URL for this episode.</summary>
    public string? StreamUrl { get; set; }

    /// <summary>Runtime in minutes.</summary>
    public int? RuntimeMinutes { get; set; }

    /// <summary>Brief episode synopsis.</summary>
    public string? Overview { get; set; }

    /// <summary>Air date of the episode.</summary>
    public DateTime? AiredAt { get; set; }
}
