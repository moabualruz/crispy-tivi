using Crispy.Application.Player.Models;
using Crispy.Infrastructure.Player;

using FluentAssertions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Player;

[Trait("Category", "Unit")]
public class AudioStreamDetectorTests
{
    private readonly AudioStreamDetector _sut = new();

    private static TrackInfo Audio(int id = 1) =>
        new(id, "Audio", "en", true, TrackKind.Audio);

    private static TrackInfo Video(int id = 2) =>
        new(id, "Video", "", false, TrackKind.Video);

    private static TrackInfo Subtitle(int id = 3) =>
        new(id, "Sub", "en", false, TrackKind.Subtitle);

    // ── Signal 1: M3U radio attribute ──────────────────────────────────────

    [Fact]
    public void IsAudioOnly_ReturnsTrue_WhenM3UAttributesContainsRadioTrue()
    {
        var result = _sut.IsAudioOnly(
            m3uAttributes: "tvg-id=\"abc\" radio=\"true\"",
            mimeType: null,
            tracks: Array.Empty<TrackInfo>(),
            groupTitle: null);

        result.Should().BeTrue();
    }

    [Fact]
    public void IsAudioOnly_ReturnsTrue_WhenM3UAttributesContainsRadioTrueCaseInsensitive()
    {
        var result = _sut.IsAudioOnly(
            m3uAttributes: "RADIO=\"TRUE\"",
            mimeType: null,
            tracks: Array.Empty<TrackInfo>(),
            groupTitle: null);

        result.Should().BeTrue();
    }

    // ── Signal 2: MIME type ────────────────────────────────────────────────

    [Fact]
    public void IsAudioOnly_ReturnsTrue_WhenMimeTypeIsAudioMpeg()
    {
        var result = _sut.IsAudioOnly(
            m3uAttributes: null,
            mimeType: "audio/mpeg",
            tracks: Array.Empty<TrackInfo>(),
            groupTitle: null);

        result.Should().BeTrue();
    }

    [Fact]
    public void IsAudioOnly_ReturnsTrue_WhenMimeTypeIsAudioAac()
    {
        var result = _sut.IsAudioOnly(
            m3uAttributes: null,
            mimeType: "audio/aac",
            tracks: Array.Empty<TrackInfo>(),
            groupTitle: null);

        result.Should().BeTrue();
    }

    [Fact]
    public void IsAudioOnly_ReturnsTrue_WhenMimeTypeIsAudioPrefixCaseInsensitive()
    {
        var result = _sut.IsAudioOnly(
            m3uAttributes: null,
            mimeType: "AUDIO/OGG",
            tracks: Array.Empty<TrackInfo>(),
            groupTitle: null);

        result.Should().BeTrue();
    }

    [Fact]
    public void IsAudioOnly_ReturnsFalse_WhenMimeTypeIsVideoMp4()
    {
        var result = _sut.IsAudioOnly(
            m3uAttributes: null,
            mimeType: "video/mp4",
            tracks: Array.Empty<TrackInfo>(),
            groupTitle: null);

        result.Should().BeFalse();
    }

    // ── Signal 3: track list ───────────────────────────────────────────────

    [Fact]
    public void IsAudioOnly_ReturnsTrue_WhenTracksContainOnlyAudioTracks()
    {
        var tracks = new[] { Audio(1), Audio(2) };

        var result = _sut.IsAudioOnly(
            m3uAttributes: null,
            mimeType: null,
            tracks: tracks,
            groupTitle: null);

        result.Should().BeTrue();
    }

    [Fact]
    public void IsAudioOnly_ReturnsFalse_WhenTracksContainVideoTrack()
    {
        var tracks = new[] { Audio(), Video() };

        var result = _sut.IsAudioOnly(
            m3uAttributes: null,
            mimeType: null,
            tracks: tracks,
            groupTitle: null);

        result.Should().BeFalse();
    }

    [Fact]
    public void IsAudioOnly_ReturnsFalse_WhenTracksListIsEmpty()
    {
        // Empty track list means track signal is inconclusive — should not flip to true
        var result = _sut.IsAudioOnly(
            m3uAttributes: null,
            mimeType: null,
            tracks: Array.Empty<TrackInfo>(),
            groupTitle: null);

        result.Should().BeFalse();
    }

    [Fact]
    public void IsAudioOnly_ReturnsFalse_WhenTracksContainOnlySubtitleTracks()
    {
        // Subtitle-only tracks should not be treated as audio-only
        var tracks = new[] { Subtitle() };

        var result = _sut.IsAudioOnly(
            m3uAttributes: null,
            mimeType: null,
            tracks: tracks,
            groupTitle: null);

        result.Should().BeFalse();
    }

    // ── Signal 4: group-title keyword ──────────────────────────────────────

    [Fact]
    public void IsAudioOnly_ReturnsTrue_WhenGroupTitleContainsRadio()
    {
        var result = _sut.IsAudioOnly(
            m3uAttributes: null,
            mimeType: null,
            tracks: Array.Empty<TrackInfo>(),
            groupTitle: "Radio Stations");

        result.Should().BeTrue();
    }

    [Fact]
    public void IsAudioOnly_ReturnsTrue_WhenGroupTitleContainsRadioCaseInsensitive()
    {
        var result = _sut.IsAudioOnly(
            m3uAttributes: null,
            mimeType: null,
            tracks: Array.Empty<TrackInfo>(),
            groupTitle: "RADIO FM");

        result.Should().BeTrue();
    }

    // ── Defensive / all-null / all-empty ──────────────────────────────────

    [Fact]
    public void IsAudioOnly_ReturnsFalse_WhenAllInputsAreNull()
    {
        var result = _sut.IsAudioOnly(
            m3uAttributes: null,
            mimeType: null,
            tracks: Array.Empty<TrackInfo>(),
            groupTitle: null);

        result.Should().BeFalse();
    }

    [Fact]
    public void IsAudioOnly_ReturnsFalse_WhenAllInputsAreEmptyStrings()
    {
        var result = _sut.IsAudioOnly(
            m3uAttributes: string.Empty,
            mimeType: string.Empty,
            tracks: Array.Empty<TrackInfo>(),
            groupTitle: string.Empty);

        result.Should().BeFalse();
    }

    // ── Normal video stream ────────────────────────────────────────────────

    [Fact]
    public void IsAudioOnly_ReturnsFalse_WhenVideoTracksArePresent()
    {
        var tracks = new[] { Audio(), Video() };

        var result = _sut.IsAudioOnly(
            m3uAttributes: "tvg-id=\"sports\"",
            mimeType: "video/mp4",
            tracks: tracks,
            groupTitle: "Sports");

        result.Should().BeFalse();
    }

    // ── Mixed signals ─────────────────────────────────────────────────────

    [Fact]
    public void IsAudioOnly_ReturnsTrue_WhenGroupTitleSaysRadioButVideoTracksPresent()
    {
        // Signal 4 (group-title) fires AFTER signal 3 (tracks).
        // Signal 3: tracks has video → does NOT return true.
        // Signal 4: groupTitle contains "radio" → returns true.
        // Actual priority: M3U attr → MIME → tracks → group-title.
        // Tracks signal only fires when tracks.Count > 0 AND all are Audio.
        // Here tracks has a Video track, so signal 3 is false.
        // Signal 4 fires and wins.
        var tracks = new[] { Audio(), Video() };

        var result = _sut.IsAudioOnly(
            m3uAttributes: null,
            mimeType: null,
            tracks: tracks,
            groupTitle: "Radio Stations");

        result.Should().BeTrue();
    }

    [Fact]
    public void IsAudioOnly_ReturnsTrue_WhenM3UAttributeSignalTakesPriorityOverEmptyTracks()
    {
        var result = _sut.IsAudioOnly(
            m3uAttributes: "radio=\"true\"",
            mimeType: null,
            tracks: Array.Empty<TrackInfo>(),
            groupTitle: null);

        result.Should().BeTrue();
    }
}
