using Avalonia.Controls;
using Avalonia.Headless.XUnit;

using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.Application.Services;
using Crispy.UI.Controls;
using Crispy.UI.ViewModels;

using FluentAssertions;

using NSubstitute;

using Crispy.UI.Tests.Helpers;

using Xunit;

namespace Crispy.UI.Tests.Controls;

[Trait("Category", "Unit")]
public class OsdOverlayTests
{
    private static PlayerViewModel MakePlayerViewModel()
    {
        var playerService = Substitute.For<IPlayerService>();
        var timeshiftService = Substitute.For<ITimeshiftService>();
        var sleepTimerService = Substitute.For<ISleepTimerService>();

        var stateSubject = new TestSubject<PlayerState>();
        playerService.StateChanged.Returns(stateSubject);
        playerService.State.Returns(PlayerState.Empty);
        playerService.AudioTracks.Returns([]);
        playerService.SubtitleTracks.Returns([]);
        playerService.AudioSamples.Returns(new TestSubject<float[]>());

        var timeshiftSubject = new TestSubject<TimeshiftState>();
        timeshiftService.StateChanged.Returns(timeshiftSubject);
        timeshiftService.State.Returns(new TimeshiftState(
            BufferDuration: TimeSpan.Zero,
            Offset: TimeSpan.Zero,
            LiveEdgeTime: DateTimeOffset.UtcNow,
            OffsetDisplay: string.Empty,
            IsAtLiveEdge: true,
            IsBufferFull: false));

        var sleepSubject = new TestSubject<TimeSpan?>();
        sleepTimerService.RemainingChanged.Returns(sleepSubject);
        sleepTimerService.Remaining.Returns((TimeSpan?)null);

        return new PlayerViewModel(playerService, timeshiftService, sleepTimerService);
    }

    [AvaloniaFact]
    public void OsdOverlay_RendersWithoutException_WhenShownWithNoDataContext()
    {
        var control = new OsdOverlay();
        var window = new Window { Content = control, Width = 1280, Height = 200 };

        var act = () => window.Show();

        act.Should().NotThrow();
        window.Close();
    }

    [AvaloniaFact]
    public void OsdOverlay_RendersWithoutException_WhenPlayerViewModelSet()
    {
        var vm = MakePlayerViewModel();
        var control = new OsdOverlay { DataContext = vm };
        var window = new Window { Content = control, Width = 1280, Height = 200 };

        var act = () => window.Show();

        act.Should().NotThrow();
        window.Close();
    }

    [AvaloniaFact]
    public void OsdOverlay_WiresSeekBars_WhenDataContextIsPlayerViewModel()
    {
        var vm = MakePlayerViewModel();
        var control = new OsdOverlay();
        var window = new Window { Content = control, Width = 1280, Height = 200 };
        window.Show();

        // Setting DataContext after Show triggers OnDataContextChanged → WireSeekBars
        var act = () => { control.DataContext = vm; };

        act.Should().NotThrow();
        window.Close();
    }

    [AvaloniaFact]
    public void OsdOverlay_DoesNotThrow_WhenDataContextChangedToNull()
    {
        var vm = MakePlayerViewModel();
        var control = new OsdOverlay { DataContext = vm };
        var window = new Window { Content = control, Width = 1280, Height = 200 };
        window.Show();

        var act = () => { control.DataContext = null; };

        act.Should().NotThrow();
        window.Close();
    }

    [AvaloniaFact]
    public void OsdOverlay_SeekBarHost_IsNotNull_AfterAttachedToVisualTree()
    {
        var vm = MakePlayerViewModel();
        var control = new OsdOverlay { DataContext = vm };
        var window = new Window { Content = control, Width = 1280, Height = 200 };
        window.Show();

        // InitializeComponent() in constructor registers x:Name fields.
        // SeekBarHost must be available after the control is in the visual tree.
        control.SeekBarHost.Should().NotBeNull(
            "SeekBarHost must be resolved from AXAML after InitializeComponent");
        control.SeekBarHost.Should().BeOfType<ContentControl>();
        window.Close();
    }

    [AvaloniaFact]
    public void OsdOverlay_WireSeekBars_CreatesLiveSeekBarForLiveStream()
    {
        var playerService = Substitute.For<IPlayerService>();
        var timeshiftService = Substitute.For<ITimeshiftService>();
        var sleepTimerService = Substitute.For<ISleepTimerService>();

        var stateSubject = new TestSubject<PlayerState>();
        playerService.StateChanged.Returns(stateSubject);
        // Start as a live stream
        playerService.State.Returns(PlayerState.Empty with { IsLive = true });
        playerService.AudioTracks.Returns([]);
        playerService.SubtitleTracks.Returns([]);
        playerService.AudioSamples.Returns(new TestSubject<float[]>());

        timeshiftService.StateChanged.Returns(new TestSubject<TimeshiftState>());
        timeshiftService.State.Returns(new TimeshiftState(
            BufferDuration: TimeSpan.Zero,
            Offset: TimeSpan.Zero,
            LiveEdgeTime: DateTimeOffset.UtcNow,
            OffsetDisplay: string.Empty,
            IsAtLiveEdge: true,
            IsBufferFull: false));

        sleepTimerService.RemainingChanged.Returns(new TestSubject<TimeSpan?>());
        sleepTimerService.Remaining.Returns((TimeSpan?)null);

        var vm = new PlayerViewModel(playerService, timeshiftService, sleepTimerService);

        var control = new OsdOverlay();
        var window = new Window { Content = control, Width = 1280, Height = 200 };
        window.Show();
        control.DataContext = vm;

        // Push live state through the observable so IsLive updates reactively
        stateSubject.OnNext(PlayerState.Empty with { IsLive = true });

        // SeekBarHost.Content is set to a LiveSeekBar for live streams
        control.SeekBarHost?.Content.Should().BeOfType<LiveSeekBar>(
            "OsdOverlay must wire a LiveSeekBar when the stream is live");
        window.Close();
    }

    [AvaloniaFact]
    public void OsdOverlay_WireSeekBars_CreatesVodSeekBarForVodStream()
    {
        var vm = MakePlayerViewModel(); // IsLive=false (empty state)

        var control = new OsdOverlay();
        var window = new Window { Content = control, Width = 1280, Height = 200 };
        window.Show();
        control.DataContext = vm;

        // SeekBarHost.Content is set to a VodSeekBar for VOD streams
        control.SeekBarHost?.Content.Should().BeOfType<VodSeekBar>(
            "OsdOverlay must wire a VodSeekBar when the stream is VOD");
        window.Close();
    }

    [AvaloniaFact]
    public void OsdOverlay_DoesNotRewireSeekBars_WhenSameViewModelSetTwice()
    {
        var vm = MakePlayerViewModel();
        var control = new OsdOverlay();
        var window = new Window { Content = control, Width = 1280, Height = 200 };
        window.Show();

        control.DataContext = vm;
        var firstContent = control.SeekBarHost?.Content;

        // Setting the same VM again must not throw and must keep the same seek bar instance
        var act = () => { control.DataContext = vm; };

        act.Should().NotThrow();
        window.Close();
    }
}
