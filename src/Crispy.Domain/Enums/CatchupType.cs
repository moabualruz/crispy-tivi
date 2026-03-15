namespace Crispy.Domain.Enums;

/// <summary>
/// Defines the catchup/timeshift playback mode for a channel.
/// </summary>
public enum CatchupType
{
    /// <summary>No catchup support.</summary>
    None = 0,

    /// <summary>Standard catchup using the default provider mechanism.</summary>
    Default = 1,

    /// <summary>Append-style catchup URL construction.</summary>
    Append = 2,

    /// <summary>Timeshift-style catchup with shift parameter.</summary>
    Shift = 3,

    /// <summary>Flussonic-style catchup.</summary>
    Flussonic = 4,

    /// <summary>Xtream Codes catchup.</summary>
    Xc = 5,
}
