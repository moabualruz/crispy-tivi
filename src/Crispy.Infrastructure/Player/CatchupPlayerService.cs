using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.Domain.Entities;
using Crispy.Domain.Enums;

using ApplicationContentType = Crispy.Application.Player.Models.ContentType;

using Microsoft.Extensions.Logging;

namespace Crispy.Infrastructure.Player;

/// <summary>
/// Wraps IPlayerService.PlayAsync with catchup URL resolution (PLR-34/35/36).
/// Validates eligibility before resolving the URL and delegates playback to
/// the underlying IPlayerService.
/// </summary>
public sealed class CatchupPlayerService
{
    private readonly IPlayerService _player;
    private readonly ILogger<CatchupPlayerService> _logger;

    public CatchupPlayerService(IPlayerService player, ILogger<CatchupPlayerService> logger)
    {
        _player = player;
        _logger = logger;
    }

    /// <summary>
    /// Starts catchup playback for a specific programme window on the given channel.
    /// </summary>
    /// <param name="channel">Channel with catchup configuration.</param>
    /// <param name="streamUrl">Base stream URL (used for Xtream/Stalker URL construction).</param>
    /// <param name="programmeStart">UTC start time of the programme.</param>
    /// <param name="programmeEnd">UTC end time of the programme.</param>
    /// <param name="username">Xtream/Stalker username (may be null for template-based sources).</param>
    /// <param name="password">Xtream/Stalker password (may be null for template-based sources).</param>
    /// <param name="ct">Cancellation token.</param>
    /// <exception cref="InvalidOperationException">
    /// When the programme is not eligible for catchup (future event or outside catchup window).
    /// </exception>
    public async Task PlayCatchupAsync(
        Channel channel,
        string streamUrl,
        DateTimeOffset programmeStart,
        DateTimeOffset programmeEnd,
        string? username = null,
        string? password = null,
        CancellationToken ct = default)
    {
        // PLR-36: validate entry is in past AND within channel.CatchupDays window
        ValidateEligibility(channel, programmeStart);

        var catchupUrl = ResolveCatchupUrl(channel, streamUrl, programmeStart, programmeEnd, username, password);

        _logger.LogInformation(
            "Catchup: channel={Channel} type={Type} url={Url}",
            channel.Title, channel.CatchupType, catchupUrl);

        var request = new PlaybackRequest(
            Url: catchupUrl,
            ContentType: ApplicationContentType.LiveTv,
            Title: channel.Title,
            ChannelLogoUrl: channel.TvgLogo,
            ResumeAt: TimeSpan.Zero);

        await _player.PlayAsync(request, ct).ConfigureAwait(false);
    }

    /// <summary>
    /// Resolves the catchup URL for a given channel and time window.
    /// Implements PLR-34 (Xtream), PLR-35 (Stalker/Append), and template substitution.
    /// </summary>
    public string ResolveCatchupUrl(
        Channel channel,
        string streamUrl,
        DateTimeOffset start,
        DateTimeOffset end,
        string? username,
        string? password)
    {
        return channel.CatchupType switch
        {
            // PLR-34: Xtream format
            // {base}/timeshift/{user}/{pass}/{duration_min}/{start_utc}/{stream_id}.ts
            CatchupType.Xc => BuildXtreamCatchupUrl(streamUrl, start, end, username, password),

            // PLR-35: Stalker / Append format — append ?utc={start}&lutc={end} to stream URL
            CatchupType.Append => BuildStalkerCatchupUrl(streamUrl, start, end),

            // Default / Flussonic / Shift: use the template from channel.CatchupSource
            CatchupType.Default or CatchupType.Flussonic or CatchupType.Shift
                when !string.IsNullOrEmpty(channel.CatchupSource) =>
                SubstitutePlaceholders(channel.CatchupSource, start, end),

            CatchupType.None => throw new InvalidOperationException(
                $"Channel '{channel.Title}' has no catchup support (CatchupType.None)."),

            _ => throw new InvalidOperationException(
                $"Cannot resolve catchup URL for channel '{channel.Title}' with type {channel.CatchupType}."),
        };
    }

    // PLR-36: validate that the programme is in the past and within the catchup window
    private static void ValidateEligibility(Channel channel, DateTimeOffset programmeStart)
    {
        var now = DateTimeOffset.UtcNow;

        if (programmeStart >= now)
        {
            throw new InvalidOperationException(
                $"Programme has not started yet (starts {programmeStart:u}). Catchup is only available for past programmes.");
        }

        var cutoff = now - TimeSpan.FromDays(Math.Max(channel.CatchupDays, 1));
        if (programmeStart < cutoff)
        {
            throw new InvalidOperationException(
                $"Programme started {programmeStart:u} which is outside the {channel.CatchupDays}-day catchup window.");
        }
    }

    // PLR-34: {base}/timeshift/{user}/{pass}/{duration_min}/{start_utc}/{stream_id}.ts
    private static string BuildXtreamCatchupUrl(
        string streamUrl,
        DateTimeOffset start,
        DateTimeOffset end,
        string? username,
        string? password)
    {
        // Extract base URL and stream ID from the stream URL
        // Expected format: {base}/live/{user}/{pass}/{streamId}.{ext}
        var uri = new Uri(streamUrl);
        var baseUrl = $"{uri.Scheme}://{uri.Authority}";
        var segments = uri.AbsolutePath.TrimStart('/').Split('/');

        // Stream ID is typically the last path segment without extension
        var streamId = Path.GetFileNameWithoutExtension(segments.LastOrDefault() ?? "0");

        var durationMinutes = (long)Math.Ceiling((end - start).TotalMinutes);
        var startUtc = start.UtcDateTime.ToString("yyyy-MM-dd_HH-mm-ss");

        var user = username ?? (segments.Length >= 3 ? segments[1] : "user");
        var pass = password ?? (segments.Length >= 3 ? segments[2] : "pass");

        return $"{baseUrl}/timeshift/{user}/{pass}/{durationMinutes}/{startUtc}/{streamId}.ts";
    }

    // PLR-35: append ?utc={start_unix}&lutc={end_unix} to stream URL
    private static string BuildStalkerCatchupUrl(string streamUrl, DateTimeOffset start, DateTimeOffset end)
    {
        var sep = streamUrl.Contains('?') ? '&' : '?';
        return $"{streamUrl}{sep}utc={start.ToUnixTimeSeconds()}&lutc={end.ToUnixTimeSeconds()}";
    }

    private static string SubstitutePlaceholders(string template, DateTimeOffset start, DateTimeOffset end)
    {
        var duration = (long)(end - start).TotalSeconds;
        var startUnix = start.ToUnixTimeSeconds();
        var endUnix = end.ToUnixTimeSeconds();
        var startUtc = start.UtcDateTime;

        return template
            .Replace("{start}", startUnix.ToString(), StringComparison.Ordinal)
            .Replace("{end}", endUnix.ToString(), StringComparison.Ordinal)
            .Replace("{duration}", duration.ToString(), StringComparison.Ordinal)
            .Replace("{utcstart}", startUtc.ToString("yyyyMMddHHmmss"), StringComparison.Ordinal)
            .Replace("{utcend}", end.UtcDateTime.ToString("yyyyMMddHHmmss"), StringComparison.Ordinal)
            .Replace("{lutcstart}", startUnix.ToString(), StringComparison.Ordinal)
            .Replace("{lutcend}", endUnix.ToString(), StringComparison.Ordinal)
            .Replace("{Y}", startUtc.ToString("yyyy"), StringComparison.Ordinal)
            .Replace("{m}", startUtc.ToString("MM"), StringComparison.Ordinal)
            .Replace("{d}", startUtc.ToString("dd"), StringComparison.Ordinal)
            .Replace("{H}", startUtc.ToString("HH"), StringComparison.Ordinal)
            .Replace("{M}", startUtc.ToString("mm"), StringComparison.Ordinal)
            .Replace("{S}", startUtc.ToString("ss"), StringComparison.Ordinal);
    }
}
