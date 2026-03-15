using Crispy.Application.Player.Models;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Crispy.Infrastructure.Data.Configurations;

/// <summary>
/// EF Core configuration for Reminder (PLR-43).
/// </summary>
public class ReminderConfiguration : IEntityTypeConfiguration<Reminder>
{
    /// <inheritdoc />
    public void Configure(EntityTypeBuilder<Reminder> builder)
    {
        builder.ToTable("PlayerReminders");

        builder.HasKey(r => r.Id);
        builder.Property(r => r.Id).HasMaxLength(36);

        builder.Property(r => r.ProgramName).HasMaxLength(500);
        builder.Property(r => r.ChannelName).HasMaxLength(200);
        builder.Property(r => r.ProfileId).HasMaxLength(100);

        // Pending reminders query index
        builder.HasIndex(r => new { r.ProfileId, r.NotifyAt, r.Fired });
    }
}
