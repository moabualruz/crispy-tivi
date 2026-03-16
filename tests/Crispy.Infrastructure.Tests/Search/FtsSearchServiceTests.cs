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

    // ─── SearchAsync early-exit branches ──────────────────────────────────────

    [Theory]
    [Trait("Category", "Unit")]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("\t")]
    public async Task SearchAsync_ReturnsEmptyResults_WhenQueryIsNullOrWhiteSpace(string query)
    {
        var sut = NewSut();
        var results = await sut.SearchAsync(query, profileId: 1, CancellationToken.None);

        results.Channels.Should().BeEmpty();
        results.Movies.Should().BeEmpty();
        results.Series.Should().BeEmpty();
    }

    [Fact]
    [Trait("Category", "Unit")]
    public async Task SearchAsync_ReturnsEmptyResults_WhenQueryContainsOnlyFtsSpecialChars()
    {
        // After sanitization, query becomes empty string → second early-exit branch
        var sut = NewSut();
        var results = await sut.SearchAsync("*()^-\"", profileId: 1, CancellationToken.None);

        results.Channels.Should().BeEmpty();
        results.Movies.Should().BeEmpty();
        results.Series.Should().BeEmpty();
    }

    [Fact]
    [Trait("Category", "Unit")]
    public async Task SearchAsync_ReturnsEmptyResults_WhenNoMatchesExist()
    {
        var sut = NewSut();
        var results = await sut.SearchAsync("xyzzy99999noresults", profileId: 1, CancellationToken.None);

        results.Channels.Should().BeEmpty();
        results.Movies.Should().BeEmpty();
        results.Series.Should().BeEmpty();
    }

    // ─── AutocompleteAsync early-exit branches ────────────────────────────────

    [Theory]
    [Trait("Category", "Unit")]
    [InlineData("")]
    [InlineData("   ")]
    public async Task AutocompleteAsync_ReturnsEmpty_WhenPrefixIsNullOrWhiteSpace(string prefix)
    {
        var sut = NewSut();
        var suggestions = await sut.AutocompleteAsync(prefix, CancellationToken.None);
        suggestions.Should().BeEmpty();
    }

    [Fact]
    [Trait("Category", "Unit")]
    public async Task AutocompleteAsync_ReturnsEmpty_WhenPrefixContainsOnlyFtsSpecialChars()
    {
        var sut = NewSut();
        var suggestions = await sut.AutocompleteAsync("*()^-", CancellationToken.None);
        suggestions.Should().BeEmpty();
    }

    [Fact]
    [Trait("Category", "Unit")]
    public async Task AutocompleteAsync_ReturnsEmpty_WhenNothingInIndex()
    {
        var sut = NewSut();
        var suggestions = await sut.AutocompleteAsync("xyzzy99999", CancellationToken.None);
        suggestions.Should().BeEmpty();
    }

    // ─── SanitizeFtsQueryPublic ───────────────────────────────────────────────

    [Fact]
    [Trait("Category", "Unit")]
    public void SanitizeFtsQueryPublic_StripsFtsSpecialChars_AndAppendsWildcard()
    {
        // The * in the input is a special char and gets stripped from the word,
        // but SanitizeFtsQuery appends * after the last quoted token as a prefix wildcard.
        var result = FtsSearchService.SanitizeFtsQueryPublic("hello*world");
        // Result should be a single quoted token ending with *
        result.Should().EndWith("*").And.StartWith("\"");
    }

    [Fact]
    [Trait("Category", "Unit")]
    public void SanitizeFtsQueryPublic_MultipleWords_WrapsEachInQuotes()
    {
        var result = FtsSearchService.SanitizeFtsQueryPublic("sports news");
        result.Should().Contain("\"sports\"").And.Contain("\"news\"*");
    }

    [Fact]
    [Trait("Category", "Unit")]
    public void SanitizeFtsQueryPublic_StripsBooleanOperators()
    {
        var result = FtsSearchService.SanitizeFtsQueryPublic("sport AND news OR weather NOT comedy");
        result.Should().NotContain("AND")
            .And.NotContain("OR")
            .And.NotContain("NOT");
    }

    [Fact]
    [Trait("Category", "Unit")]
    public void SanitizeFtsQueryPublic_ReturnsEmpty_WhenInputIsOnlySpecialChars()
    {
        var result = FtsSearchService.SanitizeFtsQueryPublic("*()^-\"");
        result.Should().BeEmpty();
    }

    // ─── Content-type routing (Movie / Series / Episode weights) ──────────────

    [Fact]
    [Trait("Category", "Integration")]
    public async Task SearchAsync_ReturnsMovieResult_WhenMovieIsIndexed()
    {
        await using var ctx = NewContext();

        var source = new Source { Name = "S4", Url = "http://s4.com", SourceType = SourceType.M3U };
        ctx.Sources.Add(source);
        await ctx.SaveChangesAsync();

        // Manually insert a Movie row and FTS entry (no trigger for Movies in test setup)
        var movie = new Movie { Title = "Inception Dream", SourceId = source.Id };
        ctx.Movies.Add(movie);
        await ctx.SaveChangesAsync();

        using (var cmd = _connection.CreateCommand())
        {
            cmd.CommandText =
                "INSERT INTO ContentSearch(rowid, content_id, content_type, source_id, title, description, group_name) " +
                "VALUES (@rowid, @cid, 'Movie', @sid, @title, NULL, NULL)";
            cmd.Parameters.AddWithValue("@rowid", movie.Id + 10000);
            cmd.Parameters.AddWithValue("@cid", movie.Id);
            cmd.Parameters.AddWithValue("@sid", source.Id);
            cmd.Parameters.AddWithValue("@title", movie.Title);
            await cmd.ExecuteNonQueryAsync();
        }

        var sut = NewSut();
        var results = await sut.SearchAsync("inception", profileId: 1, CancellationToken.None);

        results.Movies.Should().HaveCount(1);
        results.Movies[0].Title.Should().Be("Inception Dream");
    }

    [Fact]
    [Trait("Category", "Integration")]
    public async Task SearchAsync_ReturnsSeriesResult_WhenSeriesIsIndexed()
    {
        await using var ctx = NewContext();

        var source = new Source { Name = "S5", Url = "http://s5.com", SourceType = SourceType.M3U };
        ctx.Sources.Add(source);
        await ctx.SaveChangesAsync();

        var series = new Series { Title = "Breaking Story", SourceId = source.Id };
        ctx.SeriesItems.Add(series);
        await ctx.SaveChangesAsync();

        using (var cmd = _connection.CreateCommand())
        {
            cmd.CommandText =
                "INSERT INTO ContentSearch(rowid, content_id, content_type, source_id, title, description, group_name) " +
                "VALUES (@rowid, @cid, 'Series', @sid, @title, NULL, NULL)";
            cmd.Parameters.AddWithValue("@rowid", series.Id + 20000);
            cmd.Parameters.AddWithValue("@cid", series.Id);
            cmd.Parameters.AddWithValue("@sid", source.Id);
            cmd.Parameters.AddWithValue("@title", series.Title);
            await cmd.ExecuteNonQueryAsync();
        }

        var sut = NewSut();
        var results = await sut.SearchAsync("breaking", profileId: 1, CancellationToken.None);

        results.Series.Should().HaveCount(1);
        results.Series[0].Title.Should().Be("Breaking Story");
    }

    [Fact]
    [Trait("Category", "Integration")]
    public async Task AutocompleteAsync_ReturnsMovieTitle_WhenMovieIsIndexed()
    {
        await using var ctx = NewContext();

        var source = new Source { Name = "S7", Url = "http://s7.com", SourceType = SourceType.M3U };
        ctx.Sources.Add(source);
        await ctx.SaveChangesAsync();

        var movie = new Movie { Title = "Autocomplete Movie", SourceId = source.Id };
        ctx.Movies.Add(movie);
        await ctx.SaveChangesAsync();

        using (var cmd = _connection.CreateCommand())
        {
            cmd.CommandText =
                "INSERT INTO ContentSearch(rowid, content_id, content_type, source_id, title, description, group_name) " +
                "VALUES (@rowid, @cid, 'Movie', @sid, @title, NULL, NULL)";
            cmd.Parameters.AddWithValue("@rowid", movie.Id + 30000);
            cmd.Parameters.AddWithValue("@cid", movie.Id);
            cmd.Parameters.AddWithValue("@sid", source.Id);
            cmd.Parameters.AddWithValue("@title", movie.Title);
            await cmd.ExecuteNonQueryAsync();
        }

        var sut = NewSut();
        var suggestions = await sut.AutocompleteAsync("autocomplete", CancellationToken.None);

        suggestions.Should().Contain("Autocomplete Movie");
    }

    [Fact]
    [Trait("Category", "Integration")]
    public async Task AutocompleteAsync_ReturnsSeriesTitle_WhenSeriesIsIndexed()
    {
        await using var ctx = NewContext();

        var source = new Source { Name = "S8", Url = "http://s8.com", SourceType = SourceType.M3U };
        ctx.Sources.Add(source);
        await ctx.SaveChangesAsync();

        var series = new Series { Title = "Autocomplete Series", SourceId = source.Id };
        ctx.SeriesItems.Add(series);
        await ctx.SaveChangesAsync();

        using (var cmd = _connection.CreateCommand())
        {
            cmd.CommandText =
                "INSERT INTO ContentSearch(rowid, content_id, content_type, source_id, title, description, group_name) " +
                "VALUES (@rowid, @cid, 'Series', @sid, @title, NULL, NULL)";
            cmd.Parameters.AddWithValue("@rowid", series.Id + 40000);
            cmd.Parameters.AddWithValue("@cid", series.Id);
            cmd.Parameters.AddWithValue("@sid", source.Id);
            cmd.Parameters.AddWithValue("@title", series.Title);
            await cmd.ExecuteNonQueryAsync();
        }

        var sut = NewSut();
        var suggestions = await sut.AutocompleteAsync("autocomplete", CancellationToken.None);

        suggestions.Should().Contain("Autocomplete Series");
    }

    [Fact]
    [Trait("Category", "Integration")]
    public async Task SearchAsync_UnknownContentType_IsSkippedAndDoesNotAppearInResults()
    {
        // Exercises the default `_ => 1.0` weight branch and the missing switch case
        // (no bucket match → item is created but not added to any list).
        await using var ctx = NewContext();

        var source = new Source { Name = "S9", Url = "http://s9.com", SourceType = SourceType.M3U };
        ctx.Sources.Add(source);
        await ctx.SaveChangesAsync();

        // Insert an FTS row with an unrecognised content_type
        using (var cmd = _connection.CreateCommand())
        {
            cmd.CommandText =
                "INSERT INTO ContentSearch(rowid, content_id, content_type, source_id, title, description, group_name) " +
                "VALUES (99002, 9002, 'Unknown', @sid, 'Mystery Item', NULL, NULL)";
            cmd.Parameters.AddWithValue("@sid", source.Id);
            await cmd.ExecuteNonQueryAsync();
        }

        var sut = NewSut();
        var results = await sut.SearchAsync("mystery", profileId: 1, CancellationToken.None);

        results.Channels.Should().BeEmpty();
        results.Movies.Should().BeEmpty();
        results.Series.Should().BeEmpty();
    }

    [Fact]
    [Trait("Category", "Integration")]
    public async Task SearchAsync_RoutesEpisodeContentType_ToSeriesBucket()
    {
        await using var ctx = NewContext();

        var source = new Source { Name = "S6", Url = "http://s6.com", SourceType = SourceType.M3U };
        ctx.Sources.Add(source);
        await ctx.SaveChangesAsync();

        // Episodes are routed to the Series bucket; we need a SeriesItem to hydrate the title.
        // Use an unmatched content_id so hydration produces an empty title (item still present).
        using (var cmd = _connection.CreateCommand())
        {
            cmd.CommandText =
                "INSERT INTO ContentSearch(rowid, content_id, content_type, source_id, title, description, group_name) " +
                "VALUES (99001, 9001, 'Episode', @sid, 'Pilot Episode', NULL, NULL)";
            cmd.Parameters.AddWithValue("@sid", source.Id);
            await cmd.ExecuteNonQueryAsync();
        }

        var sut = NewSut();
        var results = await sut.SearchAsync("pilot", profileId: 1, CancellationToken.None);

        // Episode rows are bucketed into Series
        results.Series.Should().HaveCount(1);
        results.Channels.Should().BeEmpty();
        results.Movies.Should().BeEmpty();
    }
}

// ─── SaveSearchHistory error path ─────────────────────────────────────────────

/// <summary>
/// Tests SaveSearchHistoryAsync exception-handler path by using a factory whose
/// context has already been disposed when the fire-and-forget task runs.
/// </summary>
public class FtsSearchServiceSaveHistoryErrorTests : IAsyncLifetime
{
    private SqliteConnection _connection = null!;
    private DbContextOptions<AppDbContext> _options = null!;

    public async Task InitializeAsync()
    {
        _connection = new SqliteConnection("Data Source=:memory:");
        await _connection.OpenAsync();

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
                CREATE TRIGGER IF NOT EXISTS channel_ai
                AFTER INSERT ON Channels
                BEGIN
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

    [Fact]
    [Trait("Category", "Integration")]
    public async Task SearchAsync_DoesNotThrow_WhenSaveSearchHistoryFails()
    {
        // Arrange: fresh SQLite DB with ContentSearch but NO SearchHistory table.
        // EnsureCreated creates EF-tracked tables; SearchHistory is raw SQL only in the
        // main fixture — so omitting that CREATE TABLE makes ExecuteSqlRawAsync throw,
        // exercising the catch block in SaveSearchHistoryAsync.
        var conn = new SqliteConnection("Data Source=:memory:");
        await conn.OpenAsync();

        using (var cmd = conn.CreateCommand())
        {
            cmd.CommandText = "PRAGMA foreign_keys = OFF";
            await cmd.ExecuteNonQueryAsync();
        }

        var opts = new DbContextOptionsBuilder<AppDbContext>().UseSqlite(conn).Options;
        await using (var ctx = new AppDbContext(opts))
            await ctx.Database.EnsureCreatedAsync();

        // Create FTS table but intentionally skip SearchHistory table
        using (var cmd = conn.CreateCommand())
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

        // Insert trigger so channel insert also populates FTS
        using (var cmd = conn.CreateCommand())
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

        // Seed a channel so SearchAsync runs past early exits and reaches SaveSearchHistoryAsync
        await using (var ctx = new AppDbContext(opts))
        {
            var source = new Source { Name = "S-err", Url = "http://err.com", SourceType = SourceType.M3U };
            ctx.Sources.Add(source);
            await ctx.SaveChangesAsync();
            ctx.Channels.Add(new Channel { Title = "Error Test Channel", SourceId = source.Id, TvgId = "err-ch" });
            await ctx.SaveChangesAsync();
        }

        var appFactory = new SingleConnectionDbContextFactory<AppDbContext>(opts);
        var epgFactory = new TestEpgDbContextFactory();
        var sut = new FtsSearchService(appFactory, epgFactory, NullLogger<FtsSearchService>.Instance);

        // Act & Assert: SearchAsync must not propagate the exception from SaveSearchHistoryAsync.
        var act = async () =>
        {
            var results = await sut.SearchAsync("error", profileId: 1, CancellationToken.None);
            // Give the fire-and-forget task a moment to complete so the catch block is hit
            await Task.Delay(100);
            return results;
        };
        await act.Should().NotThrowAsync();

        await conn.DisposeAsync();
    }
}

// ─── FtsRawRow ────────────────────────────────────────────────────────────────

/// <summary>
/// Direct-construction tests for FtsRawRow — ensures all properties are covered
/// even though the class is only populated via EF SqlQueryRaw in production.
/// </summary>
public class FtsRawRowTests
{
    [Fact]
    [Trait("Category", "Unit")]
    public void FtsRawRow_DefaultProperties_AreCorrectlyInitialized()
    {
        // FtsRawRow is internal — accessed via InternalsVisibleTo or same-assembly test.
        // We use reflection to construct it so the test compiles regardless of access level.
        var type = typeof(FtsSearchService).Assembly
            .GetType("Crispy.Infrastructure.Search.FtsRawRow")!;

        var row = Activator.CreateInstance(type)!;

        // Default values
        type.GetProperty("ContentId")!.GetValue(row).Should().Be(0);
        type.GetProperty("ContentType")!.GetValue(row).Should().Be(string.Empty);
        type.GetProperty("SourceId")!.GetValue(row).Should().Be(0);
        type.GetProperty("Rank")!.GetValue(row).Should().Be(0.0);
    }

    [Fact]
    [Trait("Category", "Unit")]
    public void FtsRawRow_SetProperties_RoundTrip()
    {
        var type = typeof(FtsSearchService).Assembly
            .GetType("Crispy.Infrastructure.Search.FtsRawRow")!;

        var row = Activator.CreateInstance(type)!;
        type.GetProperty("ContentId")!.SetValue(row, 42);
        type.GetProperty("ContentType")!.SetValue(row, "Channel");
        type.GetProperty("SourceId")!.SetValue(row, 7);
        type.GetProperty("Rank")!.SetValue(row, -1.5);

        type.GetProperty("ContentId")!.GetValue(row).Should().Be(42);
        type.GetProperty("ContentType")!.GetValue(row).Should().Be("Channel");
        type.GetProperty("SourceId")!.GetValue(row).Should().Be(7);
        type.GetProperty("Rank")!.GetValue(row).Should().Be(-1.5);
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

    public Task<TContext> CreateDbContextAsync(CancellationToken cancellationToken = default) =>
        Task.FromResult(CreateDbContext());
}
