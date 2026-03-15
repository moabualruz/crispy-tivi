namespace Crispy.Application.Player.Models;

/// <summary>
/// Multiview layout type for the saved layout feature (PLR-42).
/// </summary>
public enum LayoutType
{
    /// <summary>Picture-in-picture (1 main + 1 overlay).</summary>
    Pip = 0,

    /// <summary>2x2 quad view.</summary>
    Quad = 1,

    /// <summary>Configurable grid layout.</summary>
    Grid = 2,
}

/// <summary>
/// A saved multiview slot assignment layout (PLR-42).
/// </summary>
public class SavedLayout
{
    /// <summary>Unique identifier (GUID).</summary>
    public required string Id { get; set; }

    /// <summary>User-assigned name for the layout.</summary>
    public required string Name { get; set; }

    /// <summary>Grid type for this layout.</summary>
    public LayoutType Layout { get; set; }

    /// <summary>JSON array of slot-to-stream assignments.</summary>
    public required string StreamsJson { get; set; }

    /// <summary>UTC timestamp when this layout was created.</summary>
    public DateTimeOffset CreatedAt { get; set; }

    /// <summary>Profile this layout belongs to.</summary>
    public required string ProfileId { get; set; }
}
