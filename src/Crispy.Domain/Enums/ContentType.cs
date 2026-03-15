namespace Crispy.Domain.Enums;

/// <summary>
/// Discriminates between the different types of playable content.
/// </summary>
public enum ContentType
{
    /// <summary>Live or recorded TV channel.</summary>
    Channel = 0,

    /// <summary>VOD movie.</summary>
    Movie = 1,

    /// <summary>TV series (parent container).</summary>
    Series = 2,

    /// <summary>Individual episode of a series.</summary>
    Episode = 3,
}
