using Avalonia.Controls;

namespace Crispy.UI.Views;

/// <summary>
/// Desktop main window wrapper. DataContext is AppShellViewModel, set by App.axaml.cs.
/// </summary>
public partial class MainWindow : Window
{
    /// <summary>
    /// Creates a new MainWindow.
    /// </summary>
    public MainWindow()
    {
        InitializeComponent();
    }
}
