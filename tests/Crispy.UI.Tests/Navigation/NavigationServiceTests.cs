using Crispy.UI.Navigation;
using Crispy.UI.ViewModels;

using FluentAssertions;

using Microsoft.Extensions.DependencyInjection;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.Navigation;

/// <summary>
/// Tests for stack-based NavigationService.
/// </summary>
public class NavigationServiceTests
{
    private readonly ServiceProvider _serviceProvider;
    private readonly NavigationService _sut;

    public NavigationServiceTests()
    {
        var services = new ServiceCollection();
        services.AddTransient<HomeTestViewModel>();
        services.AddTransient<LiveTvTestViewModel>();
        services.AddTransient<ScrollableTestViewModel>();
        _serviceProvider = services.BuildServiceProvider();
        _sut = new NavigationService(_serviceProvider);
    }

    [Fact]
    public void NavigateTo_Generic_SetsCurrentViewModel()
    {
        _sut.NavigateTo<HomeTestViewModel>();

        _sut.CurrentViewModel.Should().BeOfType<HomeTestViewModel>();
    }

    [Fact]
    public void NavigateTo_Generic_FiresNavigatedEvent()
    {
        ViewModelBase? navigated = null;
        _sut.Navigated += vm => navigated = vm;

        _sut.NavigateTo<HomeTestViewModel>();

        navigated.Should().BeOfType<HomeTestViewModel>();
    }

    [Fact]
    public void NavigateTo_ByType_SetsCurrentViewModel()
    {
        _sut.NavigateTo(typeof(HomeTestViewModel));

        _sut.CurrentViewModel.Should().BeOfType<HomeTestViewModel>();
    }

    [Fact]
    public void NavigateTo_CallsOnNavigatedTo_WhenViewModelImplementsINavigationAware()
    {
        _sut.NavigateTo<HomeTestViewModel>("test-param");

        var vm = _sut.CurrentViewModel as HomeTestViewModel;
        vm.Should().NotBeNull();
        vm!.LastNavigatedToParam.Should().Be("test-param");
    }

    [Fact]
    public void NavigateTo_CallsOnNavigatedFrom_OnPreviousViewModel()
    {
        _sut.NavigateTo<HomeTestViewModel>();
        var homeVm = _sut.CurrentViewModel as HomeTestViewModel;

        _sut.NavigateTo<LiveTvTestViewModel>();

        homeVm!.NavigatedFromCalled.Should().BeTrue();
    }

    [Fact]
    public void CanGoBack_IsFalse_WhenOnlyOneViewInStack()
    {
        _sut.NavigateTo<HomeTestViewModel>();

        _sut.CanGoBack.Should().BeFalse();
    }

    [Fact]
    public void CanGoBack_IsTrue_WhenMultipleViewsInStack()
    {
        _sut.NavigateTo<HomeTestViewModel>();
        _sut.NavigateTo<LiveTvTestViewModel>();

        _sut.CanGoBack.Should().BeTrue();
    }

    [Fact]
    public void GoBack_RestoresPreviousViewModel()
    {
        _sut.NavigateTo<HomeTestViewModel>();
        var homeVm = _sut.CurrentViewModel;
        _sut.NavigateTo<LiveTvTestViewModel>();

        _sut.GoBack();

        _sut.CurrentViewModel.Should().BeSameAs(homeVm);
    }

    [Fact]
    public void GoBack_FiresNavigatedEvent()
    {
        _sut.NavigateTo<HomeTestViewModel>();
        _sut.NavigateTo<LiveTvTestViewModel>();

        ViewModelBase? navigated = null;
        _sut.Navigated += vm => navigated = vm;
        _sut.GoBack();

        navigated.Should().BeOfType<HomeTestViewModel>();
    }

    [Fact]
    public void GoBack_OnEmptyStack_DoesNothing()
    {
        _sut.NavigateTo<HomeTestViewModel>();
        var current = _sut.CurrentViewModel;

        _sut.GoBack();

        _sut.CurrentViewModel.Should().BeSameAs(current);
    }

    [Fact]
    public void GoBack_SavesAndRestoresScrollPosition()
    {
        _sut.NavigateTo<ScrollableTestViewModel>();
        var scrollVm = _sut.CurrentViewModel as ScrollableTestViewModel;
        scrollVm!.ScrollPosition = 42.5;

        _sut.NavigateTo<LiveTvTestViewModel>();
        _sut.GoBack();

        var restored = _sut.CurrentViewModel as ScrollableTestViewModel;
        restored.Should().BeSameAs(scrollVm);
        restored!.RestoredPosition.Should().Be(42.5);
    }

    [Fact]
    public void NavigateTo_SameType_CreatesNewInstance()
    {
        _sut.NavigateTo<HomeTestViewModel>();
        var first = _sut.CurrentViewModel;

        _sut.NavigateTo<HomeTestViewModel>();
        var second = _sut.CurrentViewModel;

        second.Should().NotBeSameAs(first);
        _sut.CanGoBack.Should().BeTrue();
    }
}

// --- Test doubles ---

public class HomeTestViewModel : ViewModelBase, INavigationAware
{
    public object? LastNavigatedToParam { get; private set; }
    public bool NavigatedFromCalled { get; private set; }

    public void OnNavigatedTo(object? parameter)
    {
        LastNavigatedToParam = parameter;
    }

    public void OnNavigatedFrom()
    {
        NavigatedFromCalled = true;
    }
}

public class LiveTvTestViewModel : ViewModelBase
{
}

public class ScrollableTestViewModel : ViewModelBase, INavigationAware, IScrollRestorable
{
    public double ScrollPosition { get; set; }
    public double RestoredPosition { get; private set; }

    public double GetScrollPosition() => ScrollPosition;

    public void RestoreScrollPosition(double position)
    {
        RestoredPosition = position;
    }

    public void OnNavigatedTo(object? parameter) { }
    public void OnNavigatedFrom() { }
}
