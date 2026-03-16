using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using FluentAssertions;
using Xunit;

namespace Crispy.Application.Tests.Player;

[Trait("Category", "Unit")]
public class NullImplementationsTests
{
    // ── NullTimeshiftService ────────────────────────────────────────────────

    [Fact]
    public void NullTimeshiftService_State_HasZeroBufferDuration()
    {
        var sut = new NullTimeshiftService();
        sut.State.BufferDuration.Should().Be(TimeSpan.Zero);
    }

    [Fact]
    public void NullTimeshiftService_State_HasZeroOffset()
    {
        var sut = new NullTimeshiftService();
        sut.State.Offset.Should().Be(TimeSpan.Zero);
    }

    [Fact]
    public void NullTimeshiftService_State_IsAtLiveEdge()
    {
        var sut = new NullTimeshiftService();
        sut.State.IsAtLiveEdge.Should().BeTrue();
    }

    [Fact]
    public void NullTimeshiftService_State_IsBufferFullFalse()
    {
        var sut = new NullTimeshiftService();
        sut.State.IsBufferFull.Should().BeFalse();
    }

    [Fact]
    public void NullTimeshiftService_State_OffsetDisplayIsEmpty()
    {
        var sut = new NullTimeshiftService();
        sut.State.OffsetDisplay.Should().BeEmpty();
    }

    [Fact]
    public void NullTimeshiftService_StateChanged_IsNotNull()
    {
        var sut = new NullTimeshiftService();
        sut.StateChanged.Should().NotBeNull();
    }

    [Fact]
    public void NullTimeshiftService_MaxBufferDuration_IsZero()
    {
        var sut = new NullTimeshiftService();
        sut.MaxBufferDuration.Should().Be(TimeSpan.Zero);
    }

    [Fact]
    public void NullTimeshiftService_BufferFileSizeBytes_IsZero()
    {
        var sut = new NullTimeshiftService();
        sut.BufferFileSizeBytes.Should().Be(0L);
    }

    [Fact]
    public async Task NullTimeshiftService_StartBufferingAsync_CompletesWithoutThrow()
    {
        var sut = new NullTimeshiftService();
        var act = () => sut.StartBufferingAsync("http://example.com/stream");
        await act.Should().NotThrowAsync();
    }

    [Fact]
    public async Task NullTimeshiftService_StopBufferingAsync_CompletesWithoutThrow()
    {
        var sut = new NullTimeshiftService();
        var act = () => sut.StopBufferingAsync();
        await act.Should().NotThrowAsync();
    }

    [Fact]
    public async Task NullTimeshiftService_GoLiveAsync_CompletesWithoutThrow()
    {
        var sut = new NullTimeshiftService();
        var act = () => sut.GoLiveAsync();
        await act.Should().NotThrowAsync();
    }

    [Fact]
    public async Task NullTimeshiftService_SeekInBufferAsync_CompletesWithoutThrow()
    {
        var sut = new NullTimeshiftService();
        var act = () => sut.SeekInBufferAsync(TimeSpan.FromSeconds(30));
        await act.Should().NotThrowAsync();
    }

    // ── NullAudioStreamDetector ─────────────────────────────────────────────

    [Fact]
    public void NullAudioStreamDetector_IsAudioOnly_ReturnsFalse_WhenAllInputsNull()
    {
        var sut = new NullAudioStreamDetector();
        sut.IsAudioOnly(null, null, Array.Empty<TrackInfo>(), null).Should().BeFalse();
    }

    [Fact]
    public void NullAudioStreamDetector_IsAudioOnly_ReturnsFalse_WhenVideoTracksPresent()
    {
        var sut = new NullAudioStreamDetector();
        var tracks = new[]
        {
            new TrackInfo(1, "Video", "en", true, TrackKind.Video),
            new TrackInfo(2, "Audio", "en", true, TrackKind.Audio),
        };
        sut.IsAudioOnly("tvg-type=\"video\"", "video/mp4", tracks, "Movies").Should().BeFalse();
    }

    [Fact]
    public void NullAudioStreamDetector_IsAudioOnly_ReturnsFalse_WhenAudioLikeInputs()
    {
        var sut = new NullAudioStreamDetector();
        var tracks = new[]
        {
            new TrackInfo(1, "Audio", "en", true, TrackKind.Audio),
        };
        sut.IsAudioOnly("tvg-type=\"audio\"", "audio/mpeg", tracks, "Radio").Should().BeFalse();
    }

    // ── NullMediaSessionService ─────────────────────────────────────────────

    [Fact]
    public async Task NullMediaSessionService_UpdateNowPlayingAsync_CompletesWithoutThrow()
    {
        var sut = new NullMediaSessionService();
        var act = () => sut.UpdateNowPlayingAsync("Title", "Artist", "http://art.example.com/img.jpg", true);
        await act.Should().NotThrowAsync();
    }

    [Fact]
    public async Task NullMediaSessionService_UpdateNowPlayingAsync_WithNullOptionals_CompletesWithoutThrow()
    {
        var sut = new NullMediaSessionService();
        var act = () => sut.UpdateNowPlayingAsync("Title", null, null, false);
        await act.Should().NotThrowAsync();
    }

    [Fact]
    public async Task NullMediaSessionService_ClearAsync_CompletesWithoutThrow()
    {
        var sut = new NullMediaSessionService();
        var act = () => sut.ClearAsync();
        await act.Should().NotThrowAsync();
    }
}
