using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.UI.Tests.Helpers;
using Crispy.UI.ViewModels;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.ViewModels;

/// <summary>
/// Unit tests for TrackSelectorViewModel — verifies that UpdateFromState populates
/// tracks and that track/speed selection calls the service.
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
    public void AudioTracks_Populated_AfterUpdateFromState()
    {
        // Arrange
        var state = PlayerState.Empty with { AudioTracks = SampleAudioTracks };

        // Act — UpdateFromState is called when the player emits a new state
        _sut.UpdateFromState(state);

        // Assert
        _sut.AudioTracks.Should().HaveCount(SampleAudioTracks.Count,
            "AudioTracks must be populated from PlayerState.AudioTracks via UpdateFromState");
        _sut.AudioTracks.Should().Contain(t => t.Language == "en",
            "The English audio track must appear in the ViewModel collection");
    }

    [Fact]
    public async Task SelectAudioTrack_CallsSetAudioTrackAsync()
    {
        // Arrange — populate tracks first
        _sut.UpdateFromState(PlayerState.Empty with { AudioTracks = SampleAudioTracks });
        var track = SampleAudioTracks[1]; // French track

        // Act
        await _sut.SelectAudioTrackCommand.ExecuteAsync(track);

        // Assert
        await _playerService.Received(1).SetAudioTrackAsync(track.Id);
    }

    [Fact]
    public void SpeedOptions_AlwaysContainFullPresetList()
    {
        // SpeedOptions is always the full list — the View hides the speed section
        // when IsLive=true (see TrackSelectorView.axaml !IsLive binding).
        // The ViewModel exposes all presets and lets the View decide visibility.
        _sut.SpeedOptions.Should().HaveCount(6,
            "SpeedOptions must always expose all 6 preset values (0.5x–2.0x); " +
            "the View hides the section for live TV via IsLive binding");
    }

    [Fact]
    public void IsLive_IsTrue_WhenStateIsLive()
    {
        // Arrange
        var liveState = PlayerState.Empty with { Mode = PlaybackMode.Live, IsLive = true };

        // Act
        _sut.UpdateFromState(liveState);

        // Assert
        _sut.IsLive.Should().BeTrue(
            "IsLive must be set from PlayerState so the View can hide the speed section");
    }

    [Fact]
    public void SelectedAudioTrack_IsSetToActiveTrack_AfterUpdateFromState()
    {
        // Arrange — English track is IsSelected=true
        var state = PlayerState.Empty with { AudioTracks = SampleAudioTracks };

        // Act
        _sut.UpdateFromState(state);

        // Assert
        _sut.SelectedAudioTrack.Should().NotBeNull();
        _sut.SelectedAudioTrack!.Language.Should().Be("en",
            "SelectedAudioTrack must be set to the currently active track");
    }
}
