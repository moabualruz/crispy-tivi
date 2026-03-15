namespace Crispy.Application.Player.Models;

/// <summary>
/// A scheduled notification reminder for a TV programme (PLR-43).
/// </summary>
public class Reminder
{
    /// <summary>Unique identifier (GUID).</summary>
    public required string Id { get; set; }

    /// <summary>Display name of the programme to be reminded about.</summary>
    public required string ProgramName { get; set; }

    /// <summary>Display name of the channel airing the programme.</summary>
    public required string ChannelName { get; set; }

    /// <summary>UTC time the programme starts.</summary>
    public DateTimeOffset StartTime { get; set; }

    /// <summary>UTC time the local notification should fire (typically StartTime - offset).</summary>
    public DateTimeOffset NotifyAt { get; set; }

    /// <summary>True once the notification has been dispatched.</summary>
    public bool Fired { get; set; }

    /// <summary>Profile this reminder belongs to.</summary>
    public required string ProfileId { get; set; }

    /// <summary>UTC timestamp when this reminder was created.</summary>
    public DateTimeOffset CreatedAt { get; set; }
}
