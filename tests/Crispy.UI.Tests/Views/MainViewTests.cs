using Avalonia.Controls;
using Avalonia.Headless.XUnit;
using Avalonia.VisualTree;

using Crispy.UI.Navigation;
using Crispy.UI.Tests.Helpers;
using Crispy.UI.ViewModels;
using Crispy.UI.Views;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.Views;

[Trait("Category", "Unit")]
public class MainViewTests
{
    private static MainViewModel MakeViewModel()
    {
        var nav = Substitute.For<INavigationService>();
        nav.CanGoBack.Returns(false);
        nav.CurrentViewModel.Returns((ViewModelBase?)null);
        return new MainViewModel(nav);
    }

    [AvaloniaFact]
    public void MainView_RendersWithoutException_WhenShownWithViewModel()
    {
        var vm = MakeViewModel();

        var act = () =>
        {
            var window = HeadlessTestHelpers.CreateWindow<MainView>(vm);
            window.Close();
        };

        act.Should().NotThrow();
    }

    [AvaloniaFact]
    public void MainView_HasNavigationRailControl()
    {
        var vm = MakeViewModel();
        var window = HeadlessTestHelpers.CreateWindow<MainView>(vm);

        // NavigationRail lives in SplitView.Pane which Avalonia places in a
        // template-generated panel. Use FindControl (logical tree) to locate it
        // by its AXAML x:Name, which works regardless of visual-tree depth.
        var mainView = window.GetVisualDescendants()
            .OfType<MainView>()
            .FirstOrDefault();
        mainView.Should().NotBeNull("MainView must be in the window visual tree");

        var rail = mainView!.FindControl<Crispy.UI.Controls.NavigationRail>("NavRail");

        rail.Should().NotBeNull("MainView must contain a NavigationRail named NavRail");

        window.Close();
    }

    [AvaloniaFact]
    public void MainViewModel_IsRailExpanded_DefaultsFalse()
    {
        var vm = MakeViewModel();

        vm.IsRailExpanded.Should().BeFalse();
    }

    [AvaloniaFact]
    public void MainViewModel_ExpandRail_SetsIsRailExpandedTrue()
    {
        var vm = MakeViewModel();

        vm.ExpandRail();

        vm.IsRailExpanded.Should().BeTrue();
    }

    [AvaloniaFact]
    public void MainViewModel_CollapseRail_SetsIsRailExpandedFalse()
    {
        var vm = MakeViewModel();
        vm.ExpandRail();

        vm.CollapseRail();

        vm.IsRailExpanded.Should().BeFalse();
    }

    [AvaloniaFact]
    public void MainViewModel_PrimaryNavItems_IsPopulated()
    {
        var vm = MakeViewModel();

        vm.PrimaryNavItems.Should().NotBeEmpty();
    }

    [AvaloniaFact]
    public void MainViewModel_CanGoBack_ReturnsFalse_WhenNavigationServiceReturnsFalse()
    {
        var vm = MakeViewModel();

        vm.CanGoBack.Should().BeFalse();
    }

    [AvaloniaFact]
    public void MainViewModel_SelectedNavItem_DefaultsToNull()
    {
        var vm = MakeViewModel();

        vm.SelectedNavItem.Should().BeNull();
    }

    [AvaloniaFact]
    public void MainViewModel_GoBackCommand_DoesNotThrow_WhenCanGoBackIsTrue()
    {
        var nav = Substitute.For<INavigationService>();
        nav.CanGoBack.Returns(true);
        nav.CurrentViewModel.Returns((ViewModelBase?)null);
        var vm = new MainViewModel(nav);

        var act = () => vm.GoBackCommand.Execute(null);

        act.Should().NotThrow();
    }
}
