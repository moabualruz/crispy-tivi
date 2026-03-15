using AVFoundation;

using Crispy.Application.Player;

using MediaPlayer;

using Microsoft.Extensions.Logging;

namespace Crispy.iOS.Services;

/// <summary>
/// IMediaSessionService implementation for iOS.
/// Configures AVAudioSession for background audio playback and updates
/// MPNowPlayingInfoCenter for the lock-screen Now Playing widget.
/// Wires MPRemoteCommandCenter for lock-screen transport controls.
///
/// Requires Info.plist entry:
///   UIBackgroundModes = [audio]
/// </summary>
public sealed class IosMediaSessionBridge : IMediaSessionService
{
    private readonly IPlayerService _player;
    private readonly ILogger<IosMediaSessionBridge> _logger;
    private readonly HttpClient _httpClient;
    private bool _commandsRegistered;

    public IosMediaSessionBridge(
        IPlayerService player,
        ILogger<IosMediaSessionBridge> logger,
        HttpClient httpClient)
    {
        _player = player;
        _logger = logger;
        _httpClient = httpClient;
    }

    /// <inheritdoc />
    public async Task UpdateNowPlayingAsync(
        string title,
        string? artist,
        string? artworkUrl,
        bool isPlaying)
    {
        // Activate AVAudioSession for background audio
        var session = AVAudioSession.SharedInstance();
        session.SetCategory(AVAudioSessionCategory.Playback, out var setCategoryError);
        if (setCategoryError != null)
        {
            _logger.LogWarning("AVAudioSession SetCategory error: {Err}", setCategoryError.LocalizedDescription);
        }

        session.SetActive(true, out var setActiveError);
        if (setActiveError != null)
        {
            _logger.LogWarning("AVAudioSession SetActive error: {Err}", setActiveError.LocalizedDescription);
        }

        // Build Now Playing info dictionary
        var info = new MPNowPlayingInfo
        {
            Title = title,
            Artist = artist ?? string.Empty,
            PlaybackRate = isPlaying ? 1.0 : 0.0,
            ElapsedPlaybackTime = _player.State.Position.TotalSeconds,
        };

        // Load artwork asynchronously
        if (!string.IsNullOrEmpty(artworkUrl))
        {
            try
            {
                var bytes = await _httpClient.GetByteArrayAsync(artworkUrl).ConfigureAwait(false);
                using var nsData = Foundation.NSData.FromArray(bytes);
                using var uiImage = UIKit.UIImage.LoadFromData(nsData);
                if (uiImage != null)
                {
                    info.Artwork = new MPMediaItemArtwork(uiImage.Size, _ => uiImage);
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to load iOS artwork from {Url}", artworkUrl);
            }
        }

        MPNowPlayingInfoCenter.DefaultCenter.NowPlayingInfo = info;

        // Register remote command handlers once
        if (!_commandsRegistered)
        {
            RegisterRemoteCommands();
            _commandsRegistered = true;
        }
    }

    /// <inheritdoc />
    public Task ClearAsync()
    {
        MPNowPlayingInfoCenter.DefaultCenter.NowPlayingInfo = null;

        var session = AVAudioSession.SharedInstance();
        session.SetActive(false, out _);

        return Task.CompletedTask;
    }

    private void RegisterRemoteCommands()
    {
        var commandCenter = MPRemoteCommandCenter.Shared;

        commandCenter.PlayCommand.Enabled = true;
        commandCenter.PlayCommand.AddTarget(_ =>
        {
            _ = _player.ResumeAsync();
            return MPRemoteCommandHandlerStatus.Success;
        });

        commandCenter.PauseCommand.Enabled = true;
        commandCenter.PauseCommand.AddTarget(_ =>
        {
            _ = _player.PauseAsync();
            return MPRemoteCommandHandlerStatus.Success;
        });

        // NextTrack = channel up, PreviousTrack = channel down
        commandCenter.NextTrackCommand.Enabled = true;
        commandCenter.NextTrackCommand.AddTarget(_ => MPRemoteCommandHandlerStatus.Success);

        commandCenter.PreviousTrackCommand.Enabled = true;
        commandCenter.PreviousTrackCommand.AddTarget(_ => MPRemoteCommandHandlerStatus.Success);
    }
}
