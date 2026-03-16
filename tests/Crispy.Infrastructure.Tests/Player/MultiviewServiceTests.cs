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
            using var _ = System.ObservableExtensions.Subscribe(sut.SlotsChanged, _ => { });
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
        using var _ = System.ObservableExtensions.Subscribe(sut.SlotsChanged, s => emitted = s);
        var request = new PlaybackRequest("http://example.com/live", PlaybackContentType.LiveTv);

        await sut.AssignSlotAsync(0, request);

        emitted.Should().NotBeNull();
    }

    // ── ExpandSlotAsync ───────────────────────────────────────────────────────

    [Fact]
    public async Task ExpandSlotAsync_SetsIsExpanded_OnTargetSlot()
    {
        using var sut = CreateSut();

        await sut.ExpandSlotAsync(2);

        sut.Slots[2].IsExpanded.Should().BeTrue();
    }

    [Fact]
    public async Task ExpandSlotAsync_ClearsIsExpanded_OnOtherSlots()
    {
        using var sut = CreateSut();

        await sut.ExpandSlotAsync(1);

        sut.Slots[0].IsExpanded.Should().BeFalse();
        sut.Slots[2].IsExpanded.Should().BeFalse();
        sut.Slots[3].IsExpanded.Should().BeFalse();
    }

    [Fact]
    public async Task ExpandSlotAsync_ThrowsArgumentException_ForInvalidIndex()
    {
        using var sut = CreateSut();

        var act = async () => await sut.ExpandSlotAsync(99);

        await act.Should().ThrowAsync<ArgumentException>();
    }

    // ── CollapseToGridAsync ───────────────────────────────────────────────────

    [Fact]
    public async Task CollapseToGridAsync_ClearsIsExpanded_OnAllSlots()
    {
        using var sut = CreateSut();
        await sut.ExpandSlotAsync(0);

        await sut.CollapseToGridAsync();

        sut.Slots.Should().AllSatisfy(s => s.IsExpanded.Should().BeFalse());
    }

    [Fact]
    public async Task CollapseToGridAsync_DoesNotThrow_WhenNoSlotExpanded()
    {
        using var sut = CreateSut();

        var act = async () => await sut.CollapseToGridAsync();

        await act.Should().NotThrowAsync();
    }

    // ── SaveLayoutAsync ───────────────────────────────────────────────────────

    [Fact]
    public async Task SaveLayoutAsync_AddsToSavedLayouts()
    {
        using var sut = CreateSut();
        var request = new PlaybackRequest("http://example.com/live", PlaybackContentType.LiveTv, Title: "Ch1");
        await sut.AssignSlotAsync(0, request);

        await sut.SaveLayoutAsync("My Layout");

        var layouts = await sut.GetSavedLayoutsAsync();
        layouts.Should().HaveCount(1);
        layouts[0].Name.Should().Be("My Layout");
    }

    [Fact]
    public async Task SaveLayoutAsync_StoresStreamsAsJson()
    {
        using var sut = CreateSut();
        var request = new PlaybackRequest("http://example.com/live", PlaybackContentType.LiveTv, Title: "Ch1");
        await sut.AssignSlotAsync(0, request);

        await sut.SaveLayoutAsync("JsonLayout");

        var layouts = await sut.GetSavedLayoutsAsync();
        layouts[0].StreamsJson.Should().Contain("http://example.com/live");
    }

    // ── GetSavedLayoutsAsync ──────────────────────────────────────────────────

    [Fact]
    public async Task GetSavedLayoutsAsync_ReturnsEmpty_WhenNoLayoutsSaved()
    {
        using var sut = CreateSut();

        var layouts = await sut.GetSavedLayoutsAsync();

        layouts.Should().BeEmpty();
    }

    [Fact]
    public async Task GetSavedLayoutsAsync_ReturnsMostRecentFirst_AfterMultipleSaves()
    {
        using var sut = CreateSut();
        var req = new PlaybackRequest("http://example.com/live", PlaybackContentType.LiveTv);
        await sut.AssignSlotAsync(0, req);

        await sut.SaveLayoutAsync("First");
        await sut.SaveLayoutAsync("Second");

        var layouts = await sut.GetSavedLayoutsAsync();
        layouts.Should().HaveCount(2);
        layouts[0].Name.Should().Be("Second", "most recently saved layout should be first");
    }

    // ── SwapSlotsAsync ────────────────────────────────────────────────────────

    [Fact]
    public async Task SwapSlotsAsync_ExchangesRequests_BetweenTwoSlots()
    {
        using var sut = CreateSut();
        var reqA = new PlaybackRequest("http://example.com/a", PlaybackContentType.LiveTv, Title: "A");
        var reqB = new PlaybackRequest("http://example.com/b", PlaybackContentType.LiveTv, Title: "B");
        await sut.AssignSlotAsync(0, reqA);
        await sut.AssignSlotAsync(1, reqB);

        await sut.SwapSlotsAsync(0, 1);

        sut.Slots[0].Request.Should().Be(reqB);
        sut.Slots[1].Request.Should().Be(reqA);
    }

    [Fact]
    public async Task SwapSlotsAsync_ThrowsArgumentException_ForInvalidIndex()
    {
        using var sut = CreateSut();

        var act = async () => await sut.SwapSlotsAsync(0, 99);

        await act.Should().ThrowAsync<ArgumentException>();
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
