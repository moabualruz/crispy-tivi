using Crispy.UI.Navigation;
using Crispy.UI.ViewModels;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.ViewModels;

[Trait("Category", "Unit")]
public class MainViewModelTests
{
    private static (MainViewModel sut, INavigationService nav) Build()
    {
        var nav = Substitute.For<INavigationService>();
        nav.CanGoBack.Returns(false);
        var sut = new MainViewModel(nav);
        return (sut, nav);
    }

    // ── Constructor / defaults ─────────────────────────────────────────────────

    [Fact]
    public void Constructor_DoesNotThrow()
    {
        var act = () => Build();
        act.Should().NotThrow();
    }

    [Fact]
    public void Title_IsCrispyTivi()
    {
        var (sut, _) = Build();
        sut.Title.Should().Be("CrispyTivi");
    }

    [Fact]
    public void IsRailExpanded_DefaultsFalse()
    {
        var (sut, _) = Build();
        sut.IsRailExpanded.Should().BeFalse();
    }

    [Fact]
    public void SelectedNavItem_DefaultsNull()
    {
        var (sut, _) = Build();
        sut.SelectedNavItem.Should().BeNull();
    }

    [Fact]
    public void PrimaryNavItems_HasFiveItems()
    {
        var (sut, _) = Build();
        sut.PrimaryNavItems.Should().HaveCount(5);
    }

    [Fact]
    public void SecondaryNavItems_HasOneItem()
    {
        var (sut, _) = Build();
        sut.SecondaryNavItems.Should().HaveCount(1);
    }

    [Fact]
    public void PrimaryNavItems_FirstIsHome()
    {
        var (sut, _) = Build();
        sut.PrimaryNavItems[0].Name.Should().Be("Home");
        sut.PrimaryNavItems[0].ViewModelType.Should().Be(typeof(HomeViewModel));
    }

    [Fact]
    public void SecondaryNavItems_FirstIsSettings()
    {
        var (sut, _) = Build();
        sut.SecondaryNavItems[0].Name.Should().Be("Settings");
        sut.SecondaryNavItems[0].IsSecondary.Should().BeTrue();
    }

    // ── Constructor subscribes and calls NavigateTo<HomeViewModel> ────────────

    [Fact]
    public void Constructor_CallsNavigateToHome()
    {
        var (_, nav) = Build();
        nav.Received(1).NavigateTo<HomeViewModel>();
    }

    [Fact]
    public void Constructor_SubscribesToNavigatedEvent()
    {
        var nav = Substitute.For<INavigationService>();
        nav.CanGoBack.Returns(false);

        var sut = new MainViewModel(nav);

        // Raise Navigated — CurrentPage should be updated.
        var fakePage = Substitute.For<ViewModelBase>();
        nav.Navigated += Raise.Event<Action<ViewModelBase>>(fakePage);

        sut.CurrentPage.Should().Be(fakePage);
    }

    // ── CanGoBack ──────────────────────────────────────────────────────────────

    [Fact]
    public void CanGoBack_DelegatestoNavigationService()
    {
        var (sut, nav) = Build();

        nav.CanGoBack.Returns(true);
        sut.CanGoBack.Should().BeTrue();

        nav.CanGoBack.Returns(false);
        sut.CanGoBack.Should().BeFalse();
    }

    // ── GoBackCommand ──────────────────────────────────────────────────────────

    [Fact]
    public void GoBackCommand_CallsGoBack()
    {
        var (sut, nav) = Build();
        sut.GoBackCommand.Execute(null);
        nav.Received(1).GoBack();
    }

    // ── ExpandRail / CollapseRail ──────────────────────────────────────────────

    [Fact]
    public void ExpandRail_SetsIsRailExpandedTrue()
    {
        var (sut, _) = Build();
        sut.ExpandRail();
        sut.IsRailExpanded.Should().BeTrue();
    }

    [Fact]
    public void CollapseRail_SetsIsRailExpandedFalse()
    {
        var (sut, _) = Build();
        sut.IsRailExpanded = true;
        sut.CollapseRail();
        sut.IsRailExpanded.Should().BeFalse();
    }

    // ── SelectedNavItem change triggers navigation ────────────────────────────

    [Fact]
    public void SelectedNavItem_WhenSet_CallsNavigateTo()
    {
        var (sut, nav) = Build();
        nav.ClearReceivedCalls();

        // Use an existing item from the populated PrimaryNavItems list.
        var liveTvItem = sut.PrimaryNavItems.First(i => i.ViewModelType == typeof(LiveTvViewModel));
        sut.SelectedNavItem = liveTvItem;

        nav.Received(1).NavigateTo(typeof(LiveTvViewModel), Arg.Any<object?>());
    }

    [Fact]
    public void SelectedNavItem_WhenSetNull_DoesNotCallNavigateTo()
    {
        var (sut, nav) = Build();
        nav.ClearReceivedCalls();

        sut.SelectedNavItem = null;

        nav.DidNotReceive().NavigateTo(Arg.Any<Type>(), Arg.Any<object?>());
    }
}
