using Crispy.Domain.Entities;
using Crispy.Domain.Enums;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Crispy.Infrastructure.Data.Configurations;

/// <summary>
/// EF Core configuration for the Channel entity.
/// </summary>
public class ChannelConfiguration : IEntityTypeConfiguration<Channel>
{
    /// <inheritdoc />
    public void Configure(EntityTypeBuilder<Channel> builder)
    {
        builder.HasKey(c => c.Id);

        builder.Property(c => c.Title).IsRequired().HasMaxLength(500);
        builder.Property(c => c.ExternalId).HasMaxLength(500);
        builder.Property(c => c.TvgId).HasMaxLength(200);
        builder.Property(c => c.TvgName).HasMaxLength(500);
        builder.Property(c => c.TvgLogo).HasMaxLength(2048);
        builder.Property(c => c.GroupName).HasMaxLength(200);
        builder.Property(c => c.CatchupSource).HasMaxLength(2048);
        builder.Property(c => c.CatchupType).HasConversion<string>().HasMaxLength(20);

        // Unique per (ExternalId, SourceId) — the real channel identity within a source
        builder.HasIndex(c => new { c.ExternalId, c.SourceId }).IsUnique();
        // Non-unique index for EPG matching — multiple channels can share TvgId (different qualities)
        builder.HasIndex(c => new { c.TvgId, c.SourceId });
        builder.HasIndex(c => c.SourceId);
        builder.HasIndex(c => c.DeduplicationGroupId);

        builder.HasQueryFilter(c => c.DeletedAt == null);

        builder.HasOne(c => c.Source)
            .WithMany()
            .HasForeignKey(c => c.SourceId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(c => c.DeduplicationGroup)
            .WithMany(g => g.Channels)
            .HasForeignKey(c => c.DeduplicationGroupId)
            .OnDelete(DeleteBehavior.SetNull);

        // Ignore computed property — not mapped to a column
        builder.Ignore(c => c.Thumbnail);
    }
}
