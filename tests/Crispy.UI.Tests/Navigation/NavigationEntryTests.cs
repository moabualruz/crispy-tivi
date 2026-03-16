using Crispy.UI.Navigation;
using Crispy.UI.ViewModels;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.Navigation;

/// <summary>
/// Unit tests for <see cref="NavigationEntry"/>.
/// </summary>
[Trait("Category", "Unit")]
public class NavigationEntryTests
{
    private static ViewModelBase FakeVm() => Substitute.For<ViewModelBase>();

    [Fact]
    public void Constructor_StoresViewModel_WhenProvided()
    {
        var vm = FakeVm();

        var entry = new NavigationEntry(vm, 0, null);

        entry.ViewModel.Should().BeSameAs(vm);
    }

    [Fact]
    public void Constructor_StoresScrollPosition_WhenProvided()
    {
        var entry = new NavigationEntry(FakeVm(), 123.45, null);

        entry.ScrollPosition.Should().Be(123.45);
    }

    [Fact]
    public void Constructor_StoresNullParameter_WhenNotProvided()
    {
        var entry = new NavigationEntry(FakeVm(), 0, null);

        entry.Parameter.Should().BeNull();
    }

    [Fact]
    public void Constructor_StoresParameter_WhenProvided()
    {
        var param = new object();

        var entry = new NavigationEntry(FakeVm(), 0, param);

        entry.Parameter.Should().BeSameAs(param);
    }

    [Fact]
    public void Equality_ReturnsTrue_WhenAllFieldsMatch()
    {
        var vm = FakeVm();
        var param = new object();

        var a = new NavigationEntry(vm, 42.0, param);
        var b = new NavigationEntry(vm, 42.0, param);

        a.Should().Be(b);
    }

    [Fact]
    public void Equality_ReturnsFalse_WhenScrollPositionDiffers()
    {
        var vm = FakeVm();

        var a = new NavigationEntry(vm, 1.0, null);
        var b = new NavigationEntry(vm, 2.0, null);

        a.Should().NotBe(b);
    }

    [Fact]
    public void Equality_ReturnsFalse_WhenViewModelDiffers()
    {
        var a = new NavigationEntry(FakeVm(), 0, null);
        var b = new NavigationEntry(FakeVm(), 0, null);

        a.Should().NotBe(b);
    }

    [Fact]
    public void Equality_ReturnsFalse_WhenParameterDiffers()
    {
        var vm = FakeVm();

        var a = new NavigationEntry(vm, 0, "x");
        var b = new NavigationEntry(vm, 0, "y");

        a.Should().NotBe(b);
    }

    [Fact]
    public void With_UpdatesScrollPosition_LeavingOtherFieldsUnchanged()
    {
        var vm = FakeVm();
        var param = new object();
        var entry = new NavigationEntry(vm, 10.0, param);

        var updated = entry with { ScrollPosition = 99.0 };

        updated.ViewModel.Should().BeSameAs(vm);
        updated.ScrollPosition.Should().Be(99.0);
        updated.Parameter.Should().BeSameAs(param);
    }
}
