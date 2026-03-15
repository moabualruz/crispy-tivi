using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.Infrastructure.Player;
using Crispy.Infrastructure.Tests.Helpers;
using FluentAssertions;
using Xunit;

namespace Crispy.Infrastructure.Tests.Player;

[Trait("Category", "Unit")]
public class SleepTimerServiceTests
{
    private sealed class FakePlayerService : IPlayerService
    {
        public PlayerState State => PlayerState.Empty;
        public IObservable<PlayerState> StateChanged => new NullObservable<PlayerState>();
        public IObservable<float[]> AudioSamples => new NullObservable<float[]>();
        public IReadOnlyList<TrackInfo> AudioTracks => [];
        public IReadOnlyList<TrackInfo> SubtitleTracks => [];

        public Task PlayAsync(PlaybackRequest request, CancellationToken ct = default) => Task.CompletedTask;
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

    private static SleepTimerService CreateSut() => new(new FakePlayerService());

    [Fact]
    public void Remaining_IsNull_BeforeSetTimerCalled()
    {
        using var sut = CreateSut();

        sut.Remaining.Should().BeNull();
    }

    [Fact]
    public void SetTimer_MakesRemainingNonNull()
    {
        using var sut = CreateSut();

        sut.SetTimer(TimeSpan.FromMinutes(5));

        sut.Remaining.Should().NotBeNull();
    }

    [Fact]
    public void SetTimer_RemainingApproximatesRequestedDuration()
    {
        using var sut = CreateSut();
        var duration = TimeSpan.FromMinutes(10);

        sut.SetTimer(duration);

        sut.Remaining.Should().NotBeNull();
        sut.Remaining!.Value.Should().BeCloseTo(duration, TimeSpan.FromSeconds(2));
    }

    [Fact]
    public void Cancel_AfterSetTimer_MakesRemainingNull()
    {
        using var sut = CreateSut();
        sut.SetTimer(TimeSpan.FromMinutes(5));

        sut.Cancel();

        sut.Remaining.Should().BeNull();
    }

    [Fact]
    public void Cancel_WhenNoTimerActive_DoesNotThrow()
    {
        using var sut = CreateSut();

        var act = () => sut.Cancel();

        act.Should().NotThrow();
    }

    [Fact]
    public void SetTimer_Twice_OverridesFirstTimer()
    {
        using var sut = CreateSut();

        sut.SetTimer(TimeSpan.FromMinutes(1));
        sut.SetTimer(TimeSpan.FromMinutes(20));

        sut.Remaining.Should().NotBeNull();
        sut.Remaining!.Value.Should().BeGreaterThan(TimeSpan.FromMinutes(10));
    }

    [Fact]
    public void RemainingChanged_IsNotNull()
    {
        using var sut = CreateSut();

        sut.RemainingChanged.Should().NotBeNull();
    }

    [Fact]
    public void RemainingChanged_CanBeSubscribedWithoutThrowing()
    {
        using var sut = CreateSut();

        var act = () =>
        {
            using var _ = sut.RemainingChanged.Subscribe(_ => { });
        };

        act.Should().NotThrow();
    }

    [Fact]
    public void TimerElapsed_CanBeSubscribedWithoutThrowing()
    {
        using var sut = CreateSut();

        var act = () => sut.TimerElapsed += (_, _) => { };

        act.Should().NotThrow();
    }

    [Fact]
    public void Dispose_DoesNotThrow()
    {
        var sut = CreateSut();

        var act = () => sut.Dispose();

        act.Should().NotThrow();
    }

    [Fact]
    public void Dispose_AfterSetTimer_DoesNotThrow()
    {
        var sut = CreateSut();
        sut.SetTimer(TimeSpan.FromMinutes(5));

        var act = () => sut.Dispose();

        act.Should().NotThrow();
    }

    [Fact]
    public void Remaining_IsNull_AfterDispose()
    {
        var sut = CreateSut();
        sut.SetTimer(TimeSpan.FromMinutes(5));
        sut.Dispose();

        // After dispose (which calls Cancel), Remaining reflects _active = false
        sut.Remaining.Should().BeNull();
    }
}
