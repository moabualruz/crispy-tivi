using Crispy.Domain.Enums;
using Crispy.Infrastructure.Data.Repositories;
using Crispy.Infrastructure.Tests.Helpers;

using FluentAssertions;

using Microsoft.Data.Sqlite;

using Xunit;

namespace Crispy.Infrastructure.Tests.Data.Repositories;

/// <summary>
/// Tests for SearchRepository.
/// SearchAsync and AutocompleteAsync depend on an FTS5 virtual table (ContentSearch)
/// that is created by a manual migration SQL — not by EnsureCreated(). Those code paths
/// that execute raw FTS5 SQL are covered by the early-return guard tests (null/whitespace
/// input) which never touch the database. The IndexAsync method is verified using a
/// dedicated fixture that creates the FTS5 table in-process before the test runs.
/// </summary>
[Trait("Category", "Integration")]
public sealed class SearchRepositoryTests : IDisposable
{
    private readonly TestDbContextFactory _factory = new();
    private readonly SearchRepository _sut;

    public SearchRepositoryTests()
    {
        _sut = new SearchRepository(_factory);
    }

    public void Dispose() => _factory.Dispose();

    // ── SearchAsync — early-return guards (no DB hit) ────────────────────────

    [Fact]
    public async Task SearchAsync_ReturnsEmpty_WhenQueryIsNull()
    {
        var result = await _sut.SearchAsync(null!);

        result.Should().BeEmpty();
    }

    [Fact]
    public async Task SearchAsync_ReturnsEmpty_WhenQueryIsWhitespace()
    {
        var result = await _sut.SearchAsync("   ");

        result.Should().BeEmpty();
    }

    [Fact]
    public async Task SearchAsync_ReturnsEmpty_WhenQueryIsEmpty()
    {
        var result = await _sut.SearchAsync(string.Empty);

        result.Should().BeEmpty();
    }

    [Theory]
    [InlineData("\"")]
    [InlineData("(")]
    [InlineData("-")]
    [InlineData("AND")]
    [InlineData("OR")]
    [InlineData("NOT")]
    public async Task SearchAsync_ReturnsEmpty_WhenQueryContainsOnlyFtsSpecialChars(string badQuery)
    {
        // FtsSearchService.SanitizeFtsQuery strips special chars — if nothing remains,
        // SearchRepository returns [] before touching the DB.
        var result = await _sut.SearchAsync(badQuery);

        result.Should().BeEmpty();
    }

    // ── AutocompleteAsync — early-return guards (no DB hit) ──────────────────

    [Fact]
    public async Task AutocompleteAsync_ReturnsEmpty_WhenPrefixIsNull()
    {
        var result = await _sut.AutocompleteAsync(null!);

        result.Should().BeEmpty();
    }

    [Fact]
    public async Task AutocompleteAsync_ReturnsEmpty_WhenPrefixIsWhitespace()
    {
        var result = await _sut.AutocompleteAsync("   ");

        result.Should().BeEmpty();
    }

    [Fact]
    public async Task AutocompleteAsync_ReturnsEmpty_WhenPrefixIsEmpty()
    {
        var result = await _sut.AutocompleteAsync(string.Empty);

        result.Should().BeEmpty();
    }

    // ── IndexAsync — requires FTS5 virtual table ─────────────────────────────

    [Fact]
    public async Task IndexAsync_DoesNotThrow_WhenFts5TableExists()
    {
        // Create the FTS5 virtual table via raw SqliteConnection (EF Relational not available)
        await using var ctx = await _factory.CreateDbContextAsync();
        var conn = _factory.Connection;
        await using var createCmd = conn.CreateCommand();
        createCmd.CommandText =
            "CREATE VIRTUAL TABLE IF NOT EXISTS ContentSearch USING fts5(" +
            "content_id UNINDEXED, content_type UNINDEXED, source_id UNINDEXED, " +
            "title, description, group_name)";
        await createCmd.ExecuteNonQueryAsync();

        var act = async () => await _sut.IndexAsync(
            contentId: 1,
            contentType: ContentType.Channel,
            sourceId: 1,
            title: "BBC One",
            description: "UK public broadcaster",
            groupName: "UK");

        await act.Should().NotThrowAsync();
    }

    [Fact]
    public async Task IndexAsync_InsertsRow_ThatCanBeReadBack()
    {
        var conn = _factory.Connection;
        await using var createCmd = conn.CreateCommand();
        createCmd.CommandText =
            "CREATE VIRTUAL TABLE IF NOT EXISTS ContentSearch USING fts5(" +
            "content_id UNINDEXED, content_type UNINDEXED, source_id UNINDEXED, " +
            "title, description, group_name)";
        await createCmd.ExecuteNonQueryAsync();

        await _sut.IndexAsync(
            contentId: 42,
            contentType: ContentType.Movie,
            sourceId: 7,
            title: "Inception",
            description: "Dream heist",
            groupName: null);

        // Verify row exists via raw query
        await using var readCmd = conn.CreateCommand();
        readCmd.CommandText = "SELECT content_id FROM ContentSearch WHERE title MATCH 'Inception'";
        var raw = await readCmd.ExecuteScalarAsync();

        raw.Should().NotBeNull();
        Convert.ToInt32(raw).Should().Be(42);
    }
}
