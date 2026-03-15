using Crispy.Domain.Entities;
using Crispy.Domain.Enums;
using FluentAssertions;
using Xunit;

namespace Crispy.Domain.Tests.Entities;

[Trait("Category", "Unit")]
public class LifecycleEntityTests
{
    // --- Profile ---

    [Fact]
    public void Profile_Name_IsSet()
    {
        var profile = new Profile { Name = "Alice" };

        profile.Name.Should().Be("Alice");
    }

    [Fact]
    public void Profile_IsKids_DefaultsToFalse()
    {
        var profile = new Profile { Name = "Alice" };

        profile.IsKids.Should().BeFalse();
    }

    [Fact]
    public void Profile_Settings_DefaultsToEmpty()
    {
        var profile = new Profile { Name = "Alice" };

        profile.Settings.Should().NotBeNull();
        profile.Settings.Should().BeEmpty();
    }

    [Fact]
    public void Profile_Sources_DefaultsToEmpty()
    {
        var profile = new Profile { Name = "Alice" };

        profile.Sources.Should().NotBeNull();
        profile.Sources.Should().BeEmpty();
    }

    // --- WatchHistory ---

    [Fact]
    public void WatchHistory_ProfileId_IsSet()
    {
        var wh = new WatchHistory { ProfileId = 7, ContentId = 1, SourceId = 1 };

        wh.ProfileId.Should().Be(7);
    }

    [Fact]
    public void WatchHistory_CompletionPct_DefaultsToZero()
    {
        var wh = new WatchHistory { ProfileId = 1, ContentId = 1, SourceId = 1 };

        wh.CompletionPct.Should().Be(0.0);
    }

    [Fact]
    public void WatchHistory_ContentType_DefaultsToChannel()
    {
        var wh = new WatchHistory { ProfileId = 1, ContentId = 1, SourceId = 1 };

        wh.ContentType.Should().Be(ContentType.Channel);
    }

    [Fact]
    public void WatchHistory_PositionMs_DefaultsToZero()
    {
        var wh = new WatchHistory { ProfileId = 1, ContentId = 1, SourceId = 1 };

        wh.PositionMs.Should().Be(0L);
    }

    // --- Download ---

    [Fact]
    public void Download_Status_DefaultsToQueued()
    {
        var download = new Download { ContentId = 1 };

        download.Status.Should().Be(DownloadStatus.Queued);
    }

    [Fact]
    public void Download_Progress_DefaultsToZero()
    {
        var download = new Download { ContentId = 1 };

        download.Progress.Should().Be(0.0);
    }

    [Fact]
    public void Download_SizeBytes_DefaultsToZero()
    {
        var download = new Download { ContentId = 1 };

        download.SizeBytes.Should().Be(0L);
    }

    [Fact]
    public void Download_ContentId_IsSet()
    {
        var download = new Download { ContentId = 42 };

        download.ContentId.Should().Be(42);
    }

    // --- StreamEndpoint ---

    [Fact]
    public void StreamEndpoint_Url_IsSet()
    {
        var ep = new StreamEndpoint { ChannelId = 1, SourceId = 1, Url = "http://stream.example.com/live" };

        ep.Url.Should().Be("http://stream.example.com/live");
    }

    [Fact]
    public void StreamEndpoint_Format_DefaultsToUnknown()
    {
        var ep = new StreamEndpoint { ChannelId = 1, SourceId = 1, Url = "http://stream.example.com/live" };

        ep.Format.Should().Be(StreamFormat.Unknown);
    }

    [Fact]
    public void StreamEndpoint_FailureCount_DefaultsToZero()
    {
        var ep = new StreamEndpoint { ChannelId = 1, SourceId = 1, Url = "http://stream.example.com/live" };

        ep.FailureCount.Should().Be(0);
    }

    // --- ChannelGroup ---

    [Fact]
    public void ChannelGroup_Name_IsSet()
    {
        var group = new ChannelGroup { Name = "Sports" };

        group.Name.Should().Be("Sports");
    }

    [Fact]
    public void ChannelGroup_Memberships_DefaultsToEmpty()
    {
        var group = new ChannelGroup { Name = "Sports" };

        group.Memberships.Should().NotBeNull();
        group.Memberships.Should().BeEmpty();
    }

    [Fact]
    public void ChannelGroup_SourceId_DefaultsToNull()
    {
        var group = new ChannelGroup { Name = "Sports" };

        group.SourceId.Should().BeNull();
    }

    // --- SyncHistory ---

    [Fact]
    public void SyncHistory_SourceId_IsSet()
    {
        var sync = new SyncHistory { SourceId = 3 };

        sync.SourceId.Should().Be(3);
    }

    [Fact]
    public void SyncHistory_CompletedAt_DefaultsToNull()
    {
        var sync = new SyncHistory { SourceId = 1 };

        sync.CompletedAt.Should().BeNull();
    }

    [Fact]
    public void SyncHistory_ErrorMessage_DefaultsToNull()
    {
        var sync = new SyncHistory { SourceId = 1 };

        sync.ErrorMessage.Should().BeNull();
    }

    [Fact]
    public void SyncHistory_DurationMs_DefaultsToZero()
    {
        var sync = new SyncHistory { SourceId = 1 };

        sync.DurationMs.Should().Be(0L);
    }
}
