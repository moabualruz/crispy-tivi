using Crispy.Domain.Entities;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Crispy.Infrastructure.Data.Configurations;

/// <summary>
/// EF Core configuration for the StreamEndpoint entity.
/// </summary>
public class StreamEndpointConfiguration : IEntityTypeConfiguration<StreamEndpoint>
{
    /// <inheritdoc />
    public void Configure(EntityTypeBuilder<StreamEndpoint> builder)
    {
        builder.HasKey(e => e.Id);

        builder.Property(e => e.Url).IsRequired().HasMaxLength(2048);
        builder.Property(e => e.Format).HasConversion<string>().HasMaxLength(20);
        builder.Property(e => e.HttpHeaders).HasMaxLength(4000);

        builder.HasIndex(e => new { e.ChannelId, e.SourceId });
        builder.HasIndex(e => e.Priority);

        builder.HasQueryFilter(e => e.DeletedAt == null);

        builder.HasOne(e => e.Channel)
            .WithMany(c => c.StreamEndpoints)
            .HasForeignKey(e => e.ChannelId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(e => e.Source)
            .WithMany()
            .HasForeignKey(e => e.SourceId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
