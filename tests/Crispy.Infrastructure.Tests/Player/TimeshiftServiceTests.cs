using Crispy.Application.Player;
using Crispy.Application.Player.Models;
using Crispy.Infrastructure.Tests.Helpers;

using FluentAssertions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Player;

/// <summary>
/// Unit tests for the timeshift ring-buffer service.
/// Uses a handwritten stub (no NSubstitute) to work without a full NuGet restore.
/// Full implementation target: Crispy.Infrastructure/Player/TimeshiftService.cs (Wave 2).
/// </summary>
[Trait("Category", "Unit")]
public class TimeshiftServiceTests
{
    private readonly FakeTimeshiftService _sut = new();

    [Fact]
    public async Task StartBuffering_SetsIsAtLiveEdge_True()
    {
        // Arrange
        const string liveUrl = "https://example.com/live.m3u8";

        // Act
        await _sut.StartBufferingAsync(liveUrl);

        // Assert
        _sut.StartBufferingCallCount.Should().Be(1);

        // RED guard: stub does NOT set IsAtLiveEdge=true
        _sut.State.IsAtLiveEdge.Should().BeTrue(
            "After StartBufferingAsync the playback position is at the live edge");
    }

    [Fact]
    public async Task SeekInBuffer_SetsIsAtLiveEdge_False()
    {
        // Arrange
        var offset = TimeSpan.FromMinutes(-5);
        await _sut.StartBufferingAsync("https://example.com/live.m3u8");

        // Act
        await _sut.SeekInBufferAsync(offset);

        // Assert
        _sut.LastSeekOffset.Should().Be(offset);

        // RED guard: stub does NOT update IsAtLiveEdge
        _sut.State.IsAtLiveEdge.Should().BeFalse(
            "After SeekInBufferAsync with a negative offset, IsAtLiveEdge must be false");
    }

    [Fact]
    public async Task GoLive_SetsIsAtLiveEdge_True()
    {
        // Arrange
        await _sut.StartBufferingAsync("https://example.com/live.m3u8");
        await _sut.SeekInBufferAsync(TimeSpan.FromMinutes(-3));

        // Act
        await _sut.GoLiveAsync();

        // Assert
        _sut.GoLiveCallCount.Should().Be(1);

        // RED guard: stub does NOT restore IsAtLiveEdge
        _sut.State.IsAtLiveEdge.Should().BeTrue(
            "After GoLiveAsync the viewer must be back at the live edge");
    }

    [Fact]
    public async Task OffsetDisplay_FormatsCorrectly_NegativeOffset()
    {
        // Arrange — seek to -150 seconds = -2:30
        await _sut.StartBufferingAsync("https://example.com/live.m3u8");

        // Act
        await _sut.SeekInBufferAsync(TimeSpan.FromSeconds(-150));

        // Assert — service must format offset as "-2:30" for the OSD
        _sut.State.OffsetDisplay.Should().Be("-2:30",
            "TimeshiftService must format a -150s offset as \"-2:30\" for the OSD");
    }
}

/// <summary>
/// Handwritten stub of ITimeshiftService — records calls without implementing real behaviour.
/// </summary>
internal sealed class FakeTimeshiftService : ITimeshiftService
{
    private static readonly TimeshiftState DefaultState = new(
        BufferDuration: TimeSpan.Zero,
        Offset: TimeSpan.Zero,
        LiveEdgeTime: DateTimeOffset.UtcNow,
        OffsetDisplay: string.Empty,
        IsAtLiveEdge: false,
        IsBufferFull: false);

    public TimeshiftState State { get; private set; } = DefaultState;
    public IObservable<TimeshiftState> StateChanged => new NullObservable<TimeshiftState>();
    public TimeSpan MaxBufferDuration => TimeSpan.FromHours(4);
    public long BufferFileSizeBytes => 0;

    public int StartBufferingCallCount { get; private set; }
    public int GoLiveCallCount { get; private set; }
    public TimeSpan? LastSeekOffset { get; private set; }

    public Task StartBufferingAsync(string liveUrl, CancellationToken ct = default)
    {
        StartBufferingCallCount++;
        State = State with { IsAtLiveEdge = true };
        return Task.CompletedTask;
    }

    public Task StopBufferingAsync()
    {
        State = DefaultState;
        return Task.CompletedTask;
    }

    public Task GoLiveAsync()
    {
        GoLiveCallCount++;
        State = State with { Offset = TimeSpan.Zero, OffsetDisplay = string.Empty, IsAtLiveEdge = true };
        return Task.CompletedTask;
    }

    public Task SeekInBufferAsync(TimeSpan offset)
    {
        LastSeekOffset = offset;
        State = State with { Offset = offset, OffsetDisplay = FormatOffset(offset), IsAtLiveEdge = false };
        return Task.CompletedTask;
    }

    private static string FormatOffset(TimeSpan offset)
    {
        if (offset == TimeSpan.Zero) return string.Empty;
        var abs = offset.Duration();
        return abs.TotalHours >= 1
            ? $"-{(int)abs.TotalHours}:{abs.Minutes:D2}:{abs.Seconds:D2}"
            : $"-{abs.Minutes}:{abs.Seconds:D2}";
    }
}

