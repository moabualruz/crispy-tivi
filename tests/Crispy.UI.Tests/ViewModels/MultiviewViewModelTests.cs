using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.UI.Tests.Helpers;
using Crispy.UI.ViewModels;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.ViewModels;

/// <summary>
/// Unit tests for MultiviewViewModel — verifies slot initialisation,
/// layout state defaults, and saved-layout name defaults.
/// </summary>
[Trait("Category", "Unit")]
public class MultiviewViewModelTests
{
    private readonly IMultiviewService _multiviewService;
    private readonly TestSubject<IReadOnlyList<MultiviewSlot>> _slotsSubject;
    private readonly MultiviewViewModel _sut;

    public MultiviewViewModelTests()
    {
        _slotsSubject = new TestSubject<IReadOnlyList<MultiviewSlot>>();

        var slots = new List<MultiviewSlot>
        {
            new MultiviewSlot(0, null, false, false, false),
            new MultiviewSlot(1, null, false, false, false),
            new MultiviewSlot(2, null, false, false, false),
            new MultiviewSlot(3, null, false, false, false),
        };

        var playerService = Substitute.For<IPlayerService>();

        _multiviewService = Substitute.For<IMultiviewService>();
        _multiviewService.Slots.Returns(slots);
        _multiviewService.SlotsChanged.Returns(_slotsSubject);
        _multiviewService.GetSlotPlayer(Arg.Any<int>()).Returns(playerService);
        _multiviewService.GetSavedLayoutsAsync().Returns(Task.FromResult<IReadOnlyList<SavedLayout>>([]));

        _sut = new MultiviewViewModel(_multiviewService);
    }

    [Fact]
    public void Title_IsMultiview()
    {
        _sut.Title.Should().Be("Multiview",
            "MultiviewViewModel must identify itself as 'Multiview' for navigation and screen headings");
    }

    [Fact]
    public void Slots_HasFourItems()
    {
        _sut.Slots.Should().HaveCount(4,
            "Multiview always operates with exactly 4 slots in a 2×2 quad grid (PLR-29)");
    }

    [Fact]
    public void IsGridMode_TrueInitially()
    {
        _sut.IsGridMode.Should().BeTrue(
            "The default Multiview layout is the 4-up grid; no slot is expanded on startup");
    }

    [Fact]
    public void ExpandedSlotIndex_IsMinusOneInitially()
    {
        _sut.ExpandedSlotIndex.Should().Be(-1,
            "No slot is expanded on startup; sentinel value -1 means 'none expanded'");
    }

    [Fact]
    public void NewLayoutName_DefaultsToEmpty()
    {
        _sut.NewLayoutName.Should().BeEmpty(
            "The save-layout name input field must start empty so the user can type a fresh name");
    }
}
