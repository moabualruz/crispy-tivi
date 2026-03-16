using Avalonia.Controls;
using Avalonia.Headless.XUnit;

using Crispy.UI.Controls;
using Crispy.UI.Models;

using FluentAssertions;

using FluentIcons.Common;

using Xunit;

namespace Crispy.UI.Tests.Controls;

[Trait("Category", "Unit")]
public class NavigationRailTests
{
    private static NavigationItem[] MakePrimaryItems() =>
    [
        new NavigationItem("Home", Symbol.Home, typeof(object)),
        new NavigationItem("Live TV", Symbol.Play, typeof(object)),
    ];

    [AvaloniaFact]
    public void NavigationRail_RendersWithoutException_WhenShownInWindow()
    {
        var control = new NavigationRail
        {
            PrimaryItems = MakePrimaryItems(),
        };
        var window = new Window { Content = control, Width = 72, Height = 720 };

        var act = () => window.Show();

        act.Should().NotThrow();
        window.Close();
    }

    [AvaloniaFact]
    public void PrimaryItems_DefaultsToNull()
    {
        var sut = new NavigationRail();

        sut.PrimaryItems.Should().BeNull();
    }

    [AvaloniaFact]
    public void IsExpanded_DefaultsToFalse()
    {
        var sut = new NavigationRail();

        sut.IsExpanded.Should().BeFalse();
    }

    [AvaloniaFact]
    public void IsExpanded_CanBeSetToTrue()
    {
        var sut = new NavigationRail();

        sut.IsExpanded = true;

        sut.IsExpanded.Should().BeTrue();
    }

    [AvaloniaFact]
    public void SelectedItem_DefaultsToNull()
    {
        var sut = new NavigationRail();

        sut.SelectedItem.Should().BeNull();
    }

    [AvaloniaFact]
    public void SelectedItem_CanBeSetProgrammatically()
    {
        var item = new NavigationItem("Home", Symbol.Home, typeof(object));
        var sut = new NavigationRail
        {
            PrimaryItems = [item],
        };

        sut.SelectedItem = item;

        sut.SelectedItem.Should().Be(item);
    }

    [AvaloniaFact]
    public void ItemSelected_Event_CanBeSubscribed()
    {
        var sut = new NavigationRail();
        NavigationItem? received = null;
        sut.ItemSelected += item => received = item;

        // No items selected — event not yet fired
        received.Should().BeNull();
    }

    [AvaloniaFact]
    public void EnterPressed_Event_CanBeSubscribed()
    {
        var sut = new NavigationRail();
        var fired = false;
        sut.EnterPressed += () => fired = true;

        fired.Should().BeFalse();
    }

    [AvaloniaFact]
    public void NavigationRail_RendersExpanded_WithoutException()
    {
        var control = new NavigationRail
        {
            PrimaryItems = MakePrimaryItems(),
            IsExpanded = true,
        };
        var window = new Window { Content = control, Width = 200, Height = 720 };

        var act = () => window.Show();

        act.Should().NotThrow();
        window.Close();
    }
}
