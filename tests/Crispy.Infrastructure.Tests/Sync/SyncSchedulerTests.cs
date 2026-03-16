using Crispy.Infrastructure.Sync;

using FluentAssertions;

using Microsoft.Extensions.Logging.Abstractions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Sync;

[Trait("Category", "Unit")]
public class SyncSchedulerTests
{
    // ─── Helpers ─────────────────────────────────────────────────────────────

    private static SyncScheduler CreateSut(
        Func<CancellationToken, Task>? callback = null,
        TimeSpan? interval = null)
    {
        callback ??= _ => Task.CompletedTask;
        // Use a very long interval so the timer never fires during tests
        interval ??= TimeSpan.FromDays(1);
        return new SyncScheduler(callback, NullLogger<SyncScheduler>.Instance, interval);
    }

    // ─── StartAsync ───────────────────────────────────────────────────────────

    [Fact]
    public async Task StartAsync_DoesNotThrow()
    {
        await using var sut = CreateSut();

        var act = async () => await sut.StartAsync();
        await act.Should().NotThrowAsync();
    }

    [Fact]
    public async Task StartAsync_AllowsCancellation_WithoutThrowing()
    {
        using var cts = new CancellationTokenSource();
        await using var sut = CreateSut();

        await sut.StartAsync(cts.Token);
        await cts.CancelAsync();

        // Allow the background task to observe cancellation
        await Task.Delay(50);
    }

    [Fact]
    public async Task StartAsync_WithShortInterval_InvokesCallback()
    {
        var callCount = 0;
        var tcs = new TaskCompletionSource();

        Func<CancellationToken, Task> callback = _ =>
        {
            callCount++;
            tcs.TrySetResult();
            return Task.CompletedTask;
        };

        await using var sut = CreateSut(callback, interval: TimeSpan.FromMilliseconds(50));
        await sut.StartAsync();

        // Wait for at least one tick
        await tcs.Task.WaitAsync(TimeSpan.FromSeconds(5));
        await sut.StopAsync();

        callCount.Should().BeGreaterThanOrEqualTo(1);
    }

    // ─── StopAsync ────────────────────────────────────────────────────────────

    [Fact]
    public async Task StopAsync_DoesNotThrow_WhenNotStarted()
    {
        await using var sut = CreateSut();

        var act = async () => await sut.StopAsync();
        await act.Should().NotThrowAsync();
    }

    [Fact]
    public async Task StopAsync_DoesNotThrow_AfterStart()
    {
        await using var sut = CreateSut();
        await sut.StartAsync();

        var act = async () => await sut.StopAsync();
        await act.Should().NotThrowAsync();
    }

    [Fact]
    public async Task StopAsync_CanBeCalledMultipleTimes_WithoutThrowing()
    {
        await using var sut = CreateSut();
        await sut.StartAsync();
        await sut.StopAsync();

        var act = async () => await sut.StopAsync();
        await act.Should().NotThrowAsync();
    }

    // ─── DisposeAsync ─────────────────────────────────────────────────────────

    [Fact]
    public async Task DisposeAsync_CallsStop_WithoutThrowing()
    {
        var sut = CreateSut();
        await sut.StartAsync();

        var act = async () => await sut.DisposeAsync();
        await act.Should().NotThrowAsync();
    }

    [Fact]
    public async Task DisposeAsync_WithoutStart_DoesNotThrow()
    {
        var sut = CreateSut();

        var act = async () => await sut.DisposeAsync();
        await act.Should().NotThrowAsync();
    }

    // ─── Callback error isolation ──────────────────────────────────────────────

    [Fact]
    public async Task StartAsync_CallbackException_DoesNotCrashScheduler()
    {
        var callCount = 0;

        Func<CancellationToken, Task> callback = _ =>
        {
            callCount++;
            throw new InvalidOperationException("Simulated sync failure");
        };

        await using var sut = CreateSut(callback, interval: TimeSpan.FromMilliseconds(50));
        await sut.StartAsync();

        await Task.Delay(200);

        // Scheduler should still be running despite callback throwing
        await sut.StopAsync();
        callCount.Should().BeGreaterThanOrEqualTo(1);
    }
}
