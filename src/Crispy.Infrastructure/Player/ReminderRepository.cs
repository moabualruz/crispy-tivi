using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.Infrastructure.Data;

using Microsoft.EntityFrameworkCore;

namespace Crispy.Infrastructure.Player;

/// <summary>
/// SQLite-backed implementation of IReminderRepository (PLR-43).
/// </summary>
public sealed class ReminderRepository : IReminderRepository
{
    private readonly IDbContextFactory<AppDbContext> _dbFactory;

    /// <summary>Initializes a new instance of <see cref="ReminderRepository"/>.</summary>
    public ReminderRepository(IDbContextFactory<AppDbContext> dbFactory)
    {
        _dbFactory = dbFactory;
    }

    /// <inheritdoc />
    public async Task<IReadOnlyList<Reminder>> GetPendingAsync(string profileId)
    {
        await using var db = await _dbFactory.CreateDbContextAsync().ConfigureAwait(false);

        return await db.Reminders
            .Where(r => r.ProfileId == profileId
                     && !r.Fired
                     && r.NotifyAt > DateTimeOffset.UtcNow)
            .OrderBy(r => r.NotifyAt)
            .ToListAsync()
            .ConfigureAwait(false);
    }

    /// <inheritdoc />
    public async Task AddAsync(Reminder reminder)
    {
        await using var db = await _dbFactory.CreateDbContextAsync().ConfigureAwait(false);
        db.Reminders.Add(reminder);
        await db.SaveChangesAsync().ConfigureAwait(false);
    }

    /// <inheritdoc />
    public async Task MarkFiredAsync(string reminderId)
    {
        await using var db = await _dbFactory.CreateDbContextAsync().ConfigureAwait(false);

        var reminder = await db.Reminders.FindAsync(reminderId).ConfigureAwait(false);
        if (reminder is not null)
        {
            reminder.Fired = true;
            await db.SaveChangesAsync().ConfigureAwait(false);
        }
    }

    /// <inheritdoc />
    public async Task DeleteAsync(string reminderId)
    {
        await using var db = await _dbFactory.CreateDbContextAsync().ConfigureAwait(false);

        var reminder = await db.Reminders.FindAsync(reminderId).ConfigureAwait(false);
        if (reminder is not null)
        {
            db.Reminders.Remove(reminder);
            await db.SaveChangesAsync().ConfigureAwait(false);
        }
    }
}
