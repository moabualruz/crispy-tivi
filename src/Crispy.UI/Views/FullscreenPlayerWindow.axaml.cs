using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;

namespace Crispy.UI.Views;

/// <summary>
/// Dedicated fullscreen window that hosts the VideoSurface Border reparented from PlayerView.
/// Responsibilities (visual concerns only per MVVM):
/// — Accept a Border content (video surface) via VideoHost.Content.
/// — Raise ExitRequested when Escape is pressed or the window is deactivated,
///   so PlayerView can reattach the surface and close this window.
/// </summary>
public partial class FullscreenPlayerWindow : Window
{
    /// <summary>Raised when the user requests to exit fullscreen (Escape key or deactivation).</summary>
    public event EventHandler? ExitRequested;

    public FullscreenPlayerWindow()
    {
        InitializeComponent();
    }

    protected override void OnKeyDown(KeyEventArgs e)
    {
        base.OnKeyDown(e);
        if (e.Key == Key.Escape)
        {
            e.Handled = true;
            ExitRequested?.Invoke(this, EventArgs.Empty);
        }
    }

    protected override void OnLostFocus(RoutedEventArgs e)
    {
        base.OnLostFocus(e);
        // Deactivation (e.g. Alt+Tab) also exits fullscreen so the surface
        // is not stranded in an invisible window.
        ExitRequested?.Invoke(this, EventArgs.Empty);
    }

    /// <summary>
    /// Sets the video surface as the hosted content.
    /// Must be called before <see cref="Window.Show"/>.
    /// </summary>
    public void SetVideoContent(Control? content)
    {
        VideoHost.Content = content;
    }

    /// <summary>
    /// Removes and returns the hosted content so the caller can reattach it.
    /// </summary>
    public Control? DetachVideoContent()
    {
        var content = VideoHost.Content as Control;
        VideoHost.Content = null;
        return content;
    }
}
