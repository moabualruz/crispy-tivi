using Crispy.UI.Models;

using FluentAssertions;

using FluentIcons.Common;

using Xunit;

namespace Crispy.UI.Tests.Models;

/// <summary>
/// Unit tests for <see cref="NavigationItem"/>.
/// </summary>
[Trait("Category", "Unit")]
public class NavigationItemTests
{
    [Fact]
    public void Constructor_PopulatesAllProperties()
    {
        var item = new NavigationItem("Home", Symbol.Home, typeof(object));

        item.Name.Should().Be("Home");
        item.Icon.Should().Be(Symbol.Home);
        item.ViewModelType.Should().Be(typeof(object));
    }

    [Fact]
    public void IsSecondary_DefaultsToFalse()
    {
        var item = new NavigationItem("Home", Symbol.Home, typeof(object));

        item.IsSecondary.Should().BeFalse();
    }

    [Fact]
    public void IsSecondary_IsTrueWhenSpecified()
    {
        var item = new NavigationItem("Settings", Symbol.Settings, typeof(object), IsSecondary: true);

        item.IsSecondary.Should().BeTrue();
    }

    [Fact]
    public void RecordEquality_TwoIdenticalItems_AreEqual()
    {
        var a = new NavigationItem("Home", Symbol.Home, typeof(object), false);
        var b = new NavigationItem("Home", Symbol.Home, typeof(object), false);

        a.Should().Be(b);
    }

    [Fact]
    public void RecordEquality_DifferentName_AreNotEqual()
    {
        var a = new NavigationItem("Home", Symbol.Home, typeof(object));
        var b = new NavigationItem("Search", Symbol.Home, typeof(object));

        a.Should().NotBe(b);
    }

    [Fact]
    public void RecordEquality_DifferentIsSecondary_AreNotEqual()
    {
        var a = new NavigationItem("Home", Symbol.Home, typeof(object), false);
        var b = new NavigationItem("Home", Symbol.Home, typeof(object), true);

        a.Should().NotBe(b);
    }
}
