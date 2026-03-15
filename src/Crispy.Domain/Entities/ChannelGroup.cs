namespace Crispy.Domain.Entities;

/// <summary>
/// User-defined or auto-imported group of channels (e.g. "Sports", "News").
/// </summary>
public class ChannelGroup : BaseEntity
{
    /// <summary>Display name of the group.</summary>
    public required string Name { get; set; }

    /// <summary>Source that defined this group, or null for user-created groups.</summary>
    public int? SourceId { get; set; }

    /// <summary>User-defined sort position.</summary>
    public int SortOrder { get; set; }

    /// <summary>Channel memberships in this group.</summary>
    public ICollection<ChannelGroupMembership> Memberships { get; set; } = [];
}
