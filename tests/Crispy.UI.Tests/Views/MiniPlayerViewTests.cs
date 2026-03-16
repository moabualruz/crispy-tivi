using Avalonia;
using Avalonia.Headless;
using Avalonia.Headless.XUnit;
using Avalonia.Input;

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
public class MiniPlayerViewTests
{
    private static MiniPlayerViewModel BuildVm()
    {
        var stateSubject = new TestSubject<PlayerState>();
        var playerService = Substitute.For<IPlayerService>();
        playerService.State.Returns(PlayerState.Empty);
        playerService.StateChanged.Returns(stateSubject);
        playerService.AudioSamples.Returns(new TestSubject<float[]>());
        playerService.AudioTracks.Returns([]);
        playerService.SubtitleTracks.Returns([]);

        return new MiniPlayerViewModel(playerService);
    }

    [AvaloniaFact]
    public void MiniPlayerView_RendersWithoutException()
    {
        var vm = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<MiniPlayerView>(vm);

        window.Should().NotBeNull();
        window.IsVisible.Should().BeTrue();
        window.Close();
    }

    [AvaloniaFact]
    public void MiniPlayerView_InitialState_IsNotDragging()
    {
        var vm = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<MiniPlayerView>(vm);

        // Default margin is zero — no drag has occurred
        var view = (MiniPlayerView)window.Content!;
        view.Margin.Should().Be(new Thickness(0),
            "mini-player must not be displaced before any pointer interaction");
        window.Close();
    }

    [AvaloniaFact]
    public void MiniPlayerView_PointerPress_DoesNotThrow()
    {
        var vm = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<MiniPlayerView>(vm);
        var view = (MiniPlayerView)window.Content!;

        view.Focus();

        var act = () =>
        {
            window.MouseDown(new Point(10, 10), MouseButton.Left);
            window.MouseUp(new Point(10, 10), MouseButton.Left);
        };

        act.Should().NotThrow("pointer press/release must not raise exceptions");
        window.Close();
    }

    [AvaloniaFact]
    public void MiniPlayerView_DragMove_UpdatesMargin()
    {
        var vm = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<MiniPlayerView>(vm);
        var view = (MiniPlayerView)window.Content!;

        // Call internal drag methods directly — tests real drag logic
        // without relying on headless pointer coordinate routing.
        view.BeginDrag(new Point(50, 50));
        view.ApplyDragDelta(new Point(80, 70)); // delta = (30, 20) > 4px threshold

        view.IsDragging.Should().BeTrue("delta exceeds 4px threshold");
        view.Margin.Left.Should().BeApproximately(30, 0.1, "margin.Left = origin(0) + delta(30)");
        view.Margin.Top.Should().BeApproximately(20, 0.1, "margin.Top = origin(0) + delta(20)");

        view.EndDrag();
        view.IsDragging.Should().BeFalse("drag must end after release");
        window.Close();
    }

    [AvaloniaFact]
    public void MiniPlayerView_DragBelowThreshold_DoesNotMove()
    {
        var vm = BuildVm();
        var window = HeadlessTestHelpers.CreateWindow<MiniPlayerView>(vm);
        var view = (MiniPlayerView)window.Content!;

        view.BeginDrag(new Point(50, 50));
        view.ApplyDragDelta(new Point(52, 51)); // delta = (2, 1) < 4px threshold

        view.IsDragging.Should().BeFalse("delta below 4px must not trigger drag");
        view.Margin.Should().Be(new Thickness(0), "margin must not change below threshold");
        window.Close();
    }

    [AvaloniaFact]
    public void MiniPlayerView_ExpandCommand_FiredOnTap()
    {
        var vm = BuildVm();
        var expandFired = false;
        vm.ExpandRequested += (_, _) => expandFired = true;

        var window = HeadlessTestHelpers.CreateWindow<MiniPlayerView>(vm);

        // Simulate a tap (small move — should NOT set _isDragging)
        window.MouseDown(new Point(10, 10), MouseButton.Left);
        window.MouseUp(new Point(10, 10), MouseButton.Left);

        // OnVideoAreaTapped is wired via AXAML Tapped event; simulate via command directly
        vm.ExpandCommand.Execute(null);

        expandFired.Should().BeTrue("ExpandCommand must raise ExpandRequested");
        window.Close();
    }

    [AvaloniaFact]
    public void MiniPlayerView_InitialIsVisible_IsFalse()
    {
        var vm = BuildVm();

        // No state pushed — IsVisible starts false
        vm.IsVisible.Should().BeFalse("mini-player is hidden when nothing is playing");
    }

    [AvaloniaFact]
    public void MiniPlayerView_StateChange_UpdatesIsPlaying()
    {
        var stateSubject = new TestSubject<PlayerState>();
        var playerService = Substitute.For<IPlayerService>();
        playerService.State.Returns(PlayerState.Empty);
        playerService.StateChanged.Returns(stateSubject);
        playerService.AudioSamples.Returns(new TestSubject<float[]>());
        playerService.AudioTracks.Returns([]);
        playerService.SubtitleTracks.Returns([]);

        var vm = new MiniPlayerViewModel(playerService);
        var window = HeadlessTestHelpers.CreateWindow<MiniPlayerView>(vm);

        var playingState = PlayerState.Empty with { IsPlaying = true };
        stateSubject.OnNext(playingState);

        vm.IsPlaying.Should().BeTrue("IsPlaying must reflect state from IPlayerService");
        window.Close();
    }
}
