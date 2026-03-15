using Crispy.Domain.Enums;

namespace Crispy.Domain.Entities;

/// <summary>
/// Content source (IPTV playlist, Xtream Codes, Stalker Portal, or Jellyfin server).
/// </summary>
public class Source : BaseEntity
{
    /// <summary>
    /// Display name for this source.
    /// </summary>
    public required string Name { get; set; }

    /// <summary>
    /// URL to the source (M3U URL, Xtream API base, Stalker portal, or Jellyfin server).
    /// </summary>
    public required string Url { get; set; }

    /// <summary>
    /// Type of content source.
    /// </summary>
    public SourceType SourceType { get; set; }

    /// <summary>
    /// Optional username for authenticated sources.
    /// </summary>
    public string? Username { get; set; }

    /// <summary>
    /// Optional password for authenticated sources (plaintext — kept for migration compatibility).
    /// New code should read/write <see cref="EncryptedPassword"/> instead.
    /// </summary>
    public string? Password { get; set; }

    /// <summary>
    /// AES-256-GCM encrypted username (produced by ICredentialEncryption).
    /// </summary>
    public string? EncryptedUsername { get; set; }

    /// <summary>
    /// AES-256-GCM encrypted password (produced by ICredentialEncryption).
    /// </summary>
    public string? EncryptedPassword { get; set; }

    /// <summary>
    /// Profile that created this source.
    /// </summary>
    public int ProfileId { get; set; }

    /// <summary>
    /// Navigation property to the creator profile.
    /// </summary>
    public Profile? Profile { get; set; }

    /// <summary>
    /// Display order for sorting sources.
    /// </summary>
    public int SortOrder { get; set; }

    /// <summary>
    /// Whether this source is active and should be synced.
    /// </summary>
    public bool IsEnabled { get; set; } = true;
}
