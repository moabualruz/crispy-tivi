using Crispy.Domain.Entities;
using Crispy.Domain.Enums;
using Crispy.Infrastructure.Data;
using Crispy.Infrastructure.Search;
using Crispy.Infrastructure.Tests.Helpers;

using FluentAssertions;

using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Search;

/// <summary>
/// Tests for FtsSearchService using a real SQLite in-memory database with FTS5 support.
/// Verifies search results and FTS5 delete-trigger behaviour.
/// </summary>
public class FtsSearchServiceTests : IAsyncLifetime
{
    private SqliteConnection _connection = null!;
    private DbContextOptions<AppDbContext> _options = null!;

    public async Task InitializeAsync()
    {
        _connection = new SqliteConnection("Data Source=:memory:");
        await _connection.OpenAsync();

        // Disable FK enforcement so our test inserts don't fail on FK constraints
        // (we test business logic, not DB schema enforcement)
        using (var cmd = _connection.CreateCommand())
        {
            cmd.CommandText = "PRAGMA foreign_keys = OFF";
            await cmd.ExecuteNonQueryAsync();
        }

        _options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(_connection)
            .Options;

        await using var ctx = new AppDbContext(_options);
        await ctx.Database.EnsureCreatedAsync();

        // FTS5 virtual table and triggers — use raw ADO.NET to avoid EF transaction wrapping DDL
        // Use raw SqliteCommand to create triggers (ExecuteSqlRawAsync wraps in a transaction
        // that can conflict with DDL). Raw ADO.NET avoids that issue.
        using (var cmd = _connection.CreateCommand())
        {
            cmd.CommandText = """
                CREATE VIRTUAL TABLE IF NOT EXISTS ContentSearch USING fts5(
                    content_id UNINDEXED,
                    content_type UNINDEXED,
                    source_id UNINDEXED,
                    title,
                    description,
                    group_name,
                    tokenize = 'unicode61 remove_diacritics 1'
                )
                """;
            await cmd.ExecuteNonQueryAsync();
        }

        using (var cmd = _connection.CreateCommand())
        {
            cmd.CommandText = """
                CREATE TABLE IF NOT EXISTS SearchHistory (
                    Id INTEGER PRIMARY KEY AUTOINCREMENT,
                    ProfileId INTEGER NOT NULL,
                    Query TEXT NOT NULL,
                    SearchedAt TEXT NOT NULL
                )
                """;
            await cmd.ExecuteNonQueryAsync();
        }

        // FTS5 insert trigger: store rowid=NEW.Id so the delete trigger can find rows
        using (var cmd = _connection.CreateCommand())
        {
            cmd.CommandText = """
                CREATE TRIGGER IF NOT EXISTS channel_ai
                AFTER INSERT ON Channels
                BEGIN
                    INSERT INTO ContentSearch(rowid, content_id, content_type, source_id, title, description, group_name)
                    VALUES (NEW.Id, NEW.Id, 'Channel', NEW.SourceId, NEW.Title, NULL, NEW.GroupName);
                END
                """;
            await cmd.ExecuteNonQueryAsync();
        }

        // FTS5 delete: direct DELETE FROM the FTS5 table by rowid (the correct approach
        // for standalone FTS5 tables — INSERT('delete') syntax is only for content tables)
        using (var cmd = _connection.CreateCommand())
        {
            cmd.CommandText = """
                CREATE TRIGGER IF NOT EXISTS channel_ad
                AFTER DELETE ON Channels
                BEGIN
                    DELETE FROM ContentSearch WHERE rowid = OLD.Id;
                END
                """;
            await cmd.ExecuteNonQueryAsync();
        }

        using (var cmd = _connection.CreateCommand())
        {
            cmd.CommandText = """
                CREATE TRIGGER IF NOT EXISTS channel_au
                AFTER UPDATE ON Channels
                BEGIN
                    DELETE FROM ContentSearch WHERE rowid = OLD.Id;
                    INSERT INTO ContentSearch(rowid, content_id, content_type, source_id, title, description, group_name)
                    VALUES (NEW.Id, NEW.Id, 'Channel', NEW.SourceId, NEW.Title, NULL, NEW.GroupName);
                END
                """;
            await cmd.ExecuteNonQueryAsync();
        }

    }

    public async Task DisposeAsync()
    {
        await _connection.DisposeAsync();
    }

    private AppDbContext NewContext() => new(_options);

    private FtsSearchService NewSut()
    {
        var appFactory = new SingleConnectionDbContextFactory<AppDbContext>(_options);
        var epgFactory = new TestEpgDbContextFactory();
        return new FtsSearchService(appFactory, epgFactory, NullLogger<FtsSearchService>.Instance);
    }

    // ─── Search ───────────────────────────────────────────────────────────────

    [Fact]
    public async Task SearchAsync_ReturnsChannelMatchingQuery()
    {
        await using var ctx = NewContext();

        var source = new Source { Name = "S1", Url = "http://s1.com", SourceType = SourceType.M3U };
        ctx.Sources.Add(source);
        await ctx.SaveChangesAsync();

        ctx.Channels.Add(new Channel { Title = "Sports HD", SourceId = source.Id, TvgId = "sport-hd", GroupName = "Sports" });
        ctx.Channels.Add(new Channel { Title = "News 24", SourceId = source.Id, TvgId = "news-24", GroupName = "News" });
        ctx.Channels.Add(new Channel { Title = "Comedy Central", SourceId = source.Id, TvgId = "comedy-1", GroupName = "Entertainment" });
        await ctx.SaveChangesAsync();

        var sut = NewSut();
        var results = await sut.SearchAsync("sport", profileId: 1, CancellationToken.None);

        results.Channels.Should().HaveCount(1);
        results.Channels[0].Title.Should().Be("Sports HD");
    }

    [Fact]
    public async Task SearchAsync_DeleteTrigger_RemovesChannelFromIndex()
    {
        await using var ctx = NewContext();

        var source = new Source { Name = "S2", Url = "http://s2.com", SourceType = SourceType.M3U };
        ctx.Sources.Add(source);
        await ctx.SaveChangesAsync();

        var channel = new Channel { Title = "Football Live", SourceId = source.Id, TvgId = "football-live", GroupName = "Sports" };
        ctx.Channels.Add(channel);
        await ctx.SaveChangesAsync();

        var sut = NewSut();

        // Verify it's searchable before deletion
        var before = await sut.SearchAsync("football", profileId: 1, CancellationToken.None);
        before.Channels.Should().HaveCount(1);

        // Delete via the shared raw connection so the FTS5 trigger sees the same in-memory DB
        using (var cmd = _connection.CreateCommand())
        {
            cmd.CommandText = "DELETE FROM Channels WHERE Id = @id";
            var p = cmd.CreateParameter();
            p.ParameterName = "@id";
            p.Value = channel.Id;
            cmd.Parameters.Add(p);
            await cmd.ExecuteNonQueryAsync();
        }

        // Should no longer appear in search results
        var after = await sut.SearchAsync("football", profileId: 1, CancellationToken.None);
        after.Channels.Should().BeEmpty("the FTS5 delete trigger should have removed the channel from the index");
    }

    // ─── Autocomplete ─────────────────────────────────────────────────────────

    [Fact]
    public async Task AutocompleteAsync_ReturnsMaxEightResults()
    {
        await using var ctx = NewContext();

        var source = new Source { Name = "S3", Url = "http://s3.com", SourceType = SourceType.M3U };
        ctx.Sources.Add(source);
        await ctx.SaveChangesAsync();

        // Insert 10 channels all starting with "Sport"
        for (var i = 1; i <= 10; i++)
            ctx.Channels.Add(new Channel { Title = $"Sport Channel {i}", SourceId = source.Id, TvgId = $"sport-{i}" });
        await ctx.SaveChangesAsync();

        var sut = NewSut();
        var suggestions = await sut.AutocompleteAsync("sport", CancellationToken.None);

        suggestions.Count.Should().BeLessThanOrEqualTo(8, "autocomplete is capped at 8 results");
        suggestions.Should().AllSatisfy(s => s.Should().StartWith("Sport"));
    }
}

/// <summary>
/// DbContextFactory that always creates a context sharing a fixed connection.
/// Required for in-memory SQLite tests where the schema lives on the connection.
/// </summary>
internal sealed class SingleConnectionDbContextFactory<TContext> : IDbContextFactory<TContext>
    where TContext : DbContext
{
    private readonly DbContextOptions<TContext> _options;

    public SingleConnectionDbContextFactory(DbContextOptions<TContext> options) => _options = options;

    public TContext CreateDbContext() =>
        (TContext)Activator.CreateInstance(typeof(TContext), _options)!;
}
