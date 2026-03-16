using Crispy.Application.Player;
using Crispy.Application.Player.Models;

namespace Crispy.Infrastructure.Tests.Helpers;

/// <summary>
/// Minimal hand-written fake for IPlayerService.
/// Avoids System.Reactive / NSubstitute (not resolvable without full restore).
/// Records the last PlayAsync call for assertion in tests.
/// </summary>
public sealed class FakePlayerService : IPlayerService
{
    public PlayerState State { get; } = PlayerState.Empty;
    public IObservable<PlayerState> StateChanged { get; } = NeverObservable<PlayerState>.Instance;
    public IObservable<float[]> AudioSamples { get; } = NeverObservable<float[]>.Instance;
    public IReadOnlyList<TrackInfo> AudioTracks { get; } = Array.Empty<TrackInfo>();
    public IReadOnlyList<TrackInfo> SubtitleTracks { get; } = Array.Empty<TrackInfo>();

    /// <summary>The most recent request passed to PlayAsync.</summary>
    public PlaybackRequest? LastPlayRequest { get; private set; }

    /// <summary>Number of times PlayAsync was called.</summary>
    public int PlayCallCount { get; private set; }

    public Task PlayAsync(PlaybackRequest request, CancellationToken ct = default)
    {
        LastPlayRequest = request;
        PlayCallCount++;
        return Task.CompletedTask;
    }

    public Task PauseAsync() => Task.CompletedTask;
    public Task ResumeAsync() => Task.CompletedTask;
    public Task StopAsync() => Task.CompletedTask;
    public Task SeekAsync(TimeSpan position) => Task.CompletedTask;
    public Task SetRateAsync(float rate) => Task.CompletedTask;
    public Task SetAudioTrackAsync(int trackId) => Task.CompletedTask;
    public Task SetSubtitleTrackAsync(int trackId) => Task.CompletedTask;
    public Task AddSubtitleFileAsync(string filePath) => Task.CompletedTask;
    public Task SetVolumeAsync(float volume) => Task.CompletedTask;
    public Task MuteAsync(bool mute) => Task.CompletedTask;
    public Task SetAspectRatioAsync(string? ratio) => Task.CompletedTask;
}

/// <summary>An observable that never emits — avoids System.Reactive dependency.</summary>
internal sealed class NeverObservable<T> : IObservable<T>
{
    public static readonly NeverObservable<T> Instance = new();
    private NeverObservable() { }
    public IDisposable Subscribe(IObserver<T> observer) => NullDisposable.Instance;
}
