using Crispy.Infrastructure.Data;

using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;

namespace Crispy.Infrastructure.Tests.Helpers;

/// <summary>
/// Creates SQLite in-memory EpgDbContext instances for testing.
/// </summary>
public sealed class TestEpgDbContextFactory : IDbContextFactory<EpgDbContext>, IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly DbContextOptions<EpgDbContext> _options;

    /// <summary>Creates a new factory with a fresh in-memory SQLite EPG database.</summary>
    public TestEpgDbContextFactory()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();

        _options = new DbContextOptionsBuilder<EpgDbContext>()
            .UseSqlite(_connection)
            .Options;

        using var context = new EpgDbContext(_options);
        context.Database.EnsureCreated();
    }

    /// <inheritdoc />
    public EpgDbContext CreateDbContext() => new(_options);

    /// <inheritdoc />
    public Task<EpgDbContext> CreateDbContextAsync(CancellationToken cancellationToken = default) =>
        Task.FromResult(CreateDbContext());

    /// <inheritdoc />
    public void Dispose() => _connection.Dispose();
}
