using Crispy.Domain.Entities;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Crispy.Infrastructure.Data.Configurations;

/// <summary>
/// EF Core configuration for the Download entity.
/// </summary>
public class DownloadConfiguration : IEntityTypeConfiguration<Download>
{
    /// <inheritdoc />
    public void Configure(EntityTypeBuilder<Download> builder)
    {
        builder.HasKey(d => d.Id);

        builder.Property(d => d.ContentType).HasConversion<string>().HasMaxLength(20);
        builder.Property(d => d.Status).HasConversion<string>().HasMaxLength(20);
        builder.Property(d => d.FilePath).HasMaxLength(1000);
        builder.Property(d => d.Quality).HasMaxLength(50);

        builder.HasIndex(d => new { d.ContentType, d.ContentId });
        builder.HasIndex(d => d.Status);

        builder.HasQueryFilter(d => d.DeletedAt == null);
    }
}
