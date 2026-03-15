using Crispy.Domain.Entities;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Crispy.Infrastructure.Data.Configurations;

/// <summary>
/// EF Core configuration for the Movie entity.
/// </summary>
public class MovieConfiguration : IEntityTypeConfiguration<Movie>
{
    /// <inheritdoc />
    public void Configure(EntityTypeBuilder<Movie> builder)
    {
        builder.HasKey(m => m.Id);

        builder.Property(m => m.Title).IsRequired().HasMaxLength(500);
        builder.Property(m => m.Thumbnail).HasMaxLength(2048);
        builder.Property(m => m.StreamUrl).HasMaxLength(2048);
        builder.Property(m => m.Overview).HasMaxLength(4000);
        builder.Property(m => m.Genres).HasMaxLength(500);
        builder.Property(m => m.BackdropUrl).HasMaxLength(2048);

        // Not unique — same movie may appear in multiple sources pre-dedup
        builder.HasIndex(m => m.TmdbId);
        builder.HasIndex(m => m.SourceId);

        builder.HasQueryFilter(m => m.DeletedAt == null);

        builder.HasOne(m => m.Source)
            .WithMany()
            .HasForeignKey(m => m.SourceId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
