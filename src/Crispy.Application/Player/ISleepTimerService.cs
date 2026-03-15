namespace Crispy.Application.Player;

/// <summary>
/// Sleep timer that automatically stops playback after a user-configured duration.
/// </summary>
public interface ISleepTimerService
{
    /// <summary>
    /// Time remaining until the timer fires; null when no timer is active.
    /// </summary>
    TimeSpan? Remaining { get; }

    /// <summary>
    /// Observable stream of remaining time — emits every second while a timer is active,
    /// and emits null when the timer is cancelled or not set.
    /// </summary>
    IObservable<TimeSpan?> RemainingChanged { get; }

    /// <summary>
    /// Sets (or replaces) the sleep timer.
    /// The timer will fire after <paramref name="duration"/> from the moment this method is called.
    /// </summary>
    void SetTimer(TimeSpan duration);

    /// <summary>Cancels the active sleep timer; no-op if no timer is set.</summary>
    void Cancel();

    /// <summary>Raised when the configured duration elapses. The caller should stop playback.</summary>
    event EventHandler TimerElapsed;
}
