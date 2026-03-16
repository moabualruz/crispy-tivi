using Crispy.Application.Player.Models;
using Crispy.Domain.Enums;
using FluentAssertions;
using Xunit;

namespace Crispy.Application.Tests.Player.Models;

// =============================================================================
// Bookmark
// =============================================================================

[Trait("Category", "Unit")]
public sealed class BookmarkTests
{
    [Fact]
    public void Bookmark_StoresRequiredProperties_WhenConstructed()
    {
        var bookmark = new Bookmark
        {
            Id = "bm-1",
            ContentId = "ch-42",
            Label = "Great moment",
            ProfileId = "profile-1",
        };

        bookmark.Id.Should().Be("bm-1");
        bookmark.ContentId.Should().Be("ch-42");
        bookmark.Label.Should().Be("Great moment");
        bookmark.ProfileId.Should().Be("profile-1");
    }

    [Fact]
    public void Bookmark_DefaultsToChannelContentType_WhenNotSet()
    {
        var bookmark = new Bookmark
        {
            Id = "bm-2",
            ContentId = "ch-1",
            Label = "Start",
            ProfileId = "p-1",
        };

        bookmark.ContentType.Should().Be(ContentType.Channel);
    }

    [Fact]
    public void Bookmark_StoresAllContentTypeValues()
    {
        foreach (var ct in Enum.GetValues<ContentType>())
        {
            var bookmark = new Bookmark
            {
                Id = "bm-x",
                ContentId = "c-1",
                Label = "L",
                ProfileId = "p-1",
                ContentType = ct,
            };
            bookmark.ContentType.Should().Be(ct);
        }
    }

    [Fact]
    public void Bookmark_StoresPositionMsAndTimestamps()
    {
        var now = DateTimeOffset.UtcNow;
        var bookmark = new Bookmark
        {
            Id = "bm-3",
            ContentId = "movie-7",
            Label = "Climax",
            ProfileId = "p-2",
            PositionMs = 90_000L,
            CreatedAt = now,
        };

        bookmark.PositionMs.Should().Be(90_000L);
        bookmark.CreatedAt.Should().Be(now);
    }
}

// =============================================================================
// QueueItem
// =============================================================================

[Trait("Category", "Unit")]
public sealed class QueueItemTests
{
    private static PlaybackRequest MakeRequest() =>
        new("https://stream.test/live.m3u8", PlaybackContentType.LiveTv);

    [Fact]
    public void QueueItem_StoresAllPositionalParameters()
    {
        var request = MakeRequest();
        var item = new QueueItem(
            "ep-1",
            "Episode 1",
            1,
            TimeSpan.FromMinutes(45),
            "https://thumb.test/1.jpg",
            request,
            false);

        item.Id.Should().Be("ep-1");
        item.Title.Should().Be("Episode 1");
        item.EpisodeNumber.Should().Be(1);
        item.Duration.Should().Be(TimeSpan.FromMinutes(45));
        item.ThumbnailUrl.Should().Be("https://thumb.test/1.jpg");
        item.Request.Should().BeSameAs(request);
        item.IsCurrentlyPlaying.Should().BeFalse();
    }

    [Fact]
    public void QueueItem_AllowsNullOptionalFields()
    {
        var item = new QueueItem("id-2", "Movie", null, TimeSpan.Zero, null, MakeRequest(), true);

        item.EpisodeNumber.Should().BeNull();
        item.ThumbnailUrl.Should().BeNull();
        item.IsCurrentlyPlaying.Should().BeTrue();
    }

    [Fact]
    public void QueueItem_RecordEquality_WhenSameValues()
    {
        var req = MakeRequest();
        var a = new QueueItem("id", "T", 1, TimeSpan.Zero, null, req, false);
        var b = new QueueItem("id", "T", 1, TimeSpan.Zero, null, req, false);

        a.Should().Be(b);
    }

    [Fact]
    public void QueueItem_RecordInequality_WhenDifferentId()
    {
        var req = MakeRequest();
        var a = new QueueItem("id-A", "T", 1, TimeSpan.Zero, null, req, false);
        var b = new QueueItem("id-B", "T", 1, TimeSpan.Zero, null, req, false);

        a.Should().NotBe(b);
    }
}

// =============================================================================
// Reminder
// =============================================================================

[Trait("Category", "Unit")]
public sealed class ReminderTests
{
    [Fact]
    public void Reminder_StoresRequiredProperties_WhenConstructed()
    {
        var reminder = new Reminder
        {
            Id = "rem-1",
            ProgramName = "News at 10",
            ChannelName = "BBC One",
            ProfileId = "profile-1",
        };

        reminder.Id.Should().Be("rem-1");
        reminder.ProgramName.Should().Be("News at 10");
        reminder.ChannelName.Should().Be("BBC One");
        reminder.ProfileId.Should().Be("profile-1");
    }

    [Fact]
    public void Reminder_DefaultsToFiredFalse()
    {
        var reminder = new Reminder
        {
            Id = "r",
            ProgramName = "Show",
            ChannelName = "CH",
            ProfileId = "p",
        };

        reminder.Fired.Should().BeFalse();
    }

    [Fact]
    public void Reminder_StoresToggledFiredTrue()
    {
        var reminder = new Reminder
        {
            Id = "r",
            ProgramName = "Show",
            ChannelName = "CH",
            ProfileId = "p",
            Fired = true,
        };

        reminder.Fired.Should().BeTrue();
    }

    [Fact]
    public void Reminder_StoresStartTimeAndNotifyAt()
    {
        var start = new DateTimeOffset(2026, 6, 1, 20, 0, 0, TimeSpan.Zero);
        var notify = start.AddMinutes(-5);

        var reminder = new Reminder
        {
            Id = "r",
            ProgramName = "Show",
            ChannelName = "CH",
            ProfileId = "p",
            StartTime = start,
            NotifyAt = notify,
        };

        reminder.StartTime.Should().Be(start);
        reminder.NotifyAt.Should().Be(notify);
    }

    [Fact]
    public void Reminder_StoresCreatedAt()
    {
        var now = new DateTimeOffset(2026, 3, 16, 10, 0, 0, TimeSpan.Zero);

        var reminder = new Reminder
        {
            Id = "r",
            ProgramName = "Show",
            ChannelName = "CH",
            ProfileId = "p",
            CreatedAt = now,
        };

        reminder.CreatedAt.Should().Be(now);
    }

    [Fact]
    public void Reminder_FiredCanBeSetToTrueAfterConstruction()
    {
        var reminder = new Reminder
        {
            Id = "r",
            ProgramName = "Show",
            ChannelName = "CH",
            ProfileId = "p",
        };

        reminder.Fired = true;

        reminder.Fired.Should().BeTrue();
    }
}

// =============================================================================
// StreamHealth
// =============================================================================

[Trait("Category", "Unit")]
public sealed class StreamHealthTests
{
    [Fact]
    public void StreamHealth_StoresRequiredUrlHash()
    {
        var health = new StreamHealth { UrlHash = "abc12345" };

        health.UrlHash.Should().Be("abc12345");
    }

    [Fact]
    public void StreamHealth_DefaultsToZeroCountsAndTimestamps()
    {
        var health = new StreamHealth { UrlHash = "h" };

        health.StallCount.Should().Be(0);
        health.BufferSum.Should().Be(0L);
        health.BufferSamples.Should().Be(0);
        health.TtffMs.Should().Be(0L);
    }

    [Fact]
    public void StreamHealth_StoresAllMetricFields()
    {
        var now = DateTimeOffset.UtcNow;
        var health = new StreamHealth
        {
            UrlHash = "deadbeef",
            StallCount = 3,
            BufferSum = 15_000L,
            BufferSamples = 5,
            TtffMs = 800L,
            LastSeen = now,
        };

        health.StallCount.Should().Be(3);
        health.BufferSum.Should().Be(15_000L);
        health.BufferSamples.Should().Be(5);
        health.TtffMs.Should().Be(800L);
        health.LastSeen.Should().Be(now);
    }
}

// =============================================================================
// PlaybackRequest
// =============================================================================

[Trait("Category", "Unit")]
public sealed class PlaybackRequestTests
{
    [Fact]
    public void PlaybackRequest_StoresUrlAndContentType()
    {
        var req = new PlaybackRequest("https://cdn.test/s.m3u8", PlaybackContentType.Vod);

        req.Url.Should().Be("https://cdn.test/s.m3u8");
        req.ContentType.Should().Be(PlaybackContentType.Vod);
    }

    [Fact]
    public void PlaybackRequest_DefaultsToNullOptionalFields()
    {
        var req = new PlaybackRequest("url", PlaybackContentType.LiveTv);

        req.Title.Should().BeNull();
        req.ChannelLogoUrl.Should().BeNull();
        req.HttpHeaders.Should().BeNull();
        req.UserAgent.Should().BeNull();
        req.JellyfinItemId.Should().BeNull();
    }

    [Fact]
    public void PlaybackRequest_DefaultsResumeAtToZero()
    {
        var req = new PlaybackRequest("url", PlaybackContentType.Radio);

        req.ResumeAt.Should().Be(TimeSpan.Zero);
    }

    [Fact]
    public void PlaybackRequest_DefaultsEnableTimeshiftToFalse()
    {
        var req = new PlaybackRequest("url", PlaybackContentType.LiveTv);

        req.EnableTimeshift.Should().BeFalse();
    }

    [Fact]
    public void PlaybackRequest_StoresAllOptionalFieldsWhenProvided()
    {
        var headers = new Dictionary<string, string> { ["X-Token"] = "abc" };
        var req = new PlaybackRequest(
            "url",
            PlaybackContentType.Vod,
            Title: "Movie",
            ChannelLogoUrl: "https://logo.test/img.png",
            ResumeAt: TimeSpan.FromSeconds(30),
            HttpHeaders: headers,
            UserAgent: "CrispyApp/1.0",
            EnableTimeshift: true,
            JellyfinItemId: "jf-99");

        req.Title.Should().Be("Movie");
        req.ChannelLogoUrl.Should().Be("https://logo.test/img.png");
        req.ResumeAt.Should().Be(TimeSpan.FromSeconds(30));
        req.HttpHeaders.Should().BeSameAs(headers);
        req.UserAgent.Should().Be("CrispyApp/1.0");
        req.EnableTimeshift.Should().BeTrue();
        req.JellyfinItemId.Should().Be("jf-99");
    }

    [Fact]
    public void PlaybackRequest_RecordEquality_WhenSameValues()
    {
        var a = new PlaybackRequest("url", PlaybackContentType.Vod, Title: "T");
        var b = new PlaybackRequest("url", PlaybackContentType.Vod, Title: "T");

        a.Should().Be(b);
    }

    [Fact]
    public void PlaybackContentType_HasExpectedValues()
    {
        var values = Enum.GetValues<PlaybackContentType>();
        values.Should().Contain(PlaybackContentType.LiveTv);
        values.Should().Contain(PlaybackContentType.Vod);
        values.Should().Contain(PlaybackContentType.Radio);
    }
}

// =============================================================================
// WatchHistoryEntry
// =============================================================================

[Trait("Category", "Unit")]
public sealed class WatchHistoryEntryTests
{
    private static WatchHistoryEntry MakeEntry(long posMs = 0, long durMs = 0) =>
        new()
        {
            Id = "abc12345",
            Name = "The Show",
            StreamUrl = "https://stream.test/live",
            DeviceId = "dev-1",
            DeviceName = "Desktop",
            ProfileId = "p-1",
            SourceId = "src-1",
            PositionMs = posMs,
            DurationMs = durMs,
        };

    [Fact]
    public void WatchHistoryEntry_StoresRequiredFields()
    {
        var entry = MakeEntry();

        entry.Id.Should().Be("abc12345");
        entry.Name.Should().Be("The Show");
        entry.StreamUrl.Should().Be("https://stream.test/live");
        entry.DeviceId.Should().Be("dev-1");
        entry.ProfileId.Should().Be("p-1");
        entry.SourceId.Should().Be("src-1");
    }

    [Fact]
    public void Progress_ReturnsZero_WhenDurationMsIsZero()
    {
        var entry = MakeEntry(posMs: 5000, durMs: 0);

        entry.Progress.Should().Be(0.0);
    }

    [Fact]
    public void Progress_ReturnsCorrectFraction_WhenDurationMsIsPositive()
    {
        var entry = MakeEntry(posMs: 5000, durMs: 10000);

        entry.Progress.Should().BeApproximately(0.5, 1e-10);
    }

    [Fact]
    public void Progress_ReturnsOne_WhenAtEnd()
    {
        var entry = MakeEntry(posMs: 10000, durMs: 10000);

        entry.Progress.Should().BeApproximately(1.0, 1e-10);
    }

    [Fact]
    public void IsInProgress_ReturnsFalse_WhenProgressIsZero()
    {
        var entry = MakeEntry(posMs: 0, durMs: 10000);

        entry.IsInProgress.Should().BeFalse();
    }

    [Fact]
    public void IsInProgress_ReturnsTrue_WhenProgressBetweenZeroAndNinetyFivePercent()
    {
        var entry = MakeEntry(posMs: 5000, durMs: 10000);

        entry.IsInProgress.Should().BeTrue();
    }

    [Fact]
    public void IsInProgress_ReturnsFalse_WhenProgressAtOrAbove95Percent()
    {
        var entry = MakeEntry(posMs: 9500, durMs: 10000);

        entry.IsInProgress.Should().BeFalse();
    }

    [Fact]
    public void WatchHistoryEntry_StoresOptionalEpisodeFields()
    {
        var entry = MakeEntry();
        entry.SeriesId = "series-9";
        entry.SeasonNumber = 2;
        entry.EpisodeNumber = 3;

        entry.SeriesId.Should().Be("series-9");
        entry.SeasonNumber.Should().Be(2);
        entry.EpisodeNumber.Should().Be(3);
    }

    [Fact]
    public void MediaType_HasExpectedValues()
    {
        Enum.GetValues<MediaType>().Should().Contain([MediaType.Channel, MediaType.Movie, MediaType.Episode]);
    }

    [Fact]
    public void WatchHistoryEntry_MediaType_DefaultsToChannel()
    {
        var entry = MakeEntry();

        entry.MediaType.Should().Be(MediaType.Channel);
    }

    [Fact]
    public void WatchHistoryEntry_MediaType_CanBeSetToMovie()
    {
        var entry = MakeEntry();
        entry.MediaType = MediaType.Movie;

        entry.MediaType.Should().Be(MediaType.Movie);
    }

    [Fact]
    public void WatchHistoryEntry_MediaType_CanBeSetToEpisode()
    {
        var entry = MakeEntry();
        entry.MediaType = MediaType.Episode;

        entry.MediaType.Should().Be(MediaType.Episode);
    }

    [Fact]
    public void Progress_ReturnsAboveOne_WhenPositionExceedsDuration()
    {
        // PositionMs > DurationMs: fraction > 1.0 — no clamping by design.
        var entry = MakeEntry(posMs: 12000, durMs: 10000);

        entry.Progress.Should().BeGreaterThan(1.0);
    }

    [Fact]
    public void WatchHistoryEntry_StoresPosterUrls()
    {
        var entry = MakeEntry();
        entry.PosterUrl = "https://img.test/poster.jpg";
        entry.SeriesPosterUrl = "https://img.test/series.jpg";

        entry.PosterUrl.Should().Be("https://img.test/poster.jpg");
        entry.SeriesPosterUrl.Should().Be("https://img.test/series.jpg");
    }

    [Fact]
    public void WatchHistoryEntry_StoresLastWatched()
    {
        var now = DateTimeOffset.UtcNow;
        var entry = MakeEntry();
        entry.LastWatched = now;

        entry.LastWatched.Should().Be(now);
    }

    [Fact]
    public void WatchHistoryEntry_StoresDeviceName()
    {
        var entry = MakeEntry();

        entry.DeviceName.Should().Be("Desktop");
    }
}

// =============================================================================
// PlayerState
// =============================================================================

[Trait("Category", "Unit")]
public sealed class PlayerStateTests
{
    [Fact]
    public void PlayerState_Empty_HasExpectedDefaults()
    {
        var s = PlayerState.Empty;

        s.IsPlaying.Should().BeFalse();
        s.IsBuffering.Should().BeFalse();
        s.IsMuted.Should().BeFalse();
        s.Volume.Should().Be(1.0f);
        s.Rate.Should().Be(1.0f);
        s.Position.Should().Be(TimeSpan.Zero);
        s.Duration.Should().Be(TimeSpan.Zero);
        s.IsLive.Should().BeFalse();
        s.Timeshift.Should().BeNull();
        s.IsAudioOnly.Should().BeFalse();
        s.ErrorMessage.Should().BeNull();
        s.AudioTracks.Should().BeEmpty();
        s.SubtitleTracks.Should().BeEmpty();
        s.CurrentVideoWidth.Should().BeNull();
        s.CurrentVideoHeight.Should().BeNull();
        s.CurrentRequest.Should().BeNull();
        s.Mode.Should().Be(PlaybackMode.Live);
    }

    [Fact]
    public void PlayerState_Constructor_StoresAllParameters()
    {
        var request = new PlaybackRequest("https://stream.test/s.m3u8", PlaybackContentType.LiveTv);
        var audio = new List<TrackInfo> { new(1, "English", "en", true, TrackKind.Audio) };
        var subs = new List<TrackInfo> { new(2, "French", "fr", false, TrackKind.Subtitle) };

        var state = new PlayerState(
            Mode: PlaybackMode.Vod,
            IsPlaying: true,
            IsBuffering: true,
            IsMuted: true,
            Volume: 0.5f,
            Rate: 1.5f,
            Position: TimeSpan.FromSeconds(30),
            Duration: TimeSpan.FromMinutes(90),
            IsLive: false,
            Timeshift: null,
            IsAudioOnly: false,
            ErrorMessage: "test error",
            AudioTracks: audio,
            SubtitleTracks: subs,
            CurrentVideoWidth: 1920,
            CurrentVideoHeight: 1080,
            CurrentRequest: request);

        state.Mode.Should().Be(PlaybackMode.Vod);
        state.IsPlaying.Should().BeTrue();
        state.IsBuffering.Should().BeTrue();
        state.IsMuted.Should().BeTrue();
        state.Volume.Should().Be(0.5f);
        state.Rate.Should().Be(1.5f);
        state.Position.Should().Be(TimeSpan.FromSeconds(30));
        state.Duration.Should().Be(TimeSpan.FromMinutes(90));
        state.IsLive.Should().BeFalse();
        state.IsAudioOnly.Should().BeFalse();
        state.ErrorMessage.Should().Be("test error");
        state.AudioTracks.Should().BeSameAs(audio);
        state.SubtitleTracks.Should().BeSameAs(subs);
        state.CurrentVideoWidth.Should().Be(1920);
        state.CurrentVideoHeight.Should().Be(1080);
        state.CurrentRequest.Should().BeSameAs(request);
    }

    [Fact]
    public void PlayerState_RecordEquality_WhenSameValues()
    {
        var a = PlayerState.Empty;
        var b = PlayerState.Empty;

        a.Should().Be(b);
    }

    [Fact]
    public void PlayerState_RecordInequality_WhenDifferentIsPlaying()
    {
        var playing = PlayerState.Empty with { IsPlaying = true };

        playing.Should().NotBe(PlayerState.Empty);
    }

    [Fact]
    public void PlayerState_WithExpression_ProducesModifiedCopy()
    {
        var state = PlayerState.Empty with { IsLive = true, Volume = 0.8f };

        state.IsLive.Should().BeTrue();
        state.Volume.Should().Be(0.8f);
        // unchanged properties
        state.IsPlaying.Should().BeFalse();
    }

    [Fact]
    public void PlaybackMode_HasExpectedValues()
    {
        var values = Enum.GetValues<PlaybackMode>();
        values.Should().Contain(PlaybackMode.Live);
        values.Should().Contain(PlaybackMode.Vod);
    }
}

// =============================================================================
// TimeshiftState
// =============================================================================

[Trait("Category", "Unit")]
public sealed class TimeshiftStateTests
{
    [Fact]
    public void TimeshiftState_StoresAllProperties()
    {
        var live = DateTimeOffset.UtcNow;
        var state = new TimeshiftState(
            TimeSpan.FromMinutes(30),
            TimeSpan.FromMinutes(-2),
            live,
            "-2:00",
            false,
            false);

        state.BufferDuration.Should().Be(TimeSpan.FromMinutes(30));
        state.Offset.Should().Be(TimeSpan.FromMinutes(-2));
        state.LiveEdgeTime.Should().Be(live);
        state.OffsetDisplay.Should().Be("-2:00");
        state.IsAtLiveEdge.Should().BeFalse();
        state.IsBufferFull.Should().BeFalse();
    }

    [Fact]
    public void TimeshiftState_AtLiveEdge_HasEmptyOffsetDisplay()
    {
        var state = new TimeshiftState(
            TimeSpan.FromMinutes(10),
            TimeSpan.Zero,
            DateTimeOffset.UtcNow,
            string.Empty,
            true,
            false);

        state.IsAtLiveEdge.Should().BeTrue();
        state.OffsetDisplay.Should().BeEmpty();
    }

    [Fact]
    public void TimeshiftState_RecordEquality_WhenSameValues()
    {
        var live = new DateTimeOffset(2026, 1, 1, 12, 0, 0, TimeSpan.Zero);
        var a = new TimeshiftState(TimeSpan.Zero, TimeSpan.Zero, live, "", true, false);
        var b = new TimeshiftState(TimeSpan.Zero, TimeSpan.Zero, live, "", true, false);

        a.Should().Be(b);
    }

    [Fact]
    public void TimeshiftState_BufferFull_IsStoredCorrectly()
    {
        var state = new TimeshiftState(
            TimeSpan.FromHours(2),
            TimeSpan.FromHours(-2),
            DateTimeOffset.UtcNow,
            "-2:00:00",
            false,
            true);

        state.IsBufferFull.Should().BeTrue();
    }
}

// =============================================================================
// SavedLayout
// =============================================================================

[Trait("Category", "Unit")]
public sealed class SavedLayoutTests
{
    [Fact]
    public void SavedLayout_StoresRequiredProperties()
    {
        var layout = new SavedLayout
        {
            Id = "layout-1",
            Name = "My Quad",
            StreamsJson = "[]",
            ProfileId = "p-1",
        };

        layout.Id.Should().Be("layout-1");
        layout.Name.Should().Be("My Quad");
        layout.StreamsJson.Should().Be("[]");
        layout.ProfileId.Should().Be("p-1");
    }

    [Fact]
    public void SavedLayout_DefaultsToLayoutTypePip()
    {
        var layout = new SavedLayout
        {
            Id = "l",
            Name = "N",
            StreamsJson = "{}",
            ProfileId = "p",
        };

        layout.Layout.Should().Be(LayoutType.Pip);
    }

    [Fact]
    public void SavedLayout_StoresAllLayoutTypeValues()
    {
        foreach (var lt in Enum.GetValues<LayoutType>())
        {
            var layout = new SavedLayout
            {
                Id = "l",
                Name = "N",
                StreamsJson = "{}",
                ProfileId = "p",
                Layout = lt,
            };
            layout.Layout.Should().Be(lt);
        }
    }

    [Fact]
    public void SavedLayout_StoresCreatedAt()
    {
        var now = DateTimeOffset.UtcNow;
        var layout = new SavedLayout
        {
            Id = "l",
            Name = "N",
            StreamsJson = "{}",
            ProfileId = "p",
            CreatedAt = now,
        };

        layout.CreatedAt.Should().Be(now);
    }

    [Fact]
    public void LayoutType_HasExpectedValues()
    {
        Enum.GetValues<LayoutType>().Should().Contain([LayoutType.Pip, LayoutType.Quad, LayoutType.Grid]);
    }
}

// =============================================================================
// TrackInfo
// =============================================================================

[Trait("Category", "Unit")]
public sealed class TrackInfoTests
{
    [Fact]
    public void TrackInfo_StoresAllPositionalParameters()
    {
        var track = new TrackInfo(1, "English", "en", true, TrackKind.Audio);

        track.Id.Should().Be(1);
        track.Name.Should().Be("English");
        track.Language.Should().Be("en");
        track.IsSelected.Should().BeTrue();
        track.Kind.Should().Be(TrackKind.Audio);
    }

    [Fact]
    public void TrackInfo_AllowsEmptyLanguage()
    {
        var track = new TrackInfo(0, "Unknown", string.Empty, false, TrackKind.Subtitle);

        track.Language.Should().BeEmpty();
        track.IsSelected.Should().BeFalse();
        track.Kind.Should().Be(TrackKind.Subtitle);
    }

    [Fact]
    public void TrackInfo_RecordEquality_WhenSameValues()
    {
        var a = new TrackInfo(2, "French", "fr", false, TrackKind.Subtitle);
        var b = new TrackInfo(2, "French", "fr", false, TrackKind.Subtitle);

        a.Should().Be(b);
    }

    [Fact]
    public void TrackInfo_RecordInequality_WhenDifferentId()
    {
        var a = new TrackInfo(1, "English", "en", true, TrackKind.Audio);
        var b = new TrackInfo(2, "English", "en", true, TrackKind.Audio);

        a.Should().NotBe(b);
    }

    [Fact]
    public void TrackKind_HasExpectedValues()
    {
        Enum.GetValues<TrackKind>().Should().Contain([TrackKind.Audio, TrackKind.Subtitle, TrackKind.Video]);
    }
}
