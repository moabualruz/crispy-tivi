using Crispy.Domain.Entities;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Crispy.Infrastructure.Data.Configurations;

/// <summary>
/// EF Core configuration for the DeduplicationGroup entity.
/// </summary>
public class DeduplicationGroupConfiguration : IEntityTypeConfiguration<DeduplicationGroup>
{
    /// <inheritdoc />
    public void Configure(EntityTypeBuilder<DeduplicationGroup> builder)
    {
        builder.HasKey(g => g.Id);

        builder.Property(g => g.CanonicalTitle).IsRequired().HasMaxLength(500);
        builder.Property(g => g.CanonicalTvgId).HasMaxLength(200);

        builder.HasQueryFilter(g => g.DeletedAt == null);
    }
}
