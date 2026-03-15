using Crispy.Domain.Entities;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Crispy.Infrastructure.Data.Configurations;

/// <summary>
/// EF Core configuration for the ChannelGroup entity.
/// </summary>
public class ChannelGroupConfiguration : IEntityTypeConfiguration<ChannelGroup>
{
    /// <inheritdoc />
    public void Configure(EntityTypeBuilder<ChannelGroup> builder)
    {
        builder.HasKey(g => g.Id);

        builder.Property(g => g.Name).IsRequired().HasMaxLength(200);

        builder.HasIndex(g => g.SourceId);
        builder.HasIndex(g => g.SortOrder);

        builder.HasQueryFilter(g => g.DeletedAt == null);
    }
}
