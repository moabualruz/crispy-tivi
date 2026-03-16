using Avalonia.Input;

using Crispy.Application.Services;
using Crispy.UI.Services;

using FluentAssertions;

using Xunit;

namespace Crispy.UI.Tests.Services;

/// <summary>
/// Unit tests for <see cref="InputRoutingService"/>.
/// </summary>
[Trait("Category", "Unit")]
public class InputRoutingServiceTests
{
    private readonly InputRoutingService _sut = new();

    // ── MediaKey_AlwaysRoutesToPlayer_RegardlessOfState ───────────────────────

    [Theory]
    [InlineData(Key.MediaPlayPause, AppState.Idle)]
    [InlineData(Key.MediaPlayPause, AppState.Browsing)]
    [InlineData(Key.MediaPlayPause, AppState.Watching)]
    [InlineData(Key.MediaPlayPause, AppState.BrowsingWhilePlaying)]
    [InlineData(Key.MediaStop,       AppState.Idle)]
    [InlineData(Key.MediaStop,       AppState.Watching)]
    [InlineData(Key.MediaNextTrack,  AppState.Browsing)]
    [InlineData(Key.MediaNextTrack,  AppState.Watching)]
    [InlineData(Key.MediaPreviousTrack, AppState.Browsing)]
    [InlineData(Key.MediaPreviousTrack, AppState.Watching)]
    [InlineData(Key.Space,           AppState.Idle)]
    [InlineData(Key.Space,           AppState.Watching)]
    [InlineData(Key.Space,           AppState.Browsing)]
    public void MediaKey_AlwaysRoutesToPlayer_RegardlessOfState(Key key, AppState state)
    {
        var result = _sut.HandleKey(key, KeyModifiers.None, state);

        result.Should().Be(KeyHandleResult.Handled);
    }

    // ── Escape_ShowsContent_WhenWatching ──────────────────────────────────────

    [Fact]
    public void Escape_ShowsContent_WhenWatching()
    {
        var result = _sut.HandleKey(Key.Escape, KeyModifiers.None, AppState.Watching);

        result.Should().Be(KeyHandleResult.Handled);
    }

    // ── Escape_GoesBack_WhenBrowsing ──────────────────────────────────────────

    [Fact]
    public void Escape_GoesBack_WhenBrowsing()
    {
        var result = _sut.HandleKey(Key.Escape, KeyModifiers.None, AppState.Browsing);

        result.Should().Be(KeyHandleResult.Handled);
    }

    [Fact]
    public void Escape_Handled_WhenBrowsingWhilePlaying()
    {
        var result = _sut.HandleKey(Key.Escape, KeyModifiers.None, AppState.BrowsingWhilePlaying);

        result.Should().Be(KeyHandleResult.Handled);
    }

    [Fact]
    public void Escape_NotHandled_WhenIdle()
    {
        var result = _sut.HandleKey(Key.Escape, KeyModifiers.None, AppState.Idle);

        result.Should().Be(KeyHandleResult.NotHandled);
    }

    // ── ArrowKeys_RouteToContent_WhenBrowsing ─────────────────────────────────

    [Theory]
    [InlineData(Key.Up)]
    [InlineData(Key.Down)]
    [InlineData(Key.Left)]
    [InlineData(Key.Right)]
    [InlineData(Key.Enter)]
    [InlineData(Key.Back)]
    public void ArrowKeys_RouteToContent_WhenBrowsing(Key key)
    {
        var result = _sut.HandleKey(key, KeyModifiers.None, AppState.Browsing);

        result.Should().Be(KeyHandleResult.Handled);
    }

    [Theory]
    [InlineData(Key.Up)]
    [InlineData(Key.Down)]
    [InlineData(Key.Left)]
    [InlineData(Key.Right)]
    [InlineData(Key.Enter)]
    public void ArrowKeys_RouteToContent_WhenBrowsingWhilePlaying(Key key)
    {
        var result = _sut.HandleKey(key, KeyModifiers.None, AppState.BrowsingWhilePlaying);

        result.Should().Be(KeyHandleResult.Handled);
    }

    // ── ArrowKeys_RouteToOsd_WhenWatching ─────────────────────────────────────

    [Theory]
    [InlineData(Key.Up)]
    [InlineData(Key.Down)]
    [InlineData(Key.Left)]
    [InlineData(Key.Right)]
    [InlineData(Key.Enter)]
    public void ArrowKeys_RouteToOsd_WhenWatching(Key key)
    {
        var result = _sut.HandleKey(key, KeyModifiers.None, AppState.Watching);

        result.Should().Be(KeyHandleResult.Handled);
    }

    // ── Seek keys (Shift + Left/Right) always go to player ────────────────────

    [Theory]
    [InlineData(Key.Left,  AppState.Browsing)]
    [InlineData(Key.Right, AppState.Browsing)]
    [InlineData(Key.Left,  AppState.Watching)]
    [InlineData(Key.Right, AppState.Watching)]
    public void ShiftArrow_AlwaysRoutesToPlayer_AsSeekKey(Key key, AppState state)
    {
        var result = _sut.HandleKey(key, KeyModifiers.Shift, state);

        result.Should().Be(KeyHandleResult.Handled);
    }

    // ── F key toggles fullscreen ──────────────────────────────────────────────

    [Theory]
    [InlineData(AppState.Watching)]
    [InlineData(AppState.Browsing)]
    [InlineData(AppState.BrowsingWhilePlaying)]
    public void FKey_Handled_InActiveStates(AppState state)
    {
        var result = _sut.HandleKey(Key.F, KeyModifiers.None, state);

        result.Should().Be(KeyHandleResult.Handled);
    }

    // ── Unbound keys not consumed ─────────────────────────────────────────────

    [Theory]
    [InlineData(Key.Q)]
    [InlineData(Key.Tab)]
    [InlineData(Key.Delete)]
    public void UnboundKey_NotHandled_InAnyState(Key key)
    {
        foreach (var state in Enum.GetValues<AppState>())
        {
            _sut.HandleKey(key, KeyModifiers.None, state)
                .Should().Be(KeyHandleResult.NotHandled, $"key {key} in state {state} should not be consumed");
        }
    }
}
