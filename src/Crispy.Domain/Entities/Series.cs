using Crispy.Domain.Interfaces;

namespace Crispy.Domain.Entities;

/// <summary>
/// TV series (show) container — the parent of seasons and episodes.
/// </summary>
public class Series : BaseEntity, IContentItem
{
    /// <summary>Display title of the series.</summary>
    public required string Title { get; set; }

    /// <summary>Poster image URL.</summary>
    public string? Thumbnail { get; set; }

    /// <summary>Source that provided this series.</summary>
    public required int SourceId { get; set; }

    /// <summary>Navigation property to the source.</summary>
    public Source? Source { get; set; }

    /// <summary>TMDB identifier for the series.</summary>
    public int? TmdbId { get; set; }

    /// <summary>Brief synopsis.</summary>
    public string? Overview { get; set; }

    /// <summary>Year the series first aired.</summary>
    public int? FirstAiredYear { get; set; }

    /// <summary>Comma-separated genre names.</summary>
    public string? Genres { get; set; }

    /// <summary>Average audience rating.</summary>
    public double? Rating { get; set; }

    /// <summary>Backdrop / banner image URL.</summary>
    public string? BackdropUrl { get; set; }

    /// <summary>Episodes belonging to this series.</summary>
    public ICollection<Episode> Episodes { get; set; } = [];
}
