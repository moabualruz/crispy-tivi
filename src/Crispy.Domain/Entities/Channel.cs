using Crispy.Domain.Enums;
using Crispy.Domain.Interfaces;

namespace Crispy.Domain.Entities;

/// <summary>
/// Live or time-shifted TV/radio channel from any IPTV source.
/// </summary>
public class Channel : BaseEntity, IContentItem
{
    /// <summary>Display name shown in channel lists.</summary>
    public required string Title { get; set; }

    /// <summary>EPG tvg-id used to match channel to EPG programme data.</summary>
    public string? TvgId { get; set; }

    /// <summary>tvg-name attribute from the M3U playlist.</summary>
    public string? TvgName { get; set; }

    /// <summary>URL of the channel logo image.</summary>
    public string? TvgLogo { get; set; }

    /// <summary>tvg-chno channel number from the playlist.</summary>
    public int? TvgChno { get; set; }

    /// <summary>Group tag from the M3U playlist (e.g. "Sports", "News").</summary>
    public string? GroupName { get; set; }

    /// <summary>Thumbnail alias backed by TvgLogo for IContentItem compatibility.</summary>
    public string? Thumbnail => TvgLogo;

    /// <summary>Source that provided this channel.</summary>
    public required int SourceId { get; set; }

    /// <summary>Navigation property to the providing source.</summary>
    public Source? Source { get; set; }

    /// <summary>Whether this channel is a radio station (audio-only).</summary>
    public bool IsRadio { get; set; }

    /// <summary>Catchup / timeshift mode supported by this channel.</summary>
    public CatchupType CatchupType { get; set; } = CatchupType.None;

    /// <summary>Catchup URL template (may contain {start}, {duration}, {utc} placeholders).</summary>
    public string? CatchupSource { get; set; }

    /// <summary>Number of days of catchup content available.</summary>
    public int CatchupDays { get; set; }

    /// <summary>
    /// How many consecutive syncs this channel was absent from the source feed.
    /// Used to trigger soft-removal after threshold is exceeded.
    /// </summary>
    public int MissedSyncCount { get; set; }

    /// <summary>Resolved channel number after deduplication across all sources.</summary>
    public int? UnifiedNumber { get; set; }

    /// <summary>User-assigned channel number (overrides UnifiedNumber in UI).</summary>
    public int? UserAssignedNumber { get; set; }

    /// <summary>Explicit sort order set by the user.</summary>
    public int? CustomSortOrder { get; set; }

    /// <summary>Whether the user has marked this channel as a favourite.</summary>
    public bool IsFavorite { get; set; }

    /// <summary>Whether the user has hidden this channel from lists.</summary>
    public bool IsHidden { get; set; }

    /// <summary>FK to the deduplication group this channel belongs to, if any.</summary>
    public int? DeduplicationGroupId { get; set; }

    /// <summary>Navigation property to the deduplication group.</summary>
    public DeduplicationGroup? DeduplicationGroup { get; set; }

    /// <summary>Stream endpoints associated with this channel (one per source after dedup).</summary>
    public ICollection<StreamEndpoint> StreamEndpoints { get; set; } = [];

    /// <summary>Group memberships for this channel.</summary>
    public ICollection<ChannelGroupMembership> GroupMemberships { get; set; } = [];
}
