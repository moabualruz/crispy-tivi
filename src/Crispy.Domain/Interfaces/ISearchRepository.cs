using Crispy.Domain.Enums;

namespace Crispy.Domain.Interfaces;

/// <summary>
/// Repository contract for FTS5-backed full-text search over content.
/// </summary>
public interface ISearchRepository
{
    /// <summary>
    /// Executes a full-text search and returns ranked results.
    /// Each result is a (ContentType, ContentId, Rank) tuple.
    /// </summary>
    Task<IReadOnlyList<(ContentType ContentType, int ContentId, double Rank)>> SearchAsync(
        string query,
        int limit = 50,
        CancellationToken ct = default);

    /// <summary>Returns title prefix matches for autocomplete (max 10 suggestions).</summary>
    Task<IReadOnlyList<string>> AutocompleteAsync(string prefix, int limit = 10, CancellationToken ct = default);

    /// <summary>Indexes or re-indexes a single content item in the FTS5 table.</summary>
    Task IndexAsync(int contentId, ContentType contentType, int sourceId, string title, string? description, string? groupName, CancellationToken ct = default);
}
