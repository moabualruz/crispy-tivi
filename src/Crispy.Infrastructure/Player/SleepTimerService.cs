using System.Timers;

using Crispy.Application.Player;

using Timer = System.Timers.Timer;

namespace Crispy.Infrastructure.Player;

/// <summary>
/// Sleep timer implementation using System.Timers.Timer.
/// Emits RemainingChanged every second. Fades volume to zero over the final 30 seconds.
/// </summary>
public sealed class SleepTimerService : ISleepTimerService, IDisposable
{
    private const int FadeStartSeconds = 30;

    private readonly IPlayerService _player;
    private readonly SimpleSubject<TimeSpan?> _remainingSubject = new();

    private Timer? _tickTimer;
    private DateTimeOffset _expiresAt;
    private float _volumeBeforeFade = 1.0f;
    private bool _fadeStarted;
    private bool _active;

    /// <inheritdoc />
    public TimeSpan? Remaining => _active ? _expiresAt - DateTimeOffset.UtcNow : null;

    /// <inheritdoc />
    public IObservable<TimeSpan?> RemainingChanged => _remainingSubject;

    /// <inheritdoc />
    public event EventHandler? TimerElapsed;

    public SleepTimerService(IPlayerService player)
    {
        _player = player;
    }

    /// <inheritdoc />
    public void SetTimer(TimeSpan duration)
    {
        Cancel();

        _expiresAt = DateTimeOffset.UtcNow + duration;
        _fadeStarted = false;
        _active = true;
        _volumeBeforeFade = 1.0f;

        _tickTimer = new Timer(1000) { AutoReset = true };
        _tickTimer.Elapsed += OnTick;
        _tickTimer.Start();
    }

    /// <inheritdoc />
    public void Cancel()
    {
        if (!_active)
        {
            return;
        }

        _active = false;
        _tickTimer?.Stop();
        _tickTimer?.Dispose();
        _tickTimer = null;
        _remainingSubject.OnNext(null);
    }

    /// <inheritdoc />
    public void Dispose()
    {
        Cancel();
        _remainingSubject.OnCompleted();
        _remainingSubject.Dispose();
    }

    private void OnTick(object? sender, ElapsedEventArgs e)
    {
        if (!_active)
        {
            return;
        }

        var remaining = _expiresAt - DateTimeOffset.UtcNow;

        if (remaining <= TimeSpan.Zero)
        {
            // Timer elapsed
            Cancel();
            _ = _player.SetVolumeAsync(0f);
            TimerElapsed?.Invoke(this, EventArgs.Empty);
            return;
        }

        // Start volume fade at FadeStartSeconds remaining
        if (!_fadeStarted && remaining.TotalSeconds <= FadeStartSeconds)
        {
            _fadeStarted = true;
            _volumeBeforeFade = _player.State.Volume;
        }

        if (_fadeStarted)
        {
            // Linear fade from _volumeBeforeFade to 0 over FadeStartSeconds steps
            var fraction = (float)(remaining.TotalSeconds / FadeStartSeconds);
            var fadedVolume = _volumeBeforeFade * Math.Clamp(fraction, 0f, 1f);
            _ = _player.SetVolumeAsync(fadedVolume);
        }

        _remainingSubject.OnNext(remaining);
    }
}
