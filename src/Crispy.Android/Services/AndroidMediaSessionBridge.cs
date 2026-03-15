using Android.App;
using Android.Content;
using Android.Graphics;
using Android.Media;
using Android.Media.Session;
using Android.OS;

using Crispy.Application.Player;

using Microsoft.Extensions.Logging;

namespace Crispy.Android.Services;

/// <summary>
/// IMediaSessionService implementation for Android.
/// Creates a MediaSession that drives:
///  - The lock-screen Now Playing display
///  - Android media notification artwork and controls
///  - AVRCP Bluetooth remote control (handled automatically by MediaSession)
/// </summary>
public sealed class AndroidMediaSessionBridge : IMediaSessionService, IDisposable
{
    private readonly MediaSession _session;
    private readonly ILogger<AndroidMediaSessionBridge> _logger;
    private readonly HttpClient _httpClient;
    private bool _disposed;

    public AndroidMediaSessionBridge(
        Context context,
        ILogger<AndroidMediaSessionBridge> logger,
        HttpClient httpClient)
    {
        _logger = logger;
        _httpClient = httpClient;

        _session = new MediaSession(context, "CrispyTivi");
        _session.SetFlags(
            (int)(MediaSessionFlags.HandlesMediaButtons |
                  MediaSessionFlags.HandlesTransportControls));
        _session.Active = true;
    }

    /// <inheritdoc />
    public async Task UpdateNowPlayingAsync(
        string title,
        string? artist,
        string? artworkUrl,
        bool isPlaying)
    {
        if (_disposed)
        {
            return;
        }

        Bitmap? artwork = null;
        if (!string.IsNullOrEmpty(artworkUrl))
        {
            try
            {
                var bytes = await _httpClient.GetByteArrayAsync(artworkUrl).ConfigureAwait(false);
                artwork = await BitmapFactory.DecodeByteArrayAsync(bytes, 0, bytes.Length).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to load artwork from {Url}", artworkUrl);
            }
        }

        var metadataBuilder = new MediaMetadata.Builder()
            .PutString(MediaMetadata.MetadataKeyTitle, title)
            .PutString(MediaMetadata.MetadataKeyArtist, artist ?? string.Empty);

        if (artwork != null)
        {
            metadataBuilder.PutBitmap(MediaMetadata.MetadataKeyAlbumArt, artwork);
        }

        _session.SetMetadata(metadataBuilder.Build());

        var stateBuilder = new PlaybackState.Builder()
            .SetActions(
                PlaybackState.ActionPlay |
                PlaybackState.ActionPause |
                PlaybackState.ActionStop |
                PlaybackState.ActionSkipToNext |
                PlaybackState.ActionSkipToPrevious)
            .SetState(
                isPlaying ? PlaybackStateCode.Playing : PlaybackStateCode.Paused,
                PlaybackState.PlaybackPositionUnknown,
                1.0f);

        _session.SetPlaybackState(stateBuilder.Build());
    }

    /// <inheritdoc />
    public Task ClearAsync()
    {
        if (!_disposed)
        {
            _session.Active = false;
        }

        return Task.CompletedTask;
    }

    /// <inheritdoc />
    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        _session.Release();
        _session.Dispose();
    }
}
