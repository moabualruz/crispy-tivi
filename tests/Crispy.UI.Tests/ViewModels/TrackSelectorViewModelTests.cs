using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.UI.Tests.Helpers;
using Crispy.UI.ViewModels;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.ViewModels;

/// <summary>
/// Unit tests for TrackSelectorViewModel — verifies that the popover is populated
/// from IPlayerService tracks and that track/speed selection calls the service.
/// Full implementation target: Wave 2 (03-02).
/// </summary>
[Trait("Category", "Unit")]
public class TrackSelectorViewModelTests
{
    private readonly IPlayerService _playerService;
    private readonly TrackSelectorViewModel _sut;

    private static readonly IReadOnlyList<TrackInfo> SampleAudioTracks =
    [
        new TrackInfo(1, "English AC3", "en", true, TrackKind.Audio),
        new TrackInfo(2, "French Stereo", "fr", false, TrackKind.Audio),
    ];

    public TrackSelectorViewModelTests()
    {
        _playerService = Substitute.For<IPlayerService>();
        _playerService.State.Returns(PlayerState.Empty);
        _playerService.StateChanged.Returns(new TestSubject<PlayerState>());
        _playerService.AudioSamples.Returns(new TestSubject<float[]>());
        _playerService.AudioTracks.Returns(SampleAudioTracks);
        _playerService.SubtitleTracks.Returns([]);

        _sut = new TrackSelectorViewModel(_playerService);
    }

    [Fact]
    public void AudioTracks_Populated_FromPlayerServiceTracks()
    {
        // RED: Wave 2 must copy IPlayerService.AudioTracks into the ViewModel's
        // ObservableCollection during initialisation.
        _sut.AudioTracks.Should().HaveCount(SampleAudioTracks.Count,
            "AudioTracks must be populated from IPlayerService.AudioTracks on construction");

        _sut.AudioTracks.Should().Contain(t => t.Language == "en",
            "The English audio track from the service must appear in the ViewModel collection");
    }

    [Fact]
    public async Task SelectAudioTrack_CallsSetAudioTrackAsync()
    {
        // Arrange
        var track = SampleAudioTracks[1]; // French track

        // Act
        await _sut.SelectAudioTrackCommand.ExecuteAsync(track);

        // RED: the stub command does nothing — Wave 2 must call the service
        await _playerService.Received(1).SetAudioTrackAsync(track.Id);
    }

    [Fact]
    public void SpeedOptions_DoNotIncludeValues_WhenIsLive()
    {
        // Arrange — live state
        var liveState = PlayerState.Empty with
        {
            Mode = PlaybackMode.Live,
            IsLive = true,
        };

        _playerService.State.Returns(liveState);

        // Recreate ViewModel so it initialises with the live state
        var sut = new TrackSelectorViewModel(_playerService);

        // RED: SpeedOptions will be populated until Wave 2 conditionally hides them for live
        sut.SpeedOptions.Should().BeEmpty(
            "Speed options must not be shown for live streams — changing playback rate on a live stream is meaningless");
    }
}
