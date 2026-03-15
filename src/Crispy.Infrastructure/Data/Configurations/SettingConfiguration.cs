using Crispy.Domain.Entities;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Crispy.Infrastructure.Data.Configurations;

/// <summary>
/// EF Core configuration for the Setting entity.
/// </summary>
public class SettingConfiguration : IEntityTypeConfiguration<Setting>
{
    /// <inheritdoc />
    public void Configure(EntityTypeBuilder<Setting> builder)
    {
        builder.HasKey(s => s.Id);
        builder.Property(s => s.Key).IsRequired().HasMaxLength(256);
        builder.Property(s => s.Value).IsRequired();

        // Unique index on Key + ProfileId for fast lookups
        builder.HasIndex(s => new { s.Key, s.ProfileId }).IsUnique();
    }
}
