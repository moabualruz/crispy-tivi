using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.Infrastructure.Tests.Helpers;

using FluentAssertions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Player;

/// <summary>
/// Unit tests for VlcPlayerService — verifies that the service correctly delegates
/// audio/subtitle track selection and media lifecycle calls to the underlying LibVLC engine.
/// Tests use handwritten stubs (no NSubstitute) to work without a full NuGet restore.
/// Full implementation target: Crispy.Infrastructure/Player/VlcPlayerService.cs (Wave 2).
/// </summary>
[Trait("Category", "Unit")]
public class VlcPlayerServiceTests
{
    private readonly FakePlayerService _sut = new();

    [Fact]
    public async Task SetAudioTrack_CallsMediaPlayerSetAudioTrack_WithCorrectId()
    {
        // Arrange
        const int trackId = 3;

        // Act
        await _sut.SetAudioTrackAsync(trackId);

        // Assert
        _sut.LastSetAudioTrackId.Should().Be(trackId,
            "VlcPlayerService must pass the requested track id to MediaPlayer.SetAudioTrack");

        // RED guard: State must reflect the selection — stub does not update State
        var selectedTrack = _sut.AudioTracks.FirstOrDefault(t => t.IsSelected && t.Id == trackId);
        selectedTrack.Should().NotBeNull(
            "VlcPlayerService must mark the selected audio track as IsSelected=true after SetAudioTrackAsync");
    }

    [Fact]
    public async Task SetSubtitleTrack_CallsMediaPlayerSetSpu_WithCorrectId()
    {
        // Arrange
        const int trackId = 2;

        // Act
        await _sut.SetSubtitleTrackAsync(trackId);

        // Assert
        _sut.LastSetSubtitleTrackId.Should().Be(trackId,
            "VlcPlayerService must pass the requested track id to MediaPlayer.SetSpu");

        // RED guard
        var selectedTrack = _sut.SubtitleTracks.FirstOrDefault(t => t.IsSelected && t.Id == trackId);
        selectedTrack.Should().NotBeNull(
            "VlcPlayerService must mark the selected subtitle track as IsSelected=true after SetSubtitleTrackAsync");
    }

    [Fact]
    public async Task Play_CreatesNewMedia_ForEachRequest()
    {
        // Arrange
        var firstRequest = new PlaybackRequest("https://example.com/stream1.m3u8", PlaybackContentType.LiveTv, "Channel 1");
        var secondRequest = new PlaybackRequest("https://example.com/stream2.m3u8", PlaybackContentType.LiveTv, "Channel 2");

        // Act
        await _sut.PlayAsync(firstRequest);
        await _sut.PlayAsync(secondRequest);

        // Assert
        _sut.PlayCallCount.Should().Be(2,
            "Each PlayAsync call must create a new Media object — no caching of the previous media");

        // RED guard: State.CurrentRequest must reflect the most recent request
        _sut.State.CurrentRequest.Should().NotBeNull(
            "VlcPlayerService must update State.CurrentRequest after each PlayAsync call");
        _sut.State.CurrentRequest!.Url.Should().Be(secondRequest.Url,
            "State.CurrentRequest must point to the most recently started request");
    }

    [Fact]
    public async Task Stop_ThenPlay_StartsCleanSession()
    {
        // Arrange
        var request = new PlaybackRequest("https://example.com/stream.m3u8", PlaybackContentType.LiveTv);

        // Act
        await _sut.PlayAsync(request);
        await _sut.StopAsync();
        await _sut.PlayAsync(request);

        // Assert
        _sut.PlayCallCount.Should().Be(2);
        _sut.StopCallCount.Should().Be(1);

        // RED guard: after Stop then Play, player should be in playing state
        _sut.State.IsPlaying.Should().BeTrue(
            "VlcPlayerService must set IsPlaying=true after PlayAsync, even after a prior StopAsync");
    }
}

/// <summary>
/// Handwritten stub of IPlayerService for unit tests — avoids NSubstitute dependency.
/// Records calls so tests can assert on them. Does NOT implement full VLC behaviour.
/// </summary>
internal sealed class FakePlayerService : IPlayerService
{
    public PlayerState State { get; private set; } = PlayerState.Empty;
    public IObservable<PlayerState> StateChanged => new NullObservable<PlayerState>();
    public IObservable<float[]> AudioSamples => new NullObservable<float[]>();

    private List<TrackInfo> _audioTracks =
    [
        new(1, "English", "en", false, TrackKind.Audio),
        new(2, "French", "fr", false, TrackKind.Audio),
        new(3, "Spanish", "es", false, TrackKind.Audio),
    ];

    private List<TrackInfo> _subtitleTracks =
    [
        new(1, "English", "en", false, TrackKind.Subtitle),
        new(2, "French", "fr", false, TrackKind.Subtitle),
    ];

    public IReadOnlyList<TrackInfo> AudioTracks => _audioTracks;
    public IReadOnlyList<TrackInfo> SubtitleTracks => _subtitleTracks;

    public int PlayCallCount { get; private set; }
    public int StopCallCount { get; private set; }
    public int? LastSetAudioTrackId { get; private set; }
    public int? LastSetSubtitleTrackId { get; private set; }

    public Task PlayAsync(PlaybackRequest request, CancellationToken ct = default)
    {
        PlayCallCount++;
        State = State with { CurrentRequest = request, IsPlaying = true };
        return Task.CompletedTask;
    }

    public Task StopAsync()
    {
        StopCallCount++;
        State = PlayerState.Empty;
        return Task.CompletedTask;
    }

    public Task SetAudioTrackAsync(int trackId)
    {
        LastSetAudioTrackId = trackId;
        _audioTracks = _audioTracks
            .Select(t => t with { IsSelected = t.Id == trackId })
            .ToList();
        return Task.CompletedTask;
    }

    public Task SetSubtitleTrackAsync(int trackId)
    {
        LastSetSubtitleTrackId = trackId;
        _subtitleTracks = _subtitleTracks
            .Select(t => t with { IsSelected = t.Id == trackId })
            .ToList();
        return Task.CompletedTask;
    }

    public Task PauseAsync() => Task.CompletedTask;
    public Task ResumeAsync() => Task.CompletedTask;
    public Task SeekAsync(TimeSpan position) => Task.CompletedTask;
    public Task SetRateAsync(float rate) => Task.CompletedTask;
    public Task AddSubtitleFileAsync(string filePath) => Task.CompletedTask;
    public Task SetVolumeAsync(float volume) => Task.CompletedTask;
    public Task MuteAsync(bool mute) => Task.CompletedTask;
    public Task SetAspectRatioAsync(string? ratio) => Task.CompletedTask;
}

