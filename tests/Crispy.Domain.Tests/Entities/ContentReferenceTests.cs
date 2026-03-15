using Crispy.Domain.Enums;
using Crispy.Domain.ValueObjects;

using FluentAssertions;

using Xunit;

namespace Crispy.Domain.Tests.Entities;

public class ContentReferenceTests
{
    [Fact]
    public void ContentReference_SameTypeAndId_AreEqual()
    {
        var a = new ContentReference(ContentType.Channel, 42);
        var b = new ContentReference(ContentType.Channel, 42);

        a.Should().Be(b);
        (a == b).Should().BeTrue();
    }

    [Fact]
    public void ContentReference_DifferentType_AreNotEqual()
    {
        var a = new ContentReference(ContentType.Channel, 42);
        var b = new ContentReference(ContentType.Movie, 42);

        a.Should().NotBe(b);
        (a != b).Should().BeTrue();
    }

    [Fact]
    public void ContentReference_DifferentId_AreNotEqual()
    {
        var a = new ContentReference(ContentType.Movie, 1);
        var b = new ContentReference(ContentType.Movie, 2);

        a.Should().NotBe(b);
    }

    [Fact]
    public void ContentReference_ToString_ContainsTypeAndId()
    {
        var r = new ContentReference(ContentType.Series, 99);

        r.ContentType.Should().Be(ContentType.Series);
        r.ContentId.Should().Be(99);
    }
}
