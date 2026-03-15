using Avalonia.Headless.XUnit;

using Crispy.UI.Tests.Helpers;
using Crispy.UI.ViewModels;
using Crispy.UI.Views;

using FluentAssertions;

using Xunit;

namespace Crispy.UI.Tests.Views;

/// <summary>
/// Smoke tests verifying that HomeView mounts and renders without exceptions
/// under the headless Avalonia platform.
/// </summary>
[Trait("Category", "UI")]
public class HomeViewTests
{
    [Fact]
    public void HomeView_Title_IsHome()
    {
        var vm = new HomeViewModel();
        vm.Title.Should().Be("Home");
    }

    [AvaloniaFact]
    public void HomeView_RendersWithoutException()
    {
        var vm = new HomeViewModel();
        var window = HeadlessTestHelpers.CreateWindow<HomeView>(vm);

        window.Should().NotBeNull();
        window.IsVisible.Should().BeTrue();
        window.Content.Should().BeOfType<HomeView>();
        window.Close();
    }
}
