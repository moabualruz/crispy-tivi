namespace Crispy.Domain.Entities;

/// <summary>
/// A single EPG programme entry (XMLTV &lt;programme&gt; element).
/// Stored in the dedicated epg.db to keep the main database lean.
/// </summary>
public class EpgProgramme : BaseEntity
{
    /// <summary>The tvg-id / channel attribute linking this programme to a channel.</summary>
    public required string ChannelId { get; set; }

    /// <summary>Programme start time in UTC.</summary>
    public DateTime StartUtc { get; set; }

    /// <summary>Programme stop time in UTC.</summary>
    public DateTime StopUtc { get; set; }

    /// <summary>Primary programme title.</summary>
    public required string Title { get; set; }

    /// <summary>Episode sub-title, if present.</summary>
    public string? SubTitle { get; set; }

    /// <summary>Programme description / synopsis.</summary>
    public string? Description { get; set; }

    /// <summary>JSON-serialised credits (director, actors, etc.).</summary>
    public string? Credits { get; set; }

    /// <summary>Episode number in XMLTV NS format (e.g. "0.5.0/1").</summary>
    public string? EpisodeNumXmltvNs { get; set; }

    /// <summary>Human-readable episode number (e.g. "S01E06").</summary>
    public string? EpisodeNumOnScreen { get; set; }

    /// <summary>Content rating (e.g. "PG", "TV-14").</summary>
    public string? Rating { get; set; }

    /// <summary>Star rating value as a free-form string (e.g. "3/5").</summary>
    public string? StarRating { get; set; }

    /// <summary>URL of the programme icon/poster.</summary>
    public string? IconUrl { get; set; }

    /// <summary>True when the broadcast is a repeat of a previously aired programme.</summary>
    public bool PreviouslyShown { get; set; }

    /// <summary>JSON-serialised map of language code → translated title.</summary>
    public string? MultiLangTitles { get; set; }
}
