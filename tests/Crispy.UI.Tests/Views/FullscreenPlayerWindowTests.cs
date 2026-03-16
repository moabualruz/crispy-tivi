using Avalonia.Controls;
using Avalonia.Headless.XUnit;

using Crispy.UI.Views;

using FluentAssertions;

using Xunit;

namespace Crispy.UI.Tests.Views;

[Trait("Category", "UI")]
public class FullscreenPlayerWindowTests
{
    [AvaloniaFact]
    public void FullscreenPlayerWindow_CanBeCreated_WithoutThrowing()
    {
        var act = () => new FullscreenPlayerWindow();
        act.Should().NotThrow("the window must construct without exceptions");
    }

    [AvaloniaFact]
    public void FullscreenPlayerWindow_CanBeShownAndClosed_WithoutThrowing()
    {
        var window = new FullscreenPlayerWindow();
        var act = () =>
        {
            window.Show();
            window.Close();
        };
        act.Should().NotThrow("show/close lifecycle must be clean");
    }

    [AvaloniaFact]
    public void FullscreenPlayerWindow_SetVideoContent_AssignsContentToVideoHost()
    {
        var window = new FullscreenPlayerWindow();
        var surface = new Border { Background = Avalonia.Media.Brushes.Black };

        window.SetVideoContent(surface);

        window.VideoHost.Content.Should().BeSameAs(surface,
            "SetVideoContent must place the control into VideoHost");
    }

    [AvaloniaFact]
    public void FullscreenPlayerWindow_DetachVideoContent_ReturnsContentAndClearsHost()
    {
        var window = new FullscreenPlayerWindow();
        var surface = new Border { Background = Avalonia.Media.Brushes.Black };
        window.SetVideoContent(surface);

        var detached = window.DetachVideoContent();

        detached.Should().BeSameAs(surface, "DetachVideoContent must return the previously set control");
        window.VideoHost.Content.Should().BeNull("VideoHost must be cleared after detach");
    }

    [AvaloniaFact]
    public void FullscreenPlayerWindow_ExitRequested_RaisedOnEscapeKey()
    {
        var window = new FullscreenPlayerWindow();
        window.Show();

        var raised = false;
        window.ExitRequested += (_, _) => raised = true;

        // Simulate Escape key via the public event path
        window.Close(); // triggers deactivation path indirectly; test event wiring directly
        raised = false; // reset — Close does not raise ExitRequested

        // Invoke via reflection to directly test handler without real keyboard dispatch
        typeof(FullscreenPlayerWindow)
            .GetMethod("OnKeyDown",
                System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance)
            ?.Invoke(window, [new Avalonia.Input.KeyEventArgs
            {
                Key = Avalonia.Input.Key.Escape,
                RoutedEvent = Avalonia.Input.InputElement.KeyDownEvent
            }]);

        raised.Should().BeTrue("ExitRequested must fire when Escape is pressed");
    }

    [AvaloniaFact]
    public void FullscreenPlayerWindow_Background_IsBlack()
    {
        var window = new FullscreenPlayerWindow();

        window.Background.Should().Be(Avalonia.Media.Brushes.Black,
            "fullscreen window background must be black to avoid flash");
    }

    [AvaloniaFact]
    public void FullscreenPlayerWindow_SystemDecorations_IsNone()
    {
        var window = new FullscreenPlayerWindow();

        window.SystemDecorations.Should().Be(SystemDecorations.None,
            "fullscreen window must have no title bar or borders");
    }
}
