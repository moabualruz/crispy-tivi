using Crispy.Application.Player.Models;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Crispy.Infrastructure.Data.Configurations;

/// <summary>
/// EF Core configuration for SavedLayout (PLR-42).
/// </summary>
public class SavedLayoutConfiguration : IEntityTypeConfiguration<SavedLayout>
{
    /// <inheritdoc />
    public void Configure(EntityTypeBuilder<SavedLayout> builder)
    {
        builder.ToTable("PlayerSavedLayouts");

        builder.HasKey(l => l.Id);
        builder.Property(l => l.Id).HasMaxLength(36);

        builder.Property(l => l.Name).HasMaxLength(200);
        builder.Property(l => l.Layout).HasConversion<string>().HasMaxLength(20);
        builder.Property(l => l.StreamsJson).HasColumnType("TEXT");
        builder.Property(l => l.ProfileId).HasMaxLength(100);

        builder.HasIndex(l => new { l.ProfileId, l.CreatedAt });
    }
}
