using Crispy.Domain.Entities;
using Crispy.Infrastructure.Data.Configurations;

using Microsoft.EntityFrameworkCore;

namespace Crispy.Infrastructure.Data;

/// <summary>
/// EF Core database context with auto timestamps and soft delete filtering.
/// </summary>
public class AppDbContext : DbContext
{
    // -------------------------------------------------------------------------
    // Phase 1 entities
    // -------------------------------------------------------------------------

    /// <summary>Profiles table.</summary>
    public DbSet<Profile> Profiles => Set<Profile>();

    /// <summary>Settings table.</summary>
    public DbSet<Setting> Settings => Set<Setting>();

    /// <summary>Sources table.</summary>
    public DbSet<Source> Sources => Set<Source>();

    // -------------------------------------------------------------------------
    // Phase 2 — Channels
    // -------------------------------------------------------------------------

    /// <summary>Channels table.</summary>
    public DbSet<Channel> Channels => Set<Channel>();

    /// <summary>Channel groups table.</summary>
    public DbSet<ChannelGroup> ChannelGroups => Set<ChannelGroup>();

    /// <summary>Channel group memberships join table.</summary>
    public DbSet<ChannelGroupMembership> ChannelGroupMemberships => Set<ChannelGroupMembership>();

    /// <summary>Deduplication groups table.</summary>
    public DbSet<DeduplicationGroup> DeduplicationGroups => Set<DeduplicationGroup>();

    /// <summary>Stream endpoints table.</summary>
    public DbSet<StreamEndpoint> StreamEndpoints => Set<StreamEndpoint>();

    // -------------------------------------------------------------------------
    // Phase 2 — VOD
    // -------------------------------------------------------------------------

    /// <summary>Movies table.</summary>
    public DbSet<Movie> Movies => Set<Movie>();

    /// <summary>Series table.</summary>
    public DbSet<Series> SeriesItems => Set<Series>();

    /// <summary>Episodes table.</summary>
    public DbSet<Episode> Episodes => Set<Episode>();

    // -------------------------------------------------------------------------
    // Phase 2 — Operational
    // -------------------------------------------------------------------------

    /// <summary>Watch history table.</summary>
    public DbSet<WatchHistory> WatchHistory => Set<WatchHistory>();

    /// <summary>Sync history audit table.</summary>
    public DbSet<SyncHistory> SyncHistory => Set<SyncHistory>();

    /// <summary>Offline downloads table.</summary>
    public DbSet<Download> Downloads => Set<Download>();

    /// <summary>
    /// Creates a new AppDbContext with the given options.
    /// </summary>
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
    {
    }

    /// <inheritdoc />
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Phase 1 configurations
        modelBuilder.ApplyConfiguration(new ProfileConfiguration());
        modelBuilder.ApplyConfiguration(new SettingConfiguration());
        modelBuilder.ApplyConfiguration(new SourceConfiguration());

        // Phase 2 — Channel configurations
        modelBuilder.ApplyConfiguration(new ChannelConfiguration());
        modelBuilder.ApplyConfiguration(new ChannelGroupConfiguration());
        modelBuilder.ApplyConfiguration(new ChannelGroupMembershipConfiguration());
        modelBuilder.ApplyConfiguration(new DeduplicationGroupConfiguration());
        modelBuilder.ApplyConfiguration(new StreamEndpointConfiguration());

        // Phase 2 — VOD configurations
        modelBuilder.ApplyConfiguration(new MovieConfiguration());
        modelBuilder.ApplyConfiguration(new SeriesConfiguration());
        modelBuilder.ApplyConfiguration(new EpisodeConfiguration());

        // Phase 2 — Operational configurations
        modelBuilder.ApplyConfiguration(new WatchHistoryConfiguration());
        modelBuilder.ApplyConfiguration(new SyncHistoryConfiguration());
        modelBuilder.ApplyConfiguration(new DownloadConfiguration());

        // Global soft-delete query filters — Phase 1
        modelBuilder.Entity<Profile>().HasQueryFilter(e => e.DeletedAt == null);
        modelBuilder.Entity<Setting>().HasQueryFilter(e => e.DeletedAt == null);
        modelBuilder.Entity<Source>().HasQueryFilter(e => e.DeletedAt == null);
    }

    /// <inheritdoc />
    public override async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        var now = DateTime.UtcNow;

        foreach (var entry in ChangeTracker.Entries<BaseEntity>())
        {
            switch (entry.State)
            {
                case EntityState.Added:
                    entry.Entity.CreatedAt = now;
                    entry.Entity.UpdatedAt = now;
                    break;
                case EntityState.Modified:
                    entry.Entity.UpdatedAt = now;
                    break;
            }
        }

        return await base.SaveChangesAsync(cancellationToken);
    }
}
