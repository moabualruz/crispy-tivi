using Crispy.Application.Player.Models;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Crispy.Infrastructure.Data.Configurations;

/// <summary>
/// EF Core configuration for Bookmark (PLR-41).
/// </summary>
public class BookmarkConfiguration : IEntityTypeConfiguration<Bookmark>
{
    /// <inheritdoc />
    public void Configure(EntityTypeBuilder<Bookmark> builder)
    {
        builder.ToTable("PlayerBookmarks");

        builder.HasKey(b => b.Id);
        builder.Property(b => b.Id).HasMaxLength(36);

        builder.Property(b => b.ContentId).HasMaxLength(200);
        builder.Property(b => b.ContentType).HasConversion<string>().HasMaxLength(20);
        builder.Property(b => b.Label).HasMaxLength(500);
        builder.Property(b => b.ProfileId).HasMaxLength(100);

        // Content lookup index
        builder.HasIndex(b => new { b.ContentId, b.ContentType, b.ProfileId });
    }
}
