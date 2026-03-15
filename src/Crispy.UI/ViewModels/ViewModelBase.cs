using CommunityToolkit.Mvvm.ComponentModel;

namespace Crispy.UI.ViewModels;

/// <summary>
/// Base class for all ViewModels in the application.
/// </summary>
public abstract partial class ViewModelBase : ObservableObject
{
    /// <summary>
    /// Display title for the view.
    /// </summary>
    [ObservableProperty]
    private string _title = string.Empty;
}
