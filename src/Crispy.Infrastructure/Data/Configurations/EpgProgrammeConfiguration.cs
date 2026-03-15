using Crispy.Domain.Entities;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Crispy.Infrastructure.Data.Configurations;

/// <summary>
/// EF Core configuration for the EpgProgramme entity (stored in epg.db).
/// </summary>
public class EpgProgrammeConfiguration : IEntityTypeConfiguration<EpgProgramme>
{
    /// <inheritdoc />
    public void Configure(EntityTypeBuilder<EpgProgramme> builder)
    {
        builder.HasKey(p => p.Id);

        builder.Property(p => p.ChannelId).IsRequired().HasMaxLength(200);
        builder.Property(p => p.Title).IsRequired().HasMaxLength(500);
        builder.Property(p => p.SubTitle).HasMaxLength(500);
        builder.Property(p => p.Description).HasMaxLength(4000);
        builder.Property(p => p.Credits).HasMaxLength(4000);
        builder.Property(p => p.EpisodeNumXmltvNs).HasMaxLength(100);
        builder.Property(p => p.EpisodeNumOnScreen).HasMaxLength(100);
        builder.Property(p => p.Rating).HasMaxLength(50);
        builder.Property(p => p.StarRating).HasMaxLength(50);
        builder.Property(p => p.IconUrl).HasMaxLength(2048);
        builder.Property(p => p.MultiLangTitles).HasMaxLength(4000);

        // Primary query pattern: channel + time window
        builder.HasIndex(p => new { p.ChannelId, p.StartUtc, p.StopUtc });
        // Range queries across all channels (EPG grid)
        builder.HasIndex(p => p.StartUtc);
    }
}
