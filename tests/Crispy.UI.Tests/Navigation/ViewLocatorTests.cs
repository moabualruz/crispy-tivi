using Avalonia.Controls;
using Avalonia.Headless.XUnit;

using Crispy.UI.ViewModels;

using FluentAssertions;

using Microsoft.Extensions.DependencyInjection;

using Xunit;

namespace Crispy.UI.Tests.Navigation;

/// <summary>
/// Tests for DI-aware ViewLocator.
/// </summary>
[Trait("Category", "Unit")]
public class ViewLocatorTests
{
    [Fact]
    public void Match_ReturnsTrueForViewModelBase()
    {
        var sp = new ServiceCollection().BuildServiceProvider();
        var locator = new ViewLocator(sp);

        locator.Match(new TestViewModelForLocator()).Should().BeTrue();
    }

    [Fact]
    public void Match_ReturnsFalseForNonViewModel()
    {
        var sp = new ServiceCollection().BuildServiceProvider();
        var locator = new ViewLocator(sp);

        locator.Match("not a viewmodel").Should().BeFalse();
    }

    [Fact]
    public void Match_ReturnsFalseForNull()
    {
        var sp = new ServiceCollection().BuildServiceProvider();
        var locator = new ViewLocator(sp);

        locator.Match(null).Should().BeFalse();
    }

    [AvaloniaFact]
    public void Build_ReturnsFallbackTextBlock_WhenViewNotRegistered()
    {
        var sp = new ServiceCollection().BuildServiceProvider();
        var locator = new ViewLocator(sp);

        var result = locator.Build(new TestViewModelForLocator());

        result.Should().BeOfType<TextBlock>();
    }

    [AvaloniaFact]
    public void Build_ReturnsTextBlock_WithNoViewModelMessage_WhenParamIsNull()
    {
        var sp = new ServiceCollection().BuildServiceProvider();
        var locator = new ViewLocator(sp);

        var result = locator.Build(null);

        result.Should().BeOfType<TextBlock>();
        ((TextBlock)result).Text.Should().Be("No ViewModel provided");
    }

    [AvaloniaFact]
    public void Build_ReturnsViewFromDI_WhenViewIsRegistered()
    {
        // ConventionStubViewModel lives in Crispy.UI.Tests.Navigation.ViewModels →
        // resolves to Crispy.UI.Tests.Navigation.Views.ConventionStubView by convention.
        // View is registered in DI — _serviceProvider.GetService() path executes.
        var services = new ServiceCollection();
        services.AddTransient<Crispy.UI.Tests.Navigation.Views.ConventionStubView>();
        var sp = services.BuildServiceProvider();
        var locator = new ViewLocator(sp);

        var result = locator.Build(new Crispy.UI.Tests.Navigation.ViewModels.ConventionStubViewModel());

        result.Should().BeOfType<Crispy.UI.Tests.Navigation.Views.ConventionStubView>();
    }

    [AvaloniaFact]
    public void Build_ReturnsViewViaActivator_WhenViewExistsButNotInDI()
    {
        // View type exists in the assembly (ConventionStubView) but NOT registered in DI
        // so Activator.CreateInstance fallback path executes.
        var sp = new ServiceCollection().BuildServiceProvider();
        var locator = new ViewLocator(sp);

        var result = locator.Build(new Crispy.UI.Tests.Navigation.ViewModels.ConventionStubViewModel());

        result.Should().BeAssignableTo<Control>();
        result.Should().NotBeOfType<TextBlock>();
    }

    [AvaloniaFact]
    public void Build_ReturnsTextBlock_WhenViewTypeNotFound_MessageStartsWithViewNotFound()
    {
        var sp = new ServiceCollection().BuildServiceProvider();
        var locator = new ViewLocator(sp);

        var result = locator.Build(new TestViewModelForLocator());

        result.Should().BeOfType<TextBlock>();
        ((TextBlock)result).Text.Should().StartWith("View not found:");
    }
}

public class TestViewModelForLocator : ViewModelBase
{
}

