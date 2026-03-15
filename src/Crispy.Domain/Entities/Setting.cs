namespace Crispy.Domain.Entities;

/// <summary>
/// Key-value setting, optionally scoped to a profile.
/// </summary>
public class Setting : BaseEntity
{
    /// <summary>
    /// Setting key (e.g., "theme", "locale", "player.volume").
    /// </summary>
    public required string Key { get; set; }

    /// <summary>
    /// JSON-serialized setting value.
    /// </summary>
    public required string Value { get; set; }

    /// <summary>
    /// Optional profile scope. Null means global setting.
    /// </summary>
    public int? ProfileId { get; set; }

    /// <summary>
    /// Navigation property to the owning profile.
    /// </summary>
    public Profile? Profile { get; set; }
}
