using Crispy.Domain.Entities;
using Crispy.Domain.Enums;

using FluentAssertions;

using Xunit;

namespace Crispy.Domain.Tests.Entities;

// ─── BaseEntity (via concrete subclass) ───────────────────────────────────────

file sealed class ConcreteInfraEntity : BaseEntity { }

[Trait("Category", "Unit")]
public class BaseEntityInfraTests
{
    [Fact]
    public void BaseEntity_Id_DefaultsToZero()
    {
        var entity = new ConcreteInfraEntity();

        entity.Id.Should().Be(0);
    }

    [Fact]
    public void BaseEntity_CreatedAt_DefaultsToMinValue()
    {
        var entity = new ConcreteInfraEntity();

        entity.CreatedAt.Should().Be(default);
    }

    [Fact]
    public void BaseEntity_UpdatedAt_DefaultsToMinValue()
    {
        var entity = new ConcreteInfraEntity();

        entity.UpdatedAt.Should().Be(default);
    }

    [Fact]
    public void BaseEntity_DeletedAt_DefaultsToNull()
    {
        var entity = new ConcreteInfraEntity();

        entity.DeletedAt.Should().BeNull();
    }

    [Fact]
    public void BaseEntity_Id_CanBeSet()
    {
        var entity = new ConcreteInfraEntity { Id = 42 };

        entity.Id.Should().Be(42);
    }

    [Fact]
    public void BaseEntity_DeletedAt_CanBeSet()
    {
        var now = DateTime.UtcNow;
        var entity = new ConcreteInfraEntity { DeletedAt = now };

        entity.DeletedAt.Should().Be(now);
    }
}

// ─── StreamEndpoint ───────────────────────────────────────────────────────────

[Trait("Category", "Unit")]
public class StreamEndpointTests
{
    private static StreamEndpoint Make() => new()
    {
        ChannelId = 1,
        SourceId = 2,
        Url = "http://stream.example.com/live",
    };

    [Fact]
    public void StreamEndpoint_RequiredProperties_AreSet()
    {
        var ep = Make();

        ep.ChannelId.Should().Be(1);
        ep.SourceId.Should().Be(2);
        ep.Url.Should().Be("http://stream.example.com/live");
    }

    [Fact]
    public void StreamEndpoint_Format_DefaultsToUnknown()
    {
        var ep = Make();

        ep.Format.Should().Be(StreamFormat.Unknown);
    }

    [Fact]
    public void StreamEndpoint_Priority_DefaultsToZero()
    {
        var ep = Make();

        ep.Priority.Should().Be(0);
    }

    [Fact]
    public void StreamEndpoint_FailureCount_DefaultsToZero()
    {
        var ep = Make();

        ep.FailureCount.Should().Be(0);
    }

    [Fact]
    public void StreamEndpoint_LastSuccessAt_DefaultsToNull()
    {
        var ep = Make();

        ep.LastSuccessAt.Should().BeNull();
    }

    [Fact]
    public void StreamEndpoint_HttpHeaders_DefaultsToNull()
    {
        var ep = Make();

        ep.HttpHeaders.Should().BeNull();
    }

    [Fact]
    public void StreamEndpoint_Channel_DefaultsToNull()
    {
        var ep = Make();

        ep.Channel.Should().BeNull();
    }

    [Fact]
    public void StreamEndpoint_Source_DefaultsToNull()
    {
        var ep = Make();

        ep.Source.Should().BeNull();
    }

    [Fact]
    public void StreamEndpoint_Format_CanBeSet()
    {
        var ep = Make();
        ep.Format = StreamFormat.HLS;

        ep.Format.Should().Be(StreamFormat.HLS);
    }

    [Fact]
    public void StreamEndpoint_LastSuccessAt_CanBeSet()
    {
        var ep = Make();
        var now = DateTimeOffset.UtcNow;
        ep.LastSuccessAt = now;

        ep.LastSuccessAt.Should().Be(now);
    }

    [Fact]
    public void StreamEndpoint_HttpHeaders_CanBeSet()
    {
        var ep = Make();
        ep.HttpHeaders = "{\"User-Agent\":\"TestAgent\"}";

        ep.HttpHeaders.Should().Be("{\"User-Agent\":\"TestAgent\"}");
    }

    [Fact]
    public void StreamEndpoint_FailureCount_CanBeIncremented()
    {
        var ep = Make();
        ep.FailureCount = 3;

        ep.FailureCount.Should().Be(3);
    }
}

// ─── ChannelGroup ─────────────────────────────────────────────────────────────

[Trait("Category", "Unit")]
public class ChannelGroupTests
{
    private static ChannelGroup Make() => new() { Name = "Sports" };

    [Fact]
    public void ChannelGroup_Name_IsSet()
    {
        var group = Make();

        group.Name.Should().Be("Sports");
    }

    [Fact]
    public void ChannelGroup_SortOrder_DefaultsToZero()
    {
        var group = Make();

        group.SortOrder.Should().Be(0);
    }

    [Fact]
    public void ChannelGroup_SourceId_DefaultsToNull()
    {
        var group = Make();

        group.SourceId.Should().BeNull();
    }

    [Fact]
    public void ChannelGroup_Memberships_DefaultsToEmpty()
    {
        var group = Make();

        group.Memberships.Should().NotBeNull();
        group.Memberships.Should().BeEmpty();
    }

    [Fact]
    public void ChannelGroup_SourceId_CanBeSet()
    {
        var group = Make();
        group.SourceId = 7;

        group.SourceId.Should().Be(7);
    }

    [Fact]
    public void ChannelGroup_SortOrder_CanBeSet()
    {
        var group = Make();
        group.SortOrder = 5;

        group.SortOrder.Should().Be(5);
    }
}

// ─── SyncHistory ──────────────────────────────────────────────────────────────

[Trait("Category", "Unit")]
public class SyncHistoryTests
{
    private static SyncHistory Make() => new()
    {
        SourceId = 1,
        StartedAt = new DateTime(2026, 1, 1, 12, 0, 0, DateTimeKind.Utc),
    };

    [Fact]
    public void SyncHistory_SourceId_IsSet()
    {
        var sync = Make();

        sync.SourceId.Should().Be(1);
    }

    [Fact]
    public void SyncHistory_StartedAt_IsSet()
    {
        var sync = Make();

        sync.StartedAt.Should().Be(new DateTime(2026, 1, 1, 12, 0, 0, DateTimeKind.Utc));
    }

    [Fact]
    public void SyncHistory_Status_DefaultsToRunning()
    {
        var sync = Make();

        sync.Status.Should().Be(SyncStatus.Running);
    }

    [Fact]
    public void SyncHistory_ChannelCount_DefaultsToZero()
    {
        var sync = Make();

        sync.ChannelCount.Should().Be(0);
    }

    [Fact]
    public void SyncHistory_VodCount_DefaultsToZero()
    {
        var sync = Make();

        sync.VodCount.Should().Be(0);
    }

    [Fact]
    public void SyncHistory_EpgCount_DefaultsToZero()
    {
        var sync = Make();

        sync.EpgCount.Should().Be(0);
    }

    [Fact]
    public void SyncHistory_DurationMs_DefaultsToZero()
    {
        var sync = Make();

        sync.DurationMs.Should().Be(0);
    }

    [Fact]
    public void SyncHistory_CompletedAt_DefaultsToNull()
    {
        var sync = Make();

        sync.CompletedAt.Should().BeNull();
    }

    [Fact]
    public void SyncHistory_ErrorMessage_DefaultsToNull()
    {
        var sync = Make();

        sync.ErrorMessage.Should().BeNull();
    }

    [Fact]
    public void SyncHistory_Source_DefaultsToNull()
    {
        var sync = Make();

        sync.Source.Should().BeNull();
    }

    [Fact]
    public void SyncHistory_Status_CanBeSetToCompleted()
    {
        var sync = Make();
        sync.Status = SyncStatus.Completed;

        sync.Status.Should().Be(SyncStatus.Completed);
    }

    [Fact]
    public void SyncHistory_ErrorMessage_CanBeSet_WhenFailed()
    {
        var sync = Make();
        sync.Status = SyncStatus.Failed;
        sync.ErrorMessage = "Connection timed out";

        sync.Status.Should().Be(SyncStatus.Failed);
        sync.ErrorMessage.Should().Be("Connection timed out");
    }

    [Fact]
    public void SyncHistory_Counts_CanBeSet()
    {
        var sync = Make();
        sync.ChannelCount = 500;
        sync.VodCount = 1200;
        sync.EpgCount = 8000;
        sync.DurationMs = 45000;

        sync.ChannelCount.Should().Be(500);
        sync.VodCount.Should().Be(1200);
        sync.EpgCount.Should().Be(8000);
        sync.DurationMs.Should().Be(45000);
    }
}

// ─── WatchHistory ─────────────────────────────────────────────────────────────

[Trait("Category", "Unit")]
public class WatchHistoryTests
{
    private static WatchHistory Make() => new()
    {
        ProfileId = 1,
        ContentId = 10,
        SourceId = 2,
        WatchedAt = new DateTime(2026, 1, 5, 20, 30, 0, DateTimeKind.Utc),
    };

    [Fact]
    public void WatchHistory_RequiredProperties_AreSet()
    {
        var wh = Make();

        wh.ProfileId.Should().Be(1);
        wh.ContentId.Should().Be(10);
        wh.SourceId.Should().Be(2);
    }

    [Fact]
    public void WatchHistory_ContentType_DefaultsToChannel()
    {
        var wh = Make();

        wh.ContentType.Should().Be(ContentType.Channel);
    }

    [Fact]
    public void WatchHistory_PositionMs_DefaultsToZero()
    {
        var wh = Make();

        wh.PositionMs.Should().Be(0);
    }

    [Fact]
    public void WatchHistory_DurationMs_DefaultsToZero()
    {
        var wh = Make();

        wh.DurationMs.Should().Be(0);
    }

    [Fact]
    public void WatchHistory_CompletionPct_DefaultsToZero()
    {
        var wh = Make();

        wh.CompletionPct.Should().Be(0.0);
    }

    [Fact]
    public void WatchHistory_Profile_DefaultsToNull()
    {
        var wh = Make();

        wh.Profile.Should().BeNull();
    }

    [Fact]
    public void WatchHistory_ContentType_CanBeSet()
    {
        var wh = Make();
        wh.ContentType = ContentType.Movie;

        wh.ContentType.Should().Be(ContentType.Movie);
    }

    [Fact]
    public void WatchHistory_PositionAndCompletion_CanBeSet()
    {
        var wh = Make();
        wh.PositionMs = 2700000;
        wh.DurationMs = 5400000;
        wh.CompletionPct = 0.5;

        wh.PositionMs.Should().Be(2700000);
        wh.DurationMs.Should().Be(5400000);
        wh.CompletionPct.Should().Be(0.5);
    }

    [Fact]
    public void WatchHistory_WatchedAt_IsSet()
    {
        var wh = Make();

        wh.WatchedAt.Should().Be(new DateTime(2026, 1, 5, 20, 30, 0, DateTimeKind.Utc));
    }
}

// ─── Download ─────────────────────────────────────────────────────────────────

[Trait("Category", "Unit")]
public class DownloadTests
{
    private static Download Make() => new() { ContentId = 5 };

    [Fact]
    public void Download_ContentId_IsSet()
    {
        var dl = Make();

        dl.ContentId.Should().Be(5);
    }

    [Fact]
    public void Download_Status_DefaultsToQueued()
    {
        var dl = Make();

        dl.Status.Should().Be(DownloadStatus.Queued);
    }

    [Fact]
    public void Download_ContentType_DefaultsToChannel()
    {
        var dl = Make();

        dl.ContentType.Should().Be(ContentType.Channel);
    }

    [Fact]
    public void Download_Progress_DefaultsToZero()
    {
        var dl = Make();

        dl.Progress.Should().Be(0.0);
    }

    [Fact]
    public void Download_SizeBytes_DefaultsToZero()
    {
        var dl = Make();

        dl.SizeBytes.Should().Be(0);
    }

    [Fact]
    public void Download_FilePath_DefaultsToNull()
    {
        var dl = Make();

        dl.FilePath.Should().BeNull();
    }

    [Fact]
    public void Download_Quality_DefaultsToNull()
    {
        var dl = Make();

        dl.Quality.Should().BeNull();
    }

    [Fact]
    public void Download_Status_CanTransitionToDownloading()
    {
        var dl = Make();
        dl.Status = DownloadStatus.Downloading;

        dl.Status.Should().Be(DownloadStatus.Downloading);
    }

    [Fact]
    public void Download_Progress_CanBeUpdated()
    {
        var dl = Make();
        dl.Progress = 0.75;

        dl.Progress.Should().Be(0.75);
    }

    [Fact]
    public void Download_FilePath_CanBeSet_WhenCompleted()
    {
        var dl = Make();
        dl.Status = DownloadStatus.Completed;
        dl.FilePath = "/storage/downloads/movie.mkv";

        dl.FilePath.Should().Be("/storage/downloads/movie.mkv");
    }

    [Fact]
    public void Download_Quality_CanBeSet()
    {
        var dl = Make();
        dl.Quality = "1080p";

        dl.Quality.Should().Be("1080p");
    }

    [Fact]
    public void Download_SizeBytes_CanBeSet()
    {
        var dl = Make();
        dl.SizeBytes = 2_147_483_648L;

        dl.SizeBytes.Should().Be(2_147_483_648L);
    }
}

// ─── Profile ──────────────────────────────────────────────────────────────────

[Trait("Category", "Unit")]
public class ProfileTests
{
    private static Profile Make() => new() { Name = "Alice" };

    [Fact]
    public void Profile_Name_IsSet()
    {
        var p = Make();

        p.Name.Should().Be("Alice");
    }

    [Fact]
    public void Profile_IsKids_DefaultsToFalse()
    {
        var p = Make();

        p.IsKids.Should().BeFalse();
    }

    [Fact]
    public void Profile_AvatarIndex_DefaultsToZero()
    {
        var p = Make();

        p.AvatarIndex.Should().Be(0);
    }

    [Fact]
    public void Profile_AccentColorIndex_DefaultsToZero()
    {
        var p = Make();

        p.AccentColorIndex.Should().Be(0);
    }

    [Fact]
    public void Profile_PinHash_DefaultsToNull()
    {
        var p = Make();

        p.PinHash.Should().BeNull();
    }

    [Fact]
    public void Profile_Settings_DefaultsToEmpty()
    {
        var p = Make();

        p.Settings.Should().NotBeNull();
        p.Settings.Should().BeEmpty();
    }

    [Fact]
    public void Profile_Sources_DefaultsToEmpty()
    {
        var p = Make();

        p.Sources.Should().NotBeNull();
        p.Sources.Should().BeEmpty();
    }

    [Fact]
    public void Profile_IsKids_CanBeSetToTrue()
    {
        var p = Make();
        p.IsKids = true;

        p.IsKids.Should().BeTrue();
    }

    [Fact]
    public void Profile_AvatarIndex_CanBeSet()
    {
        var p = Make();
        p.AvatarIndex = 3;

        p.AvatarIndex.Should().Be(3);
    }

    [Fact]
    public void Profile_PinHash_CanBeSet()
    {
        var p = Make();
        p.PinHash = "hashed-pin-value";

        p.PinHash.Should().Be("hashed-pin-value");
    }
}

// ─── Setting ──────────────────────────────────────────────────────────────────

[Trait("Category", "Unit")]
public class SettingEntityTests
{
    private static Setting Make() => new() { Key = "theme", Value = "\"dark\"" };

    [Fact]
    public void Setting_Key_IsSet()
    {
        var s = Make();

        s.Key.Should().Be("theme");
    }

    [Fact]
    public void Setting_Value_IsSet()
    {
        var s = Make();

        s.Value.Should().Be("\"dark\"");
    }

    [Fact]
    public void Setting_ProfileId_DefaultsToNull()
    {
        var s = Make();

        s.ProfileId.Should().BeNull();
    }

    [Fact]
    public void Setting_Profile_DefaultsToNull()
    {
        var s = Make();

        s.Profile.Should().BeNull();
    }

    [Fact]
    public void Setting_ProfileId_CanBeSet_ForProfileScoped()
    {
        var s = Make();
        s.ProfileId = 7;

        s.ProfileId.Should().Be(7);
    }

    [Fact]
    public void Setting_Value_CanBeUpdated()
    {
        var s = Make();
        s.Value = "\"light\"";

        s.Value.Should().Be("\"light\"");
    }

    [Fact]
    public void Setting_GlobalSetting_HasNullProfileId()
    {
        var s = new Setting { Key = "locale", Value = "\"en-US\"" };

        s.ProfileId.Should().BeNull();
    }
}
