namespace Crispy.Domain.Entities;

/// <summary>
/// User-set reminder for an upcoming EPG programme.
/// </summary>
public class EpgReminder : BaseEntity
{
    /// <summary>FK to the profile that created the reminder.</summary>
    public required int ProfileId { get; set; }

    /// <summary>FK to the EPG programme to remind about.</summary>
    public required int EpgProgrammeId { get; set; }

    /// <summary>Navigation property to the EPG programme.</summary>
    public EpgProgramme? EpgProgramme { get; set; }

    /// <summary>How many minutes before the programme start to fire the reminder.</summary>
    public int ReminderMinutesBefore { get; set; } = 5;

    /// <summary>Whether the reminder notification has already been sent.</summary>
    public bool IsFired { get; set; }
}
