using Crispy.Application.Player.Models;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Crispy.Infrastructure.Data.Configurations;

/// <summary>
/// EF Core configuration for WatchHistoryEntry — SHA-256 keyed player history (PLR-47/48).
/// </summary>
public class WatchHistoryEntryConfiguration : IEntityTypeConfiguration<WatchHistoryEntry>
{
    /// <inheritdoc />
    public void Configure(EntityTypeBuilder<WatchHistoryEntry> builder)
    {
        builder.ToTable("PlayerWatchHistory");

        builder.HasKey(e => e.Id);
        builder.Property(e => e.Id).HasMaxLength(16);

        builder.Property(e => e.MediaType).HasConversion<string>().HasMaxLength(20);
        builder.Property(e => e.Name).HasMaxLength(500);
        builder.Property(e => e.StreamUrl).HasMaxLength(2000);
        builder.Property(e => e.PosterUrl).HasMaxLength(1000);
        builder.Property(e => e.SeriesPosterUrl).HasMaxLength(1000);
        builder.Property(e => e.SeriesId).HasMaxLength(200);
        builder.Property(e => e.DeviceId).HasMaxLength(100);
        builder.Property(e => e.DeviceName).HasMaxLength(200);
        builder.Property(e => e.ProfileId).HasMaxLength(100);
        builder.Property(e => e.SourceId).HasMaxLength(100);

        // Ignore computed properties — not stored in DB
        builder.Ignore(e => e.Progress);
        builder.Ignore(e => e.IsInProgress);

        // Continue Watching query index (PLR-45)
        builder.HasIndex(e => new { e.ProfileId, e.LastWatched });

        // Series tracking index (PLR-46)
        builder.HasIndex(e => new { e.SeriesId, e.ProfileId });
    }
}
