namespace Crispy.Domain.Interfaces;

/// <summary>
/// Common projection interface for any item that can appear in search results or content lists.
/// </summary>
public interface IContentItem
{
    /// <summary>Primary key.</summary>
    int Id { get; }

    /// <summary>Display title.</summary>
    string Title { get; }

    /// <summary>Thumbnail / poster URL, if available.</summary>
    string? Thumbnail { get; }

    /// <summary>Source the item originated from.</summary>
    int SourceId { get; }
}
