using Crispy.Domain.Enums;

namespace Crispy.Application.Player.Models;

/// <summary>
/// A named playback bookmark for a content item (PLR-41).
/// </summary>
public class Bookmark
{
    /// <summary>Unique identifier (GUID).</summary>
    public required string Id { get; set; }

    /// <summary>The channel or VOD item this bookmark is for.</summary>
    public required string ContentId { get; set; }

    /// <summary>Discriminates between live and VOD content.</summary>
    public ContentType ContentType { get; set; }

    /// <summary>Playback position in milliseconds.</summary>
    public long PositionMs { get; set; }

    /// <summary>User-assigned label for this bookmark.</summary>
    public required string Label { get; set; }

    /// <summary>UTC timestamp when this bookmark was created.</summary>
    public DateTimeOffset CreatedAt { get; set; }

    /// <summary>Profile this bookmark belongs to.</summary>
    public required string ProfileId { get; set; }
}
