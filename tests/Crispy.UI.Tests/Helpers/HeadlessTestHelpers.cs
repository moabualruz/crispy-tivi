using Avalonia.Controls;
using Avalonia.VisualTree;

using Crispy.UI.ViewModels;

using FluentAssertions;

namespace Crispy.UI.Tests.Helpers;

/// <summary>
/// Utilities for creating and interrogating Avalonia windows in headless tests.
/// All methods must be called from the Avalonia UI thread (i.e., inside [AvaloniaFact]).
/// </summary>
public static class HeadlessTestHelpers
{
    /// <summary>
    /// Creates a 1280×720 headless window containing <typeparamref name="TView"/> as its content,
    /// binds <paramref name="vm"/> as the DataContext, shows the window, and returns it.
    /// Call <see cref="Window.Close"/> when done (headless windows are not IDisposable).
    /// </summary>
    public static Window CreateWindow<TView>(ViewModelBase vm)
        where TView : Control, new()
    {
        var view = new TView { DataContext = vm };
        var window = new Window
        {
            Content = view,
            Width = 1280,
            Height = 720,
        };
        window.Show();
        return window;
    }

    /// <summary>
    /// Simulates a click on a <see cref="Button"/> named <paramref name="name"/> inside
    /// <paramref name="window"/> by executing its command directly.
    /// </summary>
    public static void ClickButton(Window window, string name)
    {
        var button = GetControl<Button>(window, name);
        button.Should().NotBeNull($"Button '{name}' must exist in the visual tree");
        button!.Command?.Execute(button.CommandParameter);
    }

    /// <summary>
    /// Finds the first descendant control of type <typeparamref name="T"/> with the given
    /// <paramref name="name"/> in the visual tree rooted at <paramref name="window"/>.
    /// Returns <c>null</c> if not found.
    /// </summary>
    public static T? GetControl<T>(Window window, string name)
        where T : Control
        => FindByName<T>(window, name);

    /// <summary>
    /// Asserts that a control named <paramref name="name"/> exists in the window's visual tree
    /// and that its <see cref="Control.IsVisible"/> property is <c>true</c>.
    /// </summary>
    public static void AssertIsVisible(Window window, string name)
    {
        var control = FindByName<Control>(window, name);
        control.Should().NotBeNull($"Control '{name}' must exist in the visual tree");
        control!.IsVisible.Should().BeTrue($"Control '{name}' should be visible");
    }

    // ── Internals ─────────────────────────────────────────────────────────────

    private static T? FindByName<T>(Control parent, string name)
        where T : Control
    {
        if (parent is T typed && typed.Name == name)
            return typed;

        foreach (var child in parent.GetVisualChildren().OfType<Control>())
        {
            var result = FindByName<T>(child, name);
            if (result is not null)
                return result;
        }

        return null;
    }
}
