using Crispy.Domain.Entities;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Crispy.Infrastructure.Data.Configurations;

/// <summary>
/// EF Core configuration for the WatchHistory entity.
/// </summary>
public class WatchHistoryConfiguration : IEntityTypeConfiguration<WatchHistory>
{
    /// <inheritdoc />
    public void Configure(EntityTypeBuilder<WatchHistory> builder)
    {
        builder.HasKey(w => w.Id);

        builder.Property(w => w.ContentType).HasConversion<string>().HasMaxLength(20);

        // Primary query: resume playback for a profile + content item
        builder.HasIndex(w => new { w.ProfileId, w.ContentType, w.ContentId });
        // Recent watch history feed
        builder.HasIndex(w => w.WatchedAt);

        builder.HasQueryFilter(w => w.DeletedAt == null);

        builder.HasOne(w => w.Profile)
            .WithMany()
            .HasForeignKey(w => w.ProfileId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
