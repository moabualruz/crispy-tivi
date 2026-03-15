using Crispy.Domain.Entities;
using Crispy.Infrastructure.Data.Configurations;

using Microsoft.EntityFrameworkCore;

namespace Crispy.Infrastructure.Data;

/// <summary>
/// EF Core database context with auto timestamps and soft delete filtering.
/// </summary>
public class AppDbContext : DbContext
{
    /// <summary>
    /// Profiles table.
    /// </summary>
    public DbSet<Profile> Profiles => Set<Profile>();

    /// <summary>
    /// Settings table.
    /// </summary>
    public DbSet<Setting> Settings => Set<Setting>();

    /// <summary>
    /// Sources table.
    /// </summary>
    public DbSet<Source> Sources => Set<Source>();

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

        modelBuilder.ApplyConfiguration(new ProfileConfiguration());
        modelBuilder.ApplyConfiguration(new SettingConfiguration());
        modelBuilder.ApplyConfiguration(new SourceConfiguration());

        // Global query filter for soft delete on all BaseEntity types
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
