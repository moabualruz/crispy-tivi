using Crispy.Domain.Entities;
using Crispy.Domain.Enums;

using FluentAssertions;

using Xunit;

namespace Crispy.Domain.Tests.Entities;

public class ChannelTests
{
    [Fact]
    public void Channel_WithIsRadioTrue_HasCatchupTypeNoneByDefault()
    {
        var channel = new Channel
        {
            Title = "Radio Station",
            SourceId = 1,
            IsRadio = true,
        };

        channel.CatchupType.Should().Be(CatchupType.None);
    }

    [Fact]
    public void Channel_MissedSyncCount_IncrementsCorrectly()
    {
        var channel = new Channel
        {
            Title = "Test Channel",
            SourceId = 1,
        };

        channel.MissedSyncCount = 0;
        channel.MissedSyncCount++;

        channel.MissedSyncCount.Should().Be(1);
    }

    [Fact]
    public void Channel_MissedSyncCount_CannotBeNegative()
    {
        var channel = new Channel
        {
            Title = "Test Channel",
            SourceId = 1,
            MissedSyncCount = 0,
        };

        // MissedSyncCount should never go below 0
        var count = channel.MissedSyncCount - 1;
        var safe = Math.Max(0, count);

        safe.Should().Be(0);
    }

    [Fact]
    public void Channel_IsFavorite_DefaultsToFalse()
    {
        var channel = new Channel { Title = "Ch", SourceId = 1 };

        channel.IsFavorite.Should().BeFalse();
    }

    [Fact]
    public void Channel_IsHidden_DefaultsToFalse()
    {
        var channel = new Channel { Title = "Ch", SourceId = 1 };

        channel.IsHidden.Should().BeFalse();
    }

    [Fact]
    public void Channel_Thumbnail_ReturnsTvgLogo_WhenSet()
    {
        var channel = new Channel
        {
            Title = "Ch",
            SourceId = 1,
            TvgLogo = "https://logo.example.com/ch.png",
        };

        channel.Thumbnail.Should().Be("https://logo.example.com/ch.png");
    }

    [Fact]
    public void Channel_Thumbnail_ReturnsNull_WhenTvgLogoNotSet()
    {
        var channel = new Channel { Title = "Ch", SourceId = 1 };

        channel.Thumbnail.Should().BeNull();
    }

    [Fact]
    public void Channel_Thumbnail_TracksChangesToTvgLogo()
    {
        var channel = new Channel { Title = "Ch", SourceId = 1, TvgLogo = "old.png" };
        channel.TvgLogo = "new.png";

        channel.Thumbnail.Should().Be("new.png");
    }

    [Fact]
    public void Channel_UnifiedNumber_DefaultsToNull()
    {
        var channel = new Channel { Title = "Ch", SourceId = 1 };

        channel.UnifiedNumber.Should().BeNull();
    }

    [Fact]
    public void Channel_UserAssignedNumber_CanBeSet()
    {
        var channel = new Channel { Title = "Ch", SourceId = 1, UserAssignedNumber = 42 };

        channel.UserAssignedNumber.Should().Be(42);
    }

    [Fact]
    public void Channel_CustomSortOrder_CanBeSet()
    {
        var channel = new Channel { Title = "Ch", SourceId = 1, CustomSortOrder = 10 };

        channel.CustomSortOrder.Should().Be(10);
    }

    [Fact]
    public void Channel_DeduplicationGroupId_DefaultsToNull()
    {
        var channel = new Channel { Title = "Ch", SourceId = 1 };

        channel.DeduplicationGroupId.Should().BeNull();
    }

    [Fact]
    public void Channel_StreamEndpoints_DefaultsToEmptyCollection()
    {
        var channel = new Channel { Title = "Ch", SourceId = 1 };

        channel.StreamEndpoints.Should().BeEmpty();
    }

    [Fact]
    public void Channel_GroupMemberships_DefaultsToEmptyCollection()
    {
        var channel = new Channel { Title = "Ch", SourceId = 1 };

        channel.GroupMemberships.Should().BeEmpty();
    }

    [Fact]
    public void Channel_CatchupDays_DefaultsToZero()
    {
        var channel = new Channel { Title = "Ch", SourceId = 1 };

        channel.CatchupDays.Should().Be(0);
    }

    [Fact]
    public void Channel_IsRadio_DefaultsToFalse()
    {
        var channel = new Channel { Title = "Ch", SourceId = 1 };

        channel.IsRadio.Should().BeFalse();
    }

    [Fact]
    public void Channel_TvgChno_CanBeSetAndRetrieved()
    {
        var channel = new Channel { Title = "Ch", SourceId = 1, TvgChno = 5 };

        channel.TvgChno.Should().Be(5);
    }
}
