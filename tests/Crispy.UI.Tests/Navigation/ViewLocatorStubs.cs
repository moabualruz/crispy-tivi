using Avalonia.Controls;

using Crispy.UI.ViewModels;

namespace Crispy.UI.Tests.Navigation.ViewModels
{
    /// <summary>
    /// Stub ViewModel in .Navigation.ViewModels namespace so ViewLocator convention
    /// resolves it to <see cref="Crispy.UI.Tests.Navigation.Views.ConventionStubView"/>.
    /// </summary>
    public class ConventionStubViewModel : ViewModelBase { }
}

namespace Crispy.UI.Tests.Navigation.Views
{
    /// <summary>Parameterless UserControl so Activator.CreateInstance succeeds.</summary>
    public class ConventionStubView : UserControl { }
}
