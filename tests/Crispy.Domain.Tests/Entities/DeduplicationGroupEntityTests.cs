using Crispy.Domain.Entities;
using FluentAssertions;
using Xunit;

namespace Crispy.Domain.Tests.Entities;

[Trait("Category", "Unit")]
public class DeduplicationGroupEntityTests
{
    [Fact]
    public void DeduplicationGroup_CanonicalTitle_IsSet()
    {
        var group = new DeduplicationGroup { CanonicalTitle = "BBC One" };

        group.CanonicalTitle.Should().Be("BBC One");
    }

    [Fact]
    public void DeduplicationGroup_CanonicalTvgId_DefaultsToNull()
    {
        var group = new DeduplicationGroup { CanonicalTitle = "BBC One" };

        group.CanonicalTvgId.Should().BeNull();
    }

    [Fact]
    public void DeduplicationGroup_CanonicalTvgId_CanBeSet()
    {
        var group = new DeduplicationGroup
        {
            CanonicalTitle = "BBC One",
            CanonicalTvgId = "bbc-one",
        };

        group.CanonicalTvgId.Should().Be("bbc-one");
    }

    [Fact]
    public void DeduplicationGroup_Channels_DefaultsToEmptyCollection()
    {
        var group = new DeduplicationGroup { CanonicalTitle = "BBC One" };

        group.Channels.Should().NotBeNull();
        group.Channels.Should().BeEmpty();
    }

    [Fact]
    public void DeduplicationGroup_Channels_CanAddMembers()
    {
        var group = new DeduplicationGroup { CanonicalTitle = "BBC One" };
        var channel = new Channel { Title = "BBC One HD", SourceId = 1 };

        group.Channels.Add(channel);

        group.Channels.Should().ContainSingle();
    }
}
