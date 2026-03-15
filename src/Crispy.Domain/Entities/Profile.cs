namespace Crispy.Domain.Entities;

/// <summary>
/// User profile supporting multi-profile per device.
/// </summary>
public class Profile : BaseEntity
{
    /// <summary>
    /// Display name for the profile.
    /// </summary>
    public required string Name { get; set; }

    /// <summary>
    /// Index into the avatar gallery.
    /// </summary>
    public int AvatarIndex { get; set; }

    /// <summary>
    /// Optional PIN hash for profile lock.
    /// </summary>
    public string? PinHash { get; set; }

    /// <summary>
    /// Whether this profile restricts content to kids-safe items.
    /// </summary>
    public bool IsKids { get; set; }

    /// <summary>
    /// Index into the accent color palette.
    /// </summary>
    public int AccentColorIndex { get; set; }

    /// <summary>
    /// Settings associated with this profile.
    /// </summary>
    public ICollection<Setting> Settings { get; set; } = [];

    /// <summary>
    /// Sources created by this profile.
    /// </summary>
    public ICollection<Source> Sources { get; set; } = [];
}
