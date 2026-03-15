namespace Crispy.Application.Search;

/// <summary>
/// Search result returned from a full-text search query.
/// </summary>
public sealed class SearchResults
{
    /// <summary>Matched channels.</summary>
    public IReadOnlyList<SearchResultItem> Channels { get; init; } = [];

    /// <summary>Matched movies.</summary>
    public IReadOnlyList<SearchResultItem> Movies { get; init; } = [];

    /// <summary>Matched series.</summary>
    public IReadOnlyList<SearchResultItem> Series { get; init; } = [];

    /// <summary>Total number of results across all content types.</summary>
    public int TotalCount => Channels.Count + Movies.Count + Series.Count;
}

/// <summary>
/// A single item in a search result set.
/// </summary>
public sealed class SearchResultItem
{
    /// <summary>Primary key of the content item.</summary>
    public required int ContentId { get; init; }

    /// <summary>Display title.</summary>
    public required string Title { get; init; }

    /// <summary>Thumbnail / poster URL.</summary>
    public string? Thumbnail { get; init; }

    /// <summary>FTS5 relevance rank (higher magnitude = more relevant).</summary>
    public double Rank { get; init; }
}

/// <summary>
/// Application-layer search service backed by the FTS5 index.
/// </summary>
public interface ISearchService
{
    /// <summary>
    /// Performs a full-text search and returns ranked results grouped by content type.
    /// </summary>
    Task<SearchResults> SearchAsync(string query, int profileId, CancellationToken ct = default);

    /// <summary>Returns title prefix completions for autocomplete UI.</summary>
    Task<IReadOnlyList<string>> AutocompleteAsync(string prefix, CancellationToken ct = default);
}
