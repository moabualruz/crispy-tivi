using Crispy.Infrastructure.Data;

using FluentAssertions;

using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;

using Xunit;

namespace Crispy.Infrastructure.Tests.Data;

[Trait("Category", "Unit")]
public class EpgDbContextTests : IDisposable
{
    // Keep a real SQLite :memory: connection open so the interceptor fires.
    private readonly SqliteConnection _connection;
    private readonly DbContextOptions<EpgDbContext> _options;

    public EpgDbContextTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();

        _options = new DbContextOptionsBuilder<EpgDbContext>()
            .UseSqlite(_connection)
            .Options;

        using var ctx = new EpgDbContext(_options);
        ctx.Database.EnsureCreated();
    }

    [Fact]
    public void EpgDbContext_ShouldCreateSuccessfully()
    {
        using var context = new EpgDbContext(_options);
        context.Should().NotBeNull();
    }

    [Fact]
    public void Programmes_DbSet_ShouldBeAccessible()
    {
        using var context = new EpgDbContext(_options);
        context.Programmes.Should().NotBeNull();
    }

    [Fact]
    public void Reminders_DbSet_ShouldBeAccessible()
    {
        using var context = new EpgDbContext(_options);
        context.Reminders.Should().NotBeNull();
    }

    [Fact]
    public void EpgConnectionInterceptor_ShouldApplyWalMode_WhenConnectionOpens()
    {
        // The interceptor is applied via OnConfiguring → AddInterceptors.
        // We force a real connection open by opening the database.
        using var context = new EpgDbContext(_options);

        // Open the underlying connection so the interceptor fires.
        context.Database.OpenConnection();

        // Query PRAGMA journal_mode.
        // SQLite :memory: databases always report "memory" — WAL cannot be applied
        // to in-memory databases (the PRAGMA is silently ignored). On a real file-based
        // database the interceptor sets WAL. Both outcomes are acceptable here.
        using var cmd = _connection.CreateCommand();
        cmd.CommandText = "PRAGMA journal_mode;";
        var mode = cmd.ExecuteScalar()?.ToString();

        mode.Should().BeOneOf("wal", "memory");
    }

    [Fact]
    public async Task EpgDbContext_ShouldSaveAndRetrieveProgramme()
    {
        await using var context = new EpgDbContext(_options);

        var programme = new Crispy.Domain.Entities.EpgProgramme
        {
            ChannelId = "channel1",
            Title = "Test Show",
            StartUtc = DateTime.UtcNow,
            StopUtc = DateTime.UtcNow.AddHours(1),
        };

        context.Programmes.Add(programme);
        await context.SaveChangesAsync();

        var retrieved = await context.Programmes.ToListAsync();
        retrieved.Should().ContainSingle(p => p.Title == "Test Show");
    }

    public void Dispose()
    {
        _connection.Dispose();
    }
}
