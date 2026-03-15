using Crispy.Domain.Entities;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Crispy.Infrastructure.Data.Configurations;

/// <summary>
/// EF Core configuration for the Series entity.
/// </summary>
public class SeriesConfiguration : IEntityTypeConfiguration<Series>
{
    /// <inheritdoc />
    public void Configure(EntityTypeBuilder<Series> builder)
    {
        builder.HasKey(s => s.Id);

        builder.Property(s => s.Title).IsRequired().HasMaxLength(500);
        builder.Property(s => s.Thumbnail).HasMaxLength(2048);
        builder.Property(s => s.Overview).HasMaxLength(4000);
        builder.Property(s => s.Genres).HasMaxLength(500);
        builder.Property(s => s.BackdropUrl).HasMaxLength(2048);

        builder.HasIndex(s => s.TmdbId);
        builder.HasIndex(s => s.SourceId);

        builder.HasQueryFilter(s => s.DeletedAt == null);

        builder.HasOne(s => s.Source)
            .WithMany()
            .HasForeignKey(s => s.SourceId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
