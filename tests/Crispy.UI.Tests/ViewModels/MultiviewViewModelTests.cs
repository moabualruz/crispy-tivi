using Avalonia.Headless.XUnit;

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

    // ─── OnSlotsChanged (lines 67-79) ────────────────────────────────────────

    [AvaloniaFact]
    public async Task OnSlotsChanged_WithExpandedSlot_SetsIsGridModeFalseAndExpandedIndex()
    {
        // Arrange: emit a slots update where slot 2 is expanded
        var updatedSlots = new List<MultiviewSlot>
        {
            new MultiviewSlot(0, null, false, false, false),
            new MultiviewSlot(1, null, false, false, false),
            new MultiviewSlot(2, null, true,  false, true),   // IsExpanded = true
            new MultiviewSlot(3, null, false, false, false),
        };

        // Act
        _slotsSubject.OnNext(updatedSlots);
        // Give the UI-thread post a chance to run (headless Avalonia dispatcher)
        await Task.Delay(50);

        // Assert
        _sut.IsGridMode.Should().BeFalse("a slot is expanded so the grid is hidden");
        _sut.ExpandedSlotIndex.Should().Be(2, "slot 2 is the expanded one");
    }

    [AvaloniaFact]
    public async Task OnSlotsChanged_NoExpandedSlot_SetsIsGridModeTrue()
    {
        // Arrange: first expand a slot, then collapse
        var expanded = new List<MultiviewSlot>
        {
            new MultiviewSlot(0, null, true, false, true),
            new MultiviewSlot(1, null, false, false, false),
            new MultiviewSlot(2, null, false, false, false),
            new MultiviewSlot(3, null, false, false, false),
        };
        _slotsSubject.OnNext(expanded);
        await Task.Delay(50);

        var collapsed = new List<MultiviewSlot>
        {
            new MultiviewSlot(0, null, false, false, false),
            new MultiviewSlot(1, null, false, false, false),
            new MultiviewSlot(2, null, false, false, false),
            new MultiviewSlot(3, null, false, false, false),
        };
        _slotsSubject.OnNext(collapsed);
        await Task.Delay(50);

        _sut.IsGridMode.Should().BeTrue("no slot is expanded so grid mode is restored");
        _sut.ExpandedSlotIndex.Should().Be(-1, "sentinel -1 means no slot expanded");
    }

    [AvaloniaFact]
    public async Task OnSlotsChanged_UpdatesSlotViewModelProperties()
    {
        var request = new PlaybackRequest("http://stream/a", PlaybackContentType.LiveTv, Title: "Channel A");
        var updatedSlots = new List<MultiviewSlot>
        {
            new MultiviewSlot(0, request, true, true, false),
            new MultiviewSlot(1, null, false, false, false),
            new MultiviewSlot(2, null, false, false, false),
            new MultiviewSlot(3, null, false, false, false),
        };

        _slotsSubject.OnNext(updatedSlots);
        await Task.Delay(50);

        _sut.Slots[0].IsActive.Should().BeTrue();
        _sut.Slots[0].IsAudioActive.Should().BeTrue();
        _sut.Slots[0].ChannelName.Should().Be("Channel A");
    }

    // ─── SaveLayoutCommand (line 113-124) ────────────────────────────────────

    [Fact]
    public async Task SaveLayoutCommand_WithNonEmptyName_CallsSaveLayoutAsyncAndClearsName()
    {
        _multiviewService.GetSavedLayoutsAsync()
            .Returns(Task.FromResult<IReadOnlyList<SavedLayout>>([]));

        _sut.NewLayoutName = "My Layout";

        await _sut.SaveLayoutCommand.ExecuteAsync(null);

        await _multiviewService.Received(1).SaveLayoutAsync("My Layout");
        _sut.NewLayoutName.Should().BeEmpty("name field is cleared after successful save");
    }

    [Fact]
    public async Task SaveLayoutCommand_WithEmptyName_DoesNotCallService()
    {
        _sut.NewLayoutName = "   ";

        await _sut.SaveLayoutCommand.ExecuteAsync(null);

        await _multiviewService.DidNotReceive().SaveLayoutAsync(Arg.Any<string>());
    }

    // ─── AssignChannel command (line 147) ────────────────────────────────────

    [Fact]
    public void AssignChannelCommand_RaisesAssignChannelRequestedEvent()
    {
        int? raisedSlot = null;
        _sut.AssignChannelRequested += (_, idx) => raisedSlot = idx;

        _sut.AssignChannelCommand.Execute(2);

        raisedSlot.Should().Be(2, "the command should raise the event with the slot index");
    }

    // ─── Dispose (line 151) ──────────────────────────────────────────────────

    [Fact]
    public void Dispose_DoesNotThrow()
    {
        var act = () => _sut.Dispose();
        act.Should().NotThrow("Dispose must be idempotent and safe");
    }

    // ─── SwapSlotsCommand (line 133-134) ─────────────────────────────────────

    [Fact]
    public async Task SwapSlotsCommand_CallsServiceWithCorrectArguments()
    {
        await _sut.SwapSlotsCommand.ExecuteAsync((0, 3));

        await _multiviewService.Received(1).SwapSlotsAsync(0, 3);
    }

    // ─── SetAudioSlotCommand ──────────────────────────────────────────────────

    [Fact]
    public async Task SetAudioSlotCommand_CallsServiceWithCorrectSlotIndex()
    {
        await _sut.SetAudioSlotCommand.ExecuteAsync(1);

        await _multiviewService.Received(1).SetActiveAudioSlotAsync(1);
    }

    // ─── ExpandSlotCommand ────────────────────────────────────────────────────

    [Fact]
    public async Task ExpandSlotCommand_CallsServiceWithCorrectSlotIndex()
    {
        await _sut.ExpandSlotCommand.ExecuteAsync(2);

        await _multiviewService.Received(1).ExpandSlotAsync(2);
    }

    // ─── CollapseCommand ──────────────────────────────────────────────────────

    [Fact]
    public async Task CollapseCommand_CallsCollapseToGrid()
    {
        await _sut.CollapseCommand.ExecuteAsync(null);

        await _multiviewService.Received(1).CollapseToGridAsync();
    }

    // ─── ClearSlotCommand ─────────────────────────────────────────────────────

    [Fact]
    public async Task ClearSlotCommand_CallsServiceWithCorrectSlotIndex()
    {
        await _sut.ClearSlotCommand.ExecuteAsync(0);

        await _multiviewService.Received(1).ClearSlotAsync(0);
    }

    // ─── LoadLayoutCommand ────────────────────────────────────────────────────

    [Fact]
    public async Task LoadLayoutCommand_CallsServiceWithLayoutId()
    {
        await _sut.LoadLayoutCommand.ExecuteAsync("layout-42");

        await _multiviewService.Received(1).LoadLayoutAsync("layout-42");
    }

    // ─── MultiviewSlotViewModel ───────────────────────────────────────────────

    [Fact]
    public void MultiviewSlotViewModel_Update_SetsAllProperties()
    {
        var request = new PlaybackRequest("http://stream/b", PlaybackContentType.LiveTv, Title: "Test Channel", ChannelLogoUrl: "http://logo/img.png");
        var slot = new MultiviewSlot(1, request, true, true, true);
        var playerService = Substitute.For<IPlayerService>();

        var vm = new MultiviewSlotViewModel(slot, playerService);

        vm.SlotIndex.Should().Be(1);
        vm.IsActive.Should().BeTrue();
        vm.IsAudioActive.Should().BeTrue();
        vm.IsExpanded.Should().BeTrue();
        vm.ChannelName.Should().Be("Test Channel");
        vm.ChannelLogoUrl.Should().Be("http://logo/img.png");
        vm.PlayerService.Should().BeSameAs(playerService);
    }

    [Fact]
    public void MultiviewSlotViewModel_Update_WhenRequestIsNull_ClearsChannelNameAndLogo()
    {
        var slot = new MultiviewSlot(0, null, false, false, false);
        var playerService = Substitute.For<IPlayerService>();

        var vm = new MultiviewSlotViewModel(slot, playerService);

        vm.ChannelName.Should().BeNull();
        vm.ChannelLogoUrl.Should().BeNull();
        vm.IsActive.Should().BeFalse();
    }

    // ─── LoadSavedLayouts on construction ────────────────────────────────────

    [Fact]
    public async Task SavedLayouts_PopulatedAfterConstruction_WhenServiceReturnsLayouts()
    {
        var layouts = new List<SavedLayout>
        {
            new SavedLayout { Id = "id-1", Name = "Layout Alpha", StreamsJson = "[]", ProfileId = "default", CreatedAt = DateTimeOffset.UtcNow },
            new SavedLayout { Id = "id-2", Name = "Layout Beta",  StreamsJson = "[]", ProfileId = "default", CreatedAt = DateTimeOffset.UtcNow },
        };

        var subject = new TestSubject<IReadOnlyList<MultiviewSlot>>();
        var playerService = Substitute.For<IPlayerService>();
        var slots = new List<MultiviewSlot>
        {
            new MultiviewSlot(0, null, false, false, false),
            new MultiviewSlot(1, null, false, false, false),
            new MultiviewSlot(2, null, false, false, false),
            new MultiviewSlot(3, null, false, false, false),
        };

        var svc = Substitute.For<IMultiviewService>();
        svc.Slots.Returns(slots);
        svc.SlotsChanged.Returns(subject);
        svc.GetSlotPlayer(Arg.Any<int>()).Returns(playerService);
        svc.GetSavedLayoutsAsync().Returns(Task.FromResult<IReadOnlyList<SavedLayout>>(layouts));

        var vm = new MultiviewViewModel(svc);
        await Task.Delay(100);

        vm.SavedLayouts.Should().HaveCount(2);
        vm.SavedLayouts[0].Name.Should().Be("Layout Alpha");
    }
}
