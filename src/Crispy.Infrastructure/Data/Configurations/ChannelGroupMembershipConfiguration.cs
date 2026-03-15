using Crispy.Domain.Entities;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Crispy.Infrastructure.Data.Configurations;

/// <summary>
/// EF Core configuration for the ChannelGroupMembership join entity.
/// </summary>
public class ChannelGroupMembershipConfiguration : IEntityTypeConfiguration<ChannelGroupMembership>
{
    /// <inheritdoc />
    public void Configure(EntityTypeBuilder<ChannelGroupMembership> builder)
    {
        builder.HasKey(m => m.Id);

        builder.HasIndex(m => new { m.ChannelId, m.ChannelGroupId }).IsUnique();
        builder.HasIndex(m => m.ChannelGroupId);

        builder.HasQueryFilter(m => m.DeletedAt == null);

        builder.HasOne(m => m.Channel)
            .WithMany(c => c.GroupMemberships)
            .HasForeignKey(m => m.ChannelId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(m => m.ChannelGroup)
            .WithMany(g => g.Memberships)
            .HasForeignKey(m => m.ChannelGroupId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
