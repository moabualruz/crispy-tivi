using Crispy.UI.ViewModels;

using FluentAssertions;

using Xunit;

namespace Crispy.UI.Tests.ViewModels;

[Trait("Category", "Unit")]
public class HomeViewModelTests
{
    private readonly HomeViewModel _sut = new();

    [Fact]
    public void Constructor_DoesNotThrow()
    {
        var act = () => new HomeViewModel();
        act.Should().NotThrow();
    }

    [Fact]
    public void Title_IsHome()
    {
        _sut.Title.Should().Be("Home");
    }
}
