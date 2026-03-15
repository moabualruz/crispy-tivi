using Crispy.Application.Player.Models;

namespace Crispy.Application.Player;

/// <summary>
/// Persistence contract for EPG programme reminders (PLR-43).
/// </summary>
public interface IReminderRepository
{
    /// <summary>
    /// Returns all unfired reminders whose NotifyAt is in the future, ordered by NotifyAt ascending.
    /// </summary>
    Task<IReadOnlyList<Reminder>> GetPendingAsync(string profileId);

    /// <summary>Persists a new reminder.</summary>
    Task AddAsync(Reminder reminder);

    /// <summary>Marks a reminder as fired (Fired = true).</summary>
    Task MarkFiredAsync(string reminderId);

    /// <summary>Deletes a reminder by ID.</summary>
    Task DeleteAsync(string reminderId);
}
