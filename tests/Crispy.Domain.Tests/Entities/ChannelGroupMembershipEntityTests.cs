using Crispy.Domain.Entities;
using FluentAssertions;
using Xunit;

namespace Crispy.Domain.Tests.Entities;

[Trait("Category", "Unit")]
public class ChannelGroupMembershipEntityTests
{
    [Fact]
    public void ChannelGroupMembership_ChannelId_IsSet()
    {
        var membership = new ChannelGroupMembership { ChannelId = 10, ChannelGroupId = 3 };

        membership.ChannelId.Should().Be(10);
    }

    [Fact]
    public void ChannelGroupMembership_ChannelGroupId_IsSet()
    {
        var membership = new ChannelGroupMembership { ChannelId = 10, ChannelGroupId = 3 };

        membership.ChannelGroupId.Should().Be(3);
    }

    [Fact]
    public void ChannelGroupMembership_SortOrder_DefaultsToZero()
    {
        var membership = new ChannelGroupMembership { ChannelId = 1, ChannelGroupId = 1 };

        membership.SortOrder.Should().Be(0);
    }

    [Fact]
    public void ChannelGroupMembership_SortOrder_CanBeSet()
    {
        var membership = new ChannelGroupMembership
        {
            ChannelId = 1,
            ChannelGroupId = 1,
            SortOrder = 5,
        };

        membership.SortOrder.Should().Be(5);
    }

    [Fact]
    public void ChannelGroupMembership_Channel_DefaultsToNull()
    {
        var membership = new ChannelGroupMembership { ChannelId = 1, ChannelGroupId = 1 };

        membership.Channel.Should().BeNull();
    }

    [Fact]
    public void ChannelGroupMembership_ChannelGroup_DefaultsToNull()
    {
        var membership = new ChannelGroupMembership { ChannelId = 1, ChannelGroupId = 1 };

        membership.ChannelGroup.Should().BeNull();
    }
}
