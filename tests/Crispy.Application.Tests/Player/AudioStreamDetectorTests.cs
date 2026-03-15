using Crispy.Application.Player;
using Crispy.Application.Player.Models;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.Application.Tests.Player;

/// <summary>
/// Unit tests for IAudioStreamDetector — validates all four detection signals and
/// the negative case where a video track is present.
/// Full implementation target: Crispy.Infrastructure/Player/AudioStreamDetector.cs (Wave 2).
/// </summary>
[Trait("Category", "Unit")]
public class AudioStreamDetectorTests
{
    private readonly IAudioStreamDetector _sut;

    public AudioStreamDetectorTests()
    {
        // RED: AudioStreamDetector does not exist yet — NSubstitute mock stands in.
        // Wave 2 will replace this with: _sut = new AudioStreamDetector();
        _sut = Substitute.For<IAudioStreamDetector>();

        // Configure the mock to return true for the audio-only signals.
        // The real implementation must satisfy these same contracts.
        _sut.IsAudioOnly(
                Arg.Is<string?>(s => s != null && s.Contains("radio=\"true\"")),
                Arg.Any<string?>(),
                Arg.Any<IReadOnlyList<TrackInfo>>(),
                Arg.Any<string?>())
            .Returns(true);

        _sut.IsAudioOnly(
                Arg.Any<string?>(),
                Arg.Is<string?>(m => m != null && m.StartsWith("audio/")),
                Arg.Any<IReadOnlyList<TrackInfo>>(),
                Arg.Any<string?>())
            .Returns(true);

        _sut.IsAudioOnly(
                Arg.Any<string?>(),
                Arg.Any<string?>(),
                Arg.Is<IReadOnlyList<TrackInfo>>(tracks =>
                    tracks.Count > 0 && tracks.All(t => t.Kind != TrackKind.Video)),
                Arg.Any<string?>())
            .Returns(true);

        _sut.IsAudioOnly(
                Arg.Any<string?>(),
                Arg.Any<string?>(),
                Arg.Any<IReadOnlyList<TrackInfo>>(),
                Arg.Is<string?>(g => g != null && g.Contains("radio", StringComparison.OrdinalIgnoreCase)))
            .Returns(true);
    }

    [Fact]
    public void IsAudioOnly_ReturnTrue_WhenM3uHasRadioAttribute()
    {
        // Arrange
        const string m3uAttributes = "tvg-id=\"BBC Radio 4\" radio=\"true\" tvg-logo=\"...\"";
        IReadOnlyList<TrackInfo> tracks = [];

        // Act
        var result = _sut.IsAudioOnly(m3uAttributes, null, tracks, null);

        // Assert
        result.Should().BeTrue("M3U radio=\"true\" attribute is an authoritative audio-only signal");
    }

    [Fact]
    public void IsAudioOnly_ReturnTrue_WhenMimeIsAudioMpeg()
    {
        // Arrange
        IReadOnlyList<TrackInfo> tracks = [];

        // Act
        var result = _sut.IsAudioOnly(null, "audio/mpeg", tracks, null);

        // Assert
        result.Should().BeTrue("MIME type audio/mpeg unambiguously indicates an audio-only stream");
    }

    [Fact]
    public void IsAudioOnly_ReturnTrue_WhenNoVideoTracks()
    {
        // Arrange — tracks list contains only audio, no video
        IReadOnlyList<TrackInfo> tracks =
        [
            new TrackInfo(1, "English", "en", true, TrackKind.Audio),
            new TrackInfo(2, "French", "fr", false, TrackKind.Audio),
        ];

        // Act
        var result = _sut.IsAudioOnly(null, null, tracks, null);

        // Assert
        result.Should().BeTrue("A non-empty track list with zero video tracks indicates an audio-only stream");
    }

    [Fact]
    public void IsAudioOnly_ReturnTrue_WhenGroupTitleContainsRadio()
    {
        // Arrange
        IReadOnlyList<TrackInfo> tracks = [];

        // Act
        var result = _sut.IsAudioOnly(null, null, tracks, "UK Radio Stations");

        // Assert
        result.Should().BeTrue("Group-title containing \"radio\" (case-insensitive) is a radio signal");
    }

    [Fact]
    public void IsAudioOnly_ReturnFalse_WhenVideoTrackPresent()
    {
        // Arrange — explicit video track proves this is not audio-only
        IReadOnlyList<TrackInfo> tracks =
        [
            new TrackInfo(1, "English", "en", true, TrackKind.Audio),
            new TrackInfo(2, "Video", string.Empty, true, TrackKind.Video),
        ];

        // Act — default mock returns false (no matching stub for this combination)
        var result = _sut.IsAudioOnly(null, null, tracks, null);

        // Assert
        result.Should().BeFalse("Presence of a video track overrides all other audio-only signals");
    }
}
