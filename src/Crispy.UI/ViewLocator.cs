using Avalonia.Controls;
using Avalonia.Controls.Templates;

using Crispy.UI.ViewModels;

namespace Crispy.UI;

/// <summary>
/// DI-aware view resolver: maps ViewModel types to View types by convention.
/// Convention: Crispy.UI.ViewModels.XxxViewModel -> Crispy.UI.Views.XxxView
/// </summary>
public sealed class ViewLocator : IDataTemplate
{
    private readonly IServiceProvider _serviceProvider;

    /// <summary>
    /// Creates a new ViewLocator with the given service provider.
    /// </summary>
    public ViewLocator(IServiceProvider serviceProvider)
    {
        _serviceProvider = serviceProvider;
    }

    /// <inheritdoc />
    public Control Build(object? param)
    {
        if (param is null)
        {
            return new TextBlock { Text = "No ViewModel provided" };
        }

        var viewModelTypeName = param.GetType().FullName;
        if (viewModelTypeName is null)
        {
            return new TextBlock { Text = "Unknown ViewModel type" };
        }

        // Convention: ViewModels.XxxViewModel -> Views.XxxView
        var viewTypeName = viewModelTypeName
            .Replace(".ViewModels.", ".Views.")
            .Replace("ViewModel", "View");

        var viewType = param.GetType().Assembly.GetType(viewTypeName)
                       ?? typeof(ViewLocator).Assembly.GetType(viewTypeName);

        if (viewType is null)
        {
            return new TextBlock { Text = $"View not found: {viewTypeName}" };
        }

        var view = _serviceProvider.GetService(viewType) as Control;
        if (view is not null)
        {
            return view;
        }

        // Fallback: try Activator if not registered in DI
        if (Activator.CreateInstance(viewType) is Control activatedView)
        {
            return activatedView;
        }

        return new TextBlock { Text = $"Could not create: {viewTypeName}" };
    }

    /// <inheritdoc />
    public bool Match(object? data)
    {
        return data is ViewModelBase;
    }
}
