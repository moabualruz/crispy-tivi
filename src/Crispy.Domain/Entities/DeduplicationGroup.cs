namespace Crispy.Domain.Entities;

/// <summary>
/// Groups duplicate channels from different sources that represent the same real-world channel.
/// The channel with the highest-priority source becomes the canonical display channel.
/// </summary>
public class DeduplicationGroup : BaseEntity
{
    /// <summary>Canonical title for the group (derived from the highest-priority member).</summary>
    public required string CanonicalTitle { get; set; }

    /// <summary>Canonical EPG tvg-id used to fetch EPG data for all members.</summary>
    public string? CanonicalTvgId { get; set; }

    /// <summary>Channels that belong to this deduplication group.</summary>
    public ICollection<Channel> Channels { get; set; } = [];
}
