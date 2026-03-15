using Crispy.Application.Player.Models;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Crispy.Infrastructure.Data.Configurations;

/// <summary>
/// EF Core configuration for StreamHealth telemetry (PLR-40).
/// </summary>
public class StreamHealthConfiguration : IEntityTypeConfiguration<StreamHealth>
{
    /// <inheritdoc />
    public void Configure(EntityTypeBuilder<StreamHealth> builder)
    {
        builder.ToTable("PlayerStreamHealth");

        builder.HasKey(h => h.UrlHash);
        builder.Property(h => h.UrlHash).HasMaxLength(16);
    }
}
