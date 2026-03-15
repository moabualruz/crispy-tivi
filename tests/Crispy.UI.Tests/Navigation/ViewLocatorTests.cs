using Avalonia.Controls;

using Crispy.UI.ViewModels;

using FluentAssertions;

using Microsoft.Extensions.DependencyInjection;

using Xunit;

namespace Crispy.UI.Tests.Navigation;

/// <summary>
/// Tests for DI-aware ViewLocator.
/// </summary>
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

    [Fact]
    public void Build_ReturnsFallbackTextBlock_WhenViewNotRegistered()
    {
        var sp = new ServiceCollection().BuildServiceProvider();
        var locator = new ViewLocator(sp);

        var result = locator.Build(new TestViewModelForLocator());

        result.Should().BeOfType<TextBlock>();
    }
}

public class TestViewModelForLocator : ViewModelBase
{
}
