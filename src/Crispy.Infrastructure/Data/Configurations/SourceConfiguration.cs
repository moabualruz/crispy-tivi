using Crispy.Domain.Entities;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Crispy.Infrastructure.Data.Configurations;

/// <summary>
/// EF Core configuration for the Source entity.
/// </summary>
public class SourceConfiguration : IEntityTypeConfiguration<Source>
{
    /// <inheritdoc />
    public void Configure(EntityTypeBuilder<Source> builder)
    {
        builder.HasKey(s => s.Id);
        builder.Property(s => s.Name).IsRequired().HasMaxLength(200);
        builder.Property(s => s.Url).IsRequired().HasMaxLength(2048);
        builder.Property(s => s.Username).HasMaxLength(256);
        builder.Property(s => s.Password).HasMaxLength(256);
        builder.Property(s => s.SourceType).HasConversion<string>().HasMaxLength(50);
    }
}
