using Crispy.Domain.Entities;

using Microsoft.EntityFrameworkCore;

namespace Crispy.Infrastructure.Data.Seed;

/// <summary>
/// Seeds the database with default data on first run.
/// </summary>
public static class DatabaseSeeder
{
    /// <summary>
    /// Seeds default profile and settings if the database is empty.
    /// </summary>
    public static async Task SeedAsync(IDbContextFactory<AppDbContext> contextFactory)
    {
        await using var context = await contextFactory.CreateDbContextAsync();

        if (await context.Profiles.AnyAsync())
        {
            return;
        }

        var defaultProfile = new Profile
        {
            Name = "Default",
            AvatarIndex = 0,
            IsKids = false,
            AccentColorIndex = 0,
        };

        context.Profiles.Add(defaultProfile);
        await context.SaveChangesAsync();

        // Seed default global settings
        context.Settings.AddRange(
            new Setting { Key = "theme", Value = "0" },
            new Setting { Key = "locale", Value = "\"en\"" }
        );

        await context.SaveChangesAsync();
    }
}
