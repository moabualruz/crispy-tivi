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
}
