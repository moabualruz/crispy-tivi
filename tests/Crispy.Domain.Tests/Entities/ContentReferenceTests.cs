using Crispy.Domain.Enums;
using Crispy.Domain.ValueObjects;

using FluentAssertions;

using Xunit;

namespace Crispy.Domain.Tests.Entities;

[Trait("Category", "Unit")]
public class ContentReferenceTests
{
    // ── Construction ──────────────────────────────────────────────────────────

    [Fact]
    public void Constructor_SetsContentType_WhenCreated()
    {
        var sut = new ContentReference(ContentType.Channel, 42);
        sut.ContentType.Should().Be(ContentType.Channel);
    }

    [Fact]
    public void Constructor_SetsContentId_WhenCreated()
    {
        var sut = new ContentReference(ContentType.Movie, 99);
        sut.ContentId.Should().Be(99);
    }

    [Theory]
    [InlineData(ContentType.Channel, 1)]
    [InlineData(ContentType.Movie, 2)]
    [InlineData(ContentType.Series, 3)]
    [InlineData(ContentType.Episode, 4)]
    public void Constructor_AcceptsAllContentTypes(ContentType type, int id)
    {
        var sut = new ContentReference(type, id);
        sut.ContentType.Should().Be(type);
        sut.ContentId.Should().Be(id);
    }

    [Fact]
    public void Constructor_AcceptsZeroId()
    {
        var sut = new ContentReference(ContentType.Channel, 0);
        sut.ContentId.Should().Be(0);
    }

    [Fact]
    public void Constructor_AcceptsNegativeId()
    {
        var sut = new ContentReference(ContentType.Movie, -1);
        sut.ContentId.Should().Be(-1);
    }

    [Fact]
    public void Constructor_AcceptsMaxIntId()
    {
        var sut = new ContentReference(ContentType.Episode, int.MaxValue);
        sut.ContentId.Should().Be(int.MaxValue);
    }

    // ── Value equality ────────────────────────────────────────────────────────

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

    // ── Hash code ─────────────────────────────────────────────────────────────

    [Fact]
    public void GetHashCode_IsEqual_ForEqualInstances()
    {
        var a = new ContentReference(ContentType.Series, 55);
        var b = new ContentReference(ContentType.Series, 55);
        a.GetHashCode().Should().Be(b.GetHashCode());
    }

    [Fact]
    public void GetHashCode_Differs_ForDifferentContentType()
    {
        var a = new ContentReference(ContentType.Channel, 1);
        var b = new ContentReference(ContentType.Movie, 1);
        a.GetHashCode().Should().NotBe(b.GetHashCode());
    }

    [Fact]
    public void GetHashCode_Differs_ForDifferentContentId()
    {
        var a = new ContentReference(ContentType.Episode, 1);
        var b = new ContentReference(ContentType.Episode, 2);
        a.GetHashCode().Should().NotBe(b.GetHashCode());
    }

    // ── Struct semantics ──────────────────────────────────────────────────────

    [Fact]
    public void IsValueType()
    {
        typeof(ContentReference).IsValueType.Should().BeTrue();
    }

    [Fact]
    public void Default_HasChannelTypeAndZeroId()
    {
        var sut = default(ContentReference);
        sut.ContentType.Should().Be(ContentType.Channel);
        sut.ContentId.Should().Be(0);
    }

    // ── ToString (record struct auto-generated) ───────────────────────────────

    [Fact]
    public void ContentReference_ToString_ContainsTypeAndId()
    {
        var r = new ContentReference(ContentType.Series, 99);

        r.ContentType.Should().Be(ContentType.Series);
        r.ContentId.Should().Be(99);
    }

    [Fact]
    public void ToString_ContainsContentTypeName()
    {
        var sut = new ContentReference(ContentType.Movie, 5);
        sut.ToString().Should().Contain(nameof(ContentType.Movie));
    }

    [Fact]
    public void ToString_ContainsContentIdValue()
    {
        var sut = new ContentReference(ContentType.Episode, 123);
        sut.ToString().Should().Contain("123");
    }
}
