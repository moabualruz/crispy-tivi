using Avalonia.Controls;
using Avalonia.Headless.XUnit;

using Crispy.UI.ViewModels;

using FluentAssertions;

using Microsoft.Extensions.DependencyInjection;

using Xunit;

namespace Crispy.UI.Tests;

/// <summary>
/// Unit tests for <see cref="ViewLocator"/>.
/// </summary>
[Trait("Category", "Unit")]
public class ViewLocatorTests
{
    private static ViewLocator BuildSut(Action<ServiceCollection>? configure = null)
    {
        var services = new ServiceCollection();
        configure?.Invoke(services);
        var provider = services.BuildServiceProvider();
        return new ViewLocator(provider);
    }

    [AvaloniaFact]
    public void Match_ReturnsTrue_WhenDataIsViewModelBase()
    {
        var sut = BuildSut();
        var vm = new FakeViewModel();

        var result = sut.Match(vm);

        result.Should().BeTrue();
    }

    [Fact]
    public void Match_ReturnsFalse_WhenDataIsNull()
    {
        var sut = BuildSut();

        var result = sut.Match(null);

        result.Should().BeFalse();
    }

    [Fact]
    public void Match_ReturnsFalse_WhenDataIsPlainString()
    {
        var sut = BuildSut();

        var result = sut.Match("not a viewmodel");

        result.Should().BeFalse();
    }

    [Fact]
    public void Match_ReturnsFalse_WhenDataIsInteger()
    {
        var sut = BuildSut();

        var result = sut.Match(42);

        result.Should().BeFalse();
    }

    [AvaloniaFact]
    public void Build_ReturnsTextBlock_WhenParamIsNull()
    {
        var sut = BuildSut();

        var result = sut.Build(null);

        result.Should().BeOfType<TextBlock>();
        ((TextBlock)result).Text.Should().Be("No ViewModel provided");
    }

    [AvaloniaFact]
    public void Build_ReturnsTextBlock_WhenViewTypeNotFound()
    {
        var sut = BuildSut();
        var vm = new FakeViewModel();

        // FakeViewModel has no corresponding FakeView in the assembly
        var result = sut.Build(vm);

        result.Should().BeOfType<TextBlock>();
        ((TextBlock)result).Text.Should().StartWith("View not found:");
    }

    [AvaloniaFact]
    public void Build_ReturnsTextBlock_WhenParamHasNoViewModelInName()
    {
        var sut = BuildSut();

        // Use an object whose type name doesn't follow ViewModel convention
        var result = sut.Build(new NotAViewModel());

        result.Should().BeOfType<TextBlock>();
    }
}

/// <summary>
/// Minimal ViewModel stub — no corresponding View exists so ViewLocator will return "View not found".
/// </summary>
internal sealed class FakeViewModel : ViewModelBase { }

/// <summary>
/// Plain class with no ViewModel suffix — exercises the "unknown type" path.
/// </summary>
internal sealed class NotAViewModel { }
