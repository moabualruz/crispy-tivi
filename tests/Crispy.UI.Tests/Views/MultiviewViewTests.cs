using Avalonia.Headless.XUnit;

using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.UI.Tests.Helpers;
using Crispy.UI.ViewModels;
using Crispy.UI.Views;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.Views;

[Trait("Category", "UI")]
public class MultiviewViewTests
{
    private static MultiviewViewModel BuildVm()
    {
        var slots = Enumerable.Range(0, 4)
            .Select(i => new MultiviewSlot(i, null, false, false, false))
            .ToList();

        var slotChanged = new TestSubject<IReadOnlyList<MultiviewSlot>>();

        var multiviewService = Substitute.For<IMultiviewService>();
        multiviewService.Slots.Returns(slots);
        multiviewService.SlotsChanged.Returns(slotChanged);
        multiviewService.GetSavedLayoutsAsync().Returns(Task.FromResult<IReadOnlyList<SavedLayout>>([]));

        for (var i = 0; i < 4; i++)
        {
            var playerService = Substitute.For<IPlayerService>();
            playerService.State.Returns(PlayerState.Empty);
            playerService.StateChanged.Returns(new TestSubject<PlayerState>());
            playerService.AudioSamples.Returns(new TestSubject<float[]>());
            playerService.AudioTracks.Returns([]);
            playerService.SubtitleTracks.Returns([]);
            multiviewService.GetSlotPlayer(i).Returns(playerService);
        }

        return new MultiviewViewModel(multiviewService);
    }

    [AvaloniaFact]
    public void MultiviewView_RendersWithoutException()
    {
        var vm = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<MultiviewView>(vm);

        window.Should().NotBeNull();
        window.IsVisible.Should().BeTrue();
        window.Close();
    }

    [AvaloniaFact]
    public void MultiviewView_InitialSlotCount_IsFour()
    {
        var vm = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<MultiviewView>(vm);

        vm.Slots.Should().HaveCount(4,
            "MultiviewViewModel must expose 4 slots matching the service");
        window.Close();
    }

    [AvaloniaFact]
    public void MultiviewView_SlotsChanged_UpdatesSlots()
    {
        var slots = Enumerable.Range(0, 4)
            .Select(i => new MultiviewSlot(i, null, false, false, false))
            .ToList();

        var slotChanged = new TestSubject<IReadOnlyList<MultiviewSlot>>();

        var multiviewService = Substitute.For<IMultiviewService>();
        multiviewService.Slots.Returns(slots);
        multiviewService.SlotsChanged.Returns(slotChanged);
        multiviewService.GetSavedLayoutsAsync().Returns(Task.FromResult<IReadOnlyList<SavedLayout>>([]));

        for (var i = 0; i < 4; i++)
        {
            var playerService = Substitute.For<IPlayerService>();
            playerService.State.Returns(PlayerState.Empty);
            playerService.StateChanged.Returns(new TestSubject<PlayerState>());
            playerService.AudioSamples.Returns(new TestSubject<float[]>());
            playerService.AudioTracks.Returns([]);
            playerService.SubtitleTracks.Returns([]);
            multiviewService.GetSlotPlayer(i).Returns(playerService);
        }

        var vm = new MultiviewViewModel(multiviewService);
        var window = HeadlessTestHelpers.CreateWindow<MultiviewView>(vm);

        // Push updated slots — VM must not throw
        var newSlots = Enumerable.Range(0, 4)
            .Select(i => new MultiviewSlot(i, null, true, false, false))
            .ToList<MultiviewSlot>();

        var act = () => slotChanged.OnNext(newSlots);

        act.Should().NotThrow("SlotsChanged event must be handled without exception");
        window.Close();
    }

    [AvaloniaFact]
    public void MultiviewView_SavedLayouts_InitiallyEmpty()
    {
        var vm = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<MultiviewView>(vm);

        vm.SavedLayouts.Should().BeEmpty(
            "no saved layouts are returned by the mock service");
        window.Close();
    }

    [AvaloniaFact]
    public void MultiviewView_DataContextChange_DoesNotThrow()
    {
        var vm1 = BuildVm();
        var vm2 = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<MultiviewView>(vm1);

        var view = (MultiviewView)window.Content!;

        var act = () => { view.DataContext = vm2; };

        act.Should().NotThrow("swapping DataContext must not throw");
        window.Close();
    }
}
