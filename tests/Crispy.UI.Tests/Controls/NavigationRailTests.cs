using Avalonia.Controls;
using Avalonia.Headless;
using Avalonia.Headless.XUnit;
using Avalonia.Input;
using Avalonia.Input.Platform;
using Avalonia.VisualTree;

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
            PrimaryItems = new NavigationItem[] { item },
        };

        sut.SelectedItem = item;

        sut.SelectedItem.Should().Be(item);
    }

    [AvaloniaFact]
    public void ItemSelected_Event_FiredWhenListBoxSelectionChanges()
    {
        var items = MakePrimaryItems();
        var control = new NavigationRail
        {
            PrimaryItems = items,
        };
        var window = new Window { Content = control, Width = 72, Height = 720 };
        window.Show();

        NavigationItem? received = null;
        control.ItemSelected += i => received = i;

        // Drive selection through the internal PrimaryList — this is the real user
        // path that triggers SelectionChanged → ItemSelected event.
        var primaryList = control.GetVisualDescendants()
            .OfType<ListBox>()
            .FirstOrDefault(l => l.Name == "PrimaryList");
        primaryList.Should().NotBeNull("PrimaryList must be in the visual tree after layout");
        primaryList!.SelectedItem = items[0];

        received.Should().Be(items[0]);
        control.SelectedItem.Should().Be(items[0]);
        window.Close();
    }

    [AvaloniaFact]
    public void EnterPressed_Event_FiredOnEnterKeyDown()
    {
        // NavigationRail.OnKeyDown fires when it holds keyboard focus.
        // Set Focusable=true so the UserControl itself can receive key events.
        var control = new NavigationRail { Focusable = true };
        var window = new Window { Content = control, Width = 72, Height = 720 };
        window.Show();

        var fired = false;
        control.EnterPressed += () => fired = true;

        control.Focus();
        window.KeyPressQwerty(PhysicalKey.Enter, RawInputModifiers.None);
        window.KeyReleaseQwerty(PhysicalKey.Enter, RawInputModifiers.None);

        fired.Should().BeTrue();
        window.Close();
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
