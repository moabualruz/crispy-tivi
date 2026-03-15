using Crispy.Domain.Entities;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Crispy.Infrastructure.Data.Configurations;

/// <summary>
/// EF Core configuration for the EpgReminder entity (stored in epg.db).
/// </summary>
public class EpgReminderConfiguration : IEntityTypeConfiguration<EpgReminder>
{
    /// <inheritdoc />
    public void Configure(EntityTypeBuilder<EpgReminder> builder)
    {
        builder.HasKey(r => r.Id);

        builder.HasIndex(r => new { r.ProfileId, r.EpgProgrammeId }).IsUnique();
        builder.HasIndex(r => r.IsFired);

        builder.HasOne(r => r.EpgProgramme)
            .WithMany()
            .HasForeignKey(r => r.EpgProgrammeId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
