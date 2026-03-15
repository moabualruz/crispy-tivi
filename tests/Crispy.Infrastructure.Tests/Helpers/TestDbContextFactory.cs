using Crispy.Infrastructure.Data;

using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;

namespace Crispy.Infrastructure.Tests.Helpers;

/// <summary>
/// Creates SQLite in-memory AppDbContext instances for testing.
/// Keeps a shared connection open so the in-memory DB persists across contexts.
/// </summary>
public sealed class TestDbContextFactory : IDbContextFactory<AppDbContext>, IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly DbContextOptions<AppDbContext> _options;

    /// <summary>
    /// Creates a new factory with a fresh in-memory SQLite database.
    /// </summary>
    public TestDbContextFactory()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();

        _options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(_connection)
            .Options;

        // Create the schema
        using var context = new AppDbContext(_options);
        context.Database.EnsureCreated();
    }

    /// <inheritdoc />
    public AppDbContext CreateDbContext()
    {
        return new AppDbContext(_options);
    }

    /// <inheritdoc />
    public Task<AppDbContext> CreateDbContextAsync(CancellationToken cancellationToken = default)
    {
        return Task.FromResult(CreateDbContext());
    }

    /// <inheritdoc />
    public void Dispose()
    {
        _connection.Dispose();
    }
}
