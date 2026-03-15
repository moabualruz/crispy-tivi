using Crispy.Domain.Entities;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Crispy.Infrastructure.Data.Configurations;

/// <summary>
/// EF Core configuration for the SyncHistory entity.
/// </summary>
public class SyncHistoryConfiguration : IEntityTypeConfiguration<SyncHistory>
{
    /// <inheritdoc />
    public void Configure(EntityTypeBuilder<SyncHistory> builder)
    {
        builder.HasKey(s => s.Id);

        builder.Property(s => s.Status).HasConversion<string>().HasMaxLength(20);
        builder.Property(s => s.ErrorMessage).HasMaxLength(2000);

        // Most recent syncs for a source
        builder.HasIndex(s => new { s.SourceId, s.StartedAt });

        builder.HasQueryFilter(s => s.DeletedAt == null);

        builder.HasOne(s => s.Source)
            .WithMany()
            .HasForeignKey(s => s.SourceId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
