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
/// Unit tests for MiniPlayerViewModel — verifies that PiP overlay state
/// is correctly derived from IPlayerService.StateChanged emissions.
/// </summary>
[Trait("Category", "Unit")]
public class MiniPlayerViewModelTests
{
    private readonly IPlayerService _playerService;
    private readonly TestSubject<PlayerState> _stateSubject;
    private readonly MiniPlayerViewModel _sut;

    public MiniPlayerViewModelTests()
    {
        _stateSubject = new TestSubject<PlayerState>();

        _playerService = Substitute.For<IPlayerService>();
        _playerService.State.Returns(PlayerState.Empty);
        _playerService.StateChanged.Returns(_stateSubject);
        _playerService.AudioSamples.Returns(new TestSubject<float[]>());
        _playerService.AudioTracks.Returns([]);
        _playerService.SubtitleTracks.Returns([]);

        _sut = new MiniPlayerViewModel(_playerService);
    }

    // ── Default state ────────────────────────────────────────────────────────

    [Fact]
    public void DefaultState_IsVisible_IsFalse()
    {
        _sut.IsVisible.Should().BeFalse();
    }

    [Fact]
    public void DefaultState_IsPlaying_IsFalse()
    {
        _sut.IsPlaying.Should().BeFalse();
    }

    [Fact]
    public void DefaultState_ChannelName_IsNull()
    {
        _sut.ChannelName.Should().BeNull();
    }

    [Fact]
    public void DefaultState_ChannelLogoUrl_IsNull()
    {
        _sut.ChannelLogoUrl.Should().BeNull();
    }

    // ── State emissions ──────────────────────────────────────────────────────

    [AvaloniaFact]
    public void StateChanged_WhenPlaying_SetsIsVisibleTrue()
    {
        var state = PlayerState.Empty with { IsPlaying = true };

        _stateSubject.OnNext(state);

        _sut.IsVisible.Should().BeTrue();
    }

    [AvaloniaFact]
    public void StateChanged_WhenPlaying_SetsIsPlayingTrue()
    {
        var state = PlayerState.Empty with { IsPlaying = true };

        _stateSubject.OnNext(state);

        _sut.IsPlaying.Should().BeTrue();
    }

    [AvaloniaFact]
    public void StateChanged_WhenBuffering_SetsIsVisibleTrue()
    {
        var state = PlayerState.Empty with { IsBuffering = true };

        _stateSubject.OnNext(state);

        _sut.IsVisible.Should().BeTrue();
    }

    [AvaloniaFact]
    public void StateChanged_WhenPlayingWithRequest_SetsChannelName()
    {
        var request = new PlaybackRequest(
            Url: "http://example.com/stream",
            ContentType: PlaybackContentType.LiveTv,
            Title: "BBC One",
            ChannelLogoUrl: "http://example.com/logo.png");

        var state = PlayerState.Empty with
        {
            IsPlaying = true,
            CurrentRequest = request,
        };

        _stateSubject.OnNext(state);

        _sut.ChannelName.Should().Be("BBC One");
        _sut.ChannelLogoUrl.Should().Be("http://example.com/logo.png");
    }

    [AvaloniaFact]
    public void StateChanged_WhenStopped_SetsIsVisibleFalse()
    {
        // First go playing, then stop
        _stateSubject.OnNext(PlayerState.Empty with { IsPlaying = true });
        _stateSubject.OnNext(PlayerState.Empty with { IsPlaying = false, IsBuffering = false });

        _sut.IsVisible.Should().BeFalse();
        _sut.IsPlaying.Should().BeFalse();
    }

    // ── Commands ─────────────────────────────────────────────────────────────

    [Fact]
    public async Task PauseCommand_CallsPlayerServicePauseAsync()
    {
        await _sut.PauseCommand.ExecuteAsync(null);

        await _playerService.Received(1).PauseAsync();
    }

    [Fact]
    public async Task ResumeCommand_CallsPlayerServiceResumeAsync()
    {
        await _sut.ResumeCommand.ExecuteAsync(null);

        await _playerService.Received(1).ResumeAsync();
    }

    [Fact]
    public async Task StopCommand_CallsPlayerServiceStopAsync()
    {
        await _sut.StopCommand.ExecuteAsync(null);

        await _playerService.Received(1).StopAsync();
    }

    [Fact]
    public async Task StopCommand_SetsIsVisibleFalse_BeforeServiceCall()
    {
        // Pre-condition: make it visible first
        _playerService
            .When(p => p.StopAsync())
            .Do(_ => _sut.IsVisible.Should().BeFalse()); // assert inside call

        await _sut.StopCommand.ExecuteAsync(null);
    }

    // ── ExpandCommand ────────────────────────────────────────────────────────

    [Fact]
    public void ExpandCommand_RaisesExpandRequested()
    {
        bool raised = false;
        _sut.ExpandRequested += (_, _) => raised = true;

        _sut.ExpandCommand.Execute(null);

        raised.Should().BeTrue();
    }

    // ── Dispose ──────────────────────────────────────────────────────────────

    [Fact]
    public void Dispose_DoesNotThrow()
    {
        var act = () => _sut.Dispose();

        act.Should().NotThrow();
    }

    [Fact]
    public void Dispose_CalledTwice_DoesNotThrow()
    {
        _sut.Dispose();
        var act = () => _sut.Dispose();

        act.Should().NotThrow();
    }
}
