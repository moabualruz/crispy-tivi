using Crispy.Domain.Entities;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Crispy.Infrastructure.Data.Configurations;

/// <summary>
/// EF Core configuration for the Episode entity.
/// </summary>
public class EpisodeConfiguration : IEntityTypeConfiguration<Episode>
{
    /// <inheritdoc />
    public void Configure(EntityTypeBuilder<Episode> builder)
    {
        builder.HasKey(e => e.Id);

        builder.Property(e => e.Title).IsRequired().HasMaxLength(500);
        builder.Property(e => e.Thumbnail).HasMaxLength(2048);
        builder.Property(e => e.StreamUrl).HasMaxLength(2048);
        builder.Property(e => e.Overview).HasMaxLength(4000);

        builder.HasIndex(e => new { e.SeriesId, e.SeasonNumber, e.EpisodeNumber });
        builder.HasIndex(e => e.SourceId);

        builder.HasQueryFilter(e => e.DeletedAt == null);

        builder.HasOne(e => e.Series)
            .WithMany(s => s.Episodes)
            .HasForeignKey(e => e.SeriesId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(e => e.Source)
            .WithMany()
            .HasForeignKey(e => e.SourceId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
