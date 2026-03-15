using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.Infrastructure.Player;
using Crispy.Infrastructure.Tests.Helpers;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Crispy.Infrastructure.Tests.Player;

[Trait("Category", "Unit")]
public class MultiviewServiceTests
{
    private class FakePlayerService : IPlayerService
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

    private sealed class DisposableFakePlayerService : FakePlayerService, IDisposable
    {
        public int DisposeCallCount { get; private set; }

        public void Dispose() => DisposeCallCount++;
    }

    private static FakePlayerService[] MakePlayers(int count) =>
        Enumerable.Range(0, count).Select(_ => new FakePlayerService()).ToArray();

    private static MultiviewService CreateSut(IPlayerService[]? players = null)
    {
        var p = players ?? MakePlayers(4);
        return new MultiviewService(p, NullLogger<MultiviewService>.Instance);
    }

    // ── Slots ─────────────────────────────────────────────────────────────────

    [Fact]
    public void Slots_HasCount4_OnConstruction()
    {
        using var sut = CreateSut();

        sut.Slots.Should().HaveCount(4);
    }

    [Fact]
    public void Slots_SlotIndicesAreZeroToThree_OnConstruction()
    {
        using var sut = CreateSut();

        sut.Slots.Select(s => s.SlotIndex).Should().BeEquivalentTo([0, 1, 2, 3]);
    }

    [Fact]
    public void Slots_AllNotActive_OnConstruction()
    {
        using var sut = CreateSut();

        sut.Slots.Should().AllSatisfy(s => s.IsActive.Should().BeFalse());
    }

    [Fact]
    public void Slots_Slot0IsAudioActive_OnConstruction()
    {
        using var sut = CreateSut();

        sut.Slots[0].IsAudioActive.Should().BeTrue();
        sut.Slots[1].IsAudioActive.Should().BeFalse();
        sut.Slots[2].IsAudioActive.Should().BeFalse();
        sut.Slots[3].IsAudioActive.Should().BeFalse();
    }

    [Fact]
    public void Constructor_ThrowsArgumentException_WhenFewerThan4PlayersProvided()
    {
        var players = MakePlayers(2);

        var act = () => new MultiviewService(players, NullLogger<MultiviewService>.Instance);

        act.Should().Throw<ArgumentException>();
    }

    // ── SlotsChanged ──────────────────────────────────────────────────────────

    [Fact]
    public void SlotsChanged_IsNotNull()
    {
        using var sut = CreateSut();

        sut.SlotsChanged.Should().NotBeNull();
    }

    [Fact]
    public void SlotsChanged_CanBeSubscribedWithoutThrowing()
    {
        using var sut = CreateSut();

        var act = () =>
        {
            using var _ = sut.SlotsChanged.Subscribe(_ => { });
        };

        act.Should().NotThrow();
    }

    // ── AssignSlotAsync ───────────────────────────────────────────────────────

    [Fact]
    public async Task AssignSlotAsync_DoesNotThrow_ForValidIndex()
    {
        using var sut = CreateSut();
        var request = new PlaybackRequest("http://example.com/live", PlaybackContentType.LiveTv);

        var act = async () => await sut.AssignSlotAsync(0, request);

        await act.Should().NotThrowAsync();
    }

    [Fact]
    public async Task AssignSlotAsync_MarksSlotActive()
    {
        using var sut = CreateSut();
        var request = new PlaybackRequest("http://example.com/live", PlaybackContentType.LiveTv);

        await sut.AssignSlotAsync(0, request);

        sut.Slots[0].IsActive.Should().BeTrue();
    }

    [Fact]
    public async Task AssignSlotAsync_SetsRequest_OnSlot()
    {
        using var sut = CreateSut();
        var request = new PlaybackRequest("http://example.com/live", PlaybackContentType.LiveTv, Title: "Test");

        await sut.AssignSlotAsync(1, request);

        sut.Slots[1].Request.Should().Be(request);
    }

    [Fact]
    public async Task AssignSlotAsync_ThrowsArgumentException_ForInvalidIndex()
    {
        using var sut = CreateSut();
        var request = new PlaybackRequest("http://example.com/live", PlaybackContentType.LiveTv);

        var act = async () => await sut.AssignSlotAsync(5, request);

        await act.Should().ThrowAsync<ArgumentException>();
    }

    // ── ClearSlotAsync ────────────────────────────────────────────────────────

    [Fact]
    public async Task ClearSlotAsync_DoesNotThrow_ForValidIndex()
    {
        using var sut = CreateSut();

        var act = async () => await sut.ClearSlotAsync(0);

        await act.Should().NotThrowAsync();
    }

    [Fact]
    public async Task ClearSlotAsync_MarksSlotInactive_AfterAssign()
    {
        using var sut = CreateSut();
        var request = new PlaybackRequest("http://example.com/live", PlaybackContentType.LiveTv);
        await sut.AssignSlotAsync(0, request);

        await sut.ClearSlotAsync(0);

        sut.Slots[0].IsActive.Should().BeFalse();
    }

    [Fact]
    public async Task ClearSlotAsync_ThrowsArgumentException_ForInvalidIndex()
    {
        using var sut = CreateSut();

        var act = async () => await sut.ClearSlotAsync(-1);

        await act.Should().ThrowAsync<ArgumentException>();
    }

    // ── SetActiveAudioSlotAsync ───────────────────────────────────────────────

    [Fact]
    public async Task SetActiveAudioSlotAsync_DoesNotThrow_ForValidIndex()
    {
        using var sut = CreateSut();

        var act = async () => await sut.SetActiveAudioSlotAsync(0);

        await act.Should().NotThrowAsync();
    }

    [Fact]
    public async Task SetActiveAudioSlotAsync_SetsAudioActive_OnTargetSlot()
    {
        using var sut = CreateSut();

        await sut.SetActiveAudioSlotAsync(2);

        sut.Slots[2].IsAudioActive.Should().BeTrue();
    }

    [Fact]
    public async Task SetActiveAudioSlotAsync_ClearsAudioActive_OnOtherSlots()
    {
        using var sut = CreateSut();

        await sut.SetActiveAudioSlotAsync(3);

        sut.Slots[0].IsAudioActive.Should().BeFalse();
        sut.Slots[1].IsAudioActive.Should().BeFalse();
        sut.Slots[2].IsAudioActive.Should().BeFalse();
        sut.Slots[3].IsAudioActive.Should().BeTrue();
    }

    // ── GetSlotPlayer ─────────────────────────────────────────────────────────

    [Fact]
    public void GetSlotPlayer_ReturnsExpectedPlayer_ForValidIndex()
    {
        var players = MakePlayers(4);
        using var sut = CreateSut(players);

        var result = sut.GetSlotPlayer(1);

        result.Should().BeSameAs(players[1]);
    }

    [Fact]
    public void GetSlotPlayer_ThrowsArgumentException_ForInvalidIndex()
    {
        using var sut = CreateSut();

        var act = () => sut.GetSlotPlayer(10);

        act.Should().Throw<ArgumentException>();
    }

    // ── SlotsChanged emits ────────────────────────────────────────────────────

    [Fact]
    public async Task AssignSlotAsync_EmitsSlotsChanged()
    {
        using var sut = CreateSut();
        IReadOnlyList<MultiviewSlot>? emitted = null;
        using var _ = sut.SlotsChanged.Subscribe(s => emitted = s);
        var request = new PlaybackRequest("http://example.com/live", PlaybackContentType.LiveTv);

        await sut.AssignSlotAsync(0, request);

        emitted.Should().NotBeNull();
    }

    // ── Dispose ───────────────────────────────────────────────────────────────

    [Fact]
    public void Dispose_DoesNotThrow()
    {
        var sut = CreateSut();

        var act = () => sut.Dispose();

        act.Should().NotThrow();
    }

    [Fact]
    public void Dispose_CallsDisposeOnDisposablePlayers()
    {
        var disposablePlayer = new DisposableFakePlayerService();
        var players = new IPlayerService[] { disposablePlayer }
            .Concat(MakePlayers(3))
            .ToArray();
        var sut = new MultiviewService(players, NullLogger<MultiviewService>.Instance);

        sut.Dispose();

        disposablePlayer.DisposeCallCount.Should().Be(1);
    }
}
