using Crispy.Domain.Enums;
using Crispy.Domain.Interfaces;
using Crispy.Infrastructure.Search;

using Microsoft.EntityFrameworkCore;

namespace Crispy.Infrastructure.Data.Repositories;

/// <summary>
/// FTS5-backed implementation of ISearchRepository.
/// Delegates full-text queries to the ContentSearch virtual table.
/// </summary>
public sealed class SearchRepository : ISearchRepository
{
    private readonly IDbContextFactory<Data.AppDbContext> _factory;

    /// <summary>Creates a new SearchRepository.</summary>
    public SearchRepository(IDbContextFactory<Data.AppDbContext> factory)
    {
        _factory = factory;
    }

    /// <inheritdoc/>
    public async Task<IReadOnlyList<(ContentType ContentType, int ContentId, double Rank)>> SearchAsync(
        string query,
        int limit = 50,
        CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(query))
            return [];

        var sanitized = FtsSearchService.SanitizeFtsQueryPublic(query);
        if (string.IsNullOrEmpty(sanitized))
            return [];

        await using var ctx = await _factory.CreateDbContextAsync(ct).ConfigureAwait(false);

        var rows = await ctx.Database
            .SqlQueryRaw<FtsRawRow>(
                "SELECT content_id AS ContentId, content_type AS ContentType, source_id AS SourceId, rank AS Rank FROM ContentSearch WHERE ContentSearch MATCH {0} ORDER BY rank LIMIT {1}",
                sanitized, limit)
            .ToListAsync(ct)
            .ConfigureAwait(false);

        return rows.Select(r => (
            ContentType: Enum.TryParse<ContentType>(r.ContentType, out var ct2) ? ct2 : ContentType.Channel,
            r.ContentId,
            r.Rank))
            .ToList();
    }

    /// <inheritdoc/>
    public async Task<IReadOnlyList<string>> AutocompleteAsync(
        string prefix,
        int limit = 10,
        CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(prefix))
            return [];

        var sanitized = FtsSearchService.SanitizeFtsQueryPublic(prefix);
        if (string.IsNullOrEmpty(sanitized))
            return [];

        await using var ctx = await _factory.CreateDbContextAsync(ct).ConfigureAwait(false);

        var rows = await ctx.Database
            .SqlQueryRaw<FtsRawRow>(
                "SELECT content_id AS ContentId, content_type AS ContentType, source_id AS SourceId, rank AS Rank FROM ContentSearch WHERE ContentSearch MATCH {0} ORDER BY rank LIMIT {1}",
                sanitized, limit)
            .ToListAsync(ct)
            .ConfigureAwait(false);

        // Return titles by content type
        var suggestions = new List<string>();
        var channelIds = rows.Where(r => r.ContentType == "Channel").Select(r => r.ContentId).ToList();
        if (channelIds.Count > 0)
        {
            var titles = await ctx.Channels
                .Where(c => channelIds.Contains(c.Id))
                .Select(c => c.Title)
                .ToListAsync(ct)
                .ConfigureAwait(false);
            suggestions.AddRange(titles);
        }

        return suggestions.Take(limit).ToList();
    }

    /// <inheritdoc/>
    public async Task IndexAsync(
        int contentId,
        ContentType contentType,
        int sourceId,
        string title,
        string? description,
        string? groupName,
        CancellationToken ct = default)
    {
        await using var ctx = await _factory.CreateDbContextAsync(ct).ConfigureAwait(false);
        await ctx.Database.ExecuteSqlRawAsync(
            "INSERT INTO ContentSearch(content_id, content_type, source_id, title, description, group_name) VALUES ({0}, {1}, {2}, {3}, {4}, {5})",
            contentId, contentType.ToString(), sourceId, title, description ?? string.Empty, groupName ?? string.Empty)
            .ConfigureAwait(false);
    }
}
