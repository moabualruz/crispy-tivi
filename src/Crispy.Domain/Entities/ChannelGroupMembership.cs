namespace Crispy.Domain.Entities;

/// <summary>
/// Join table linking channels to channel groups with an optional sort position.
/// </summary>
public class ChannelGroupMembership : BaseEntity
{
    /// <summary>FK to the channel.</summary>
    public required int ChannelId { get; set; }

    /// <summary>Navigation property to the channel.</summary>
    public Channel? Channel { get; set; }

    /// <summary>FK to the channel group.</summary>
    public required int ChannelGroupId { get; set; }

    /// <summary>Navigation property to the channel group.</summary>
    public ChannelGroup? ChannelGroup { get; set; }

    /// <summary>Sort position of the channel within the group.</summary>
    public int SortOrder { get; set; }
}
