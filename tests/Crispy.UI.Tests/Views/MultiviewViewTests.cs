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
}
