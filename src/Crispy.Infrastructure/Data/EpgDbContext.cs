using Crispy.Domain.Entities;
using Crispy.Infrastructure.Data.Configurations;

using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;

namespace Crispy.Infrastructure.Data;

/// <summary>
/// Dedicated EF Core context for EPG programme data, stored in a separate epg.db file.
/// Using WAL mode and memory temp store for high-throughput bulk upserts during EPG sync.
/// </summary>
public class EpgDbContext : DbContext
{
    /// <summary>EPG programme data.</summary>
    public DbSet<EpgProgramme> Programmes => Set<EpgProgramme>();

    /// <summary>User-set EPG reminders.</summary>
    public DbSet<EpgReminder> Reminders => Set<EpgReminder>();

    /// <summary>
    /// Creates a new EpgDbContext with the given options.
    /// </summary>
    public EpgDbContext(DbContextOptions<EpgDbContext> options) : base(options)
    {
    }

    /// <inheritdoc />
    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
    {
        base.OnConfiguring(optionsBuilder);

        // Apply performance PRAGMAs when a connection is opened
        optionsBuilder.AddInterceptors(new EpgConnectionInterceptor());
    }

    /// <inheritdoc />
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.ApplyConfiguration(new EpgProgrammeConfiguration());
        modelBuilder.ApplyConfiguration(new EpgReminderConfiguration());
    }
}

/// <summary>
/// Applies WAL mode and performance PRAGMAs when an EPG database connection opens.
/// </summary>
internal sealed class EpgConnectionInterceptor : Microsoft.EntityFrameworkCore.Diagnostics.DbConnectionInterceptor
{
    public override void ConnectionOpened(
        System.Data.Common.DbConnection connection,
        Microsoft.EntityFrameworkCore.Diagnostics.ConnectionEndEventData eventData)
    {
        ApplyPragmas(connection);
    }

    public override Task ConnectionOpenedAsync(
        System.Data.Common.DbConnection connection,
        Microsoft.EntityFrameworkCore.Diagnostics.ConnectionEndEventData eventData,
        CancellationToken cancellationToken = default)
    {
        ApplyPragmas(connection);
        return Task.CompletedTask;
    }

    private static void ApplyPragmas(System.Data.Common.DbConnection connection)
    {
        if (connection is not SqliteConnection)
            return;

        using var cmd = connection.CreateCommand();

        // WAL mode for concurrent read/write without blocking
        cmd.CommandText = "PRAGMA journal_mode=WAL;";
        cmd.ExecuteNonQuery();

        // Incremental auto_vacuum keeps epg.db from growing unboundedly
        cmd.CommandText = "PRAGMA auto_vacuum=INCREMENTAL;";
        cmd.ExecuteNonQuery();

        // Store temp tables in memory for faster bulk operations
        cmd.CommandText = "PRAGMA temp_store=MEMORY;";
        cmd.ExecuteNonQuery();
    }
}
