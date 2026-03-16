using Crispy.Application.Player.Models;
using Crispy.Infrastructure.Player;
using Crispy.Infrastructure.Tests.Helpers;

using FluentAssertions;

using Xunit;

namespace Crispy.Infrastructure.Tests.Player;

[Trait("Category", "Unit")]
public class ReminderRepositoryTests : IDisposable
{
    private readonly TestDbContextFactory _factory;
    private readonly ReminderRepository _sut;

    public ReminderRepositoryTests()
    {
        _factory = new TestDbContextFactory();
        _sut = new ReminderRepository(_factory);
    }

    // -------------------------------------------------------------------------
    // GetPendingAsync
    // -------------------------------------------------------------------------

    [Fact]
    public async Task GetPendingAsync_ReturnsEmptyList_WhenNoRemindersExist()
    {
        var result = await _sut.GetPendingAsync("profile-1");

        result.Should().BeEmpty();
    }

    [Fact]
    public async Task GetPendingAsync_ReturnsPendingReminders_OrderedByNotifyAt()
    {
        var future = DateTimeOffset.UtcNow.AddHours(1);

        await _sut.AddAsync(MakeReminder("r1", "p1", notifyAt: future.AddMinutes(30)));
        await _sut.AddAsync(MakeReminder("r2", "p1", notifyAt: future.AddMinutes(10)));
        await _sut.AddAsync(MakeReminder("r3", "p1", notifyAt: future.AddMinutes(60)));

        var result = await _sut.GetPendingAsync("p1");

        result.Should().HaveCount(3);
        result.Select(r => r.NotifyAt).Should().BeInAscendingOrder();
    }

    [Fact]
    public async Task GetPendingAsync_ExcludesFiredReminders()
    {
        var future = DateTimeOffset.UtcNow.AddHours(1);

        await _sut.AddAsync(MakeReminder("r-active", "p1", notifyAt: future));
        var fired = MakeReminder("r-fired", "p1", notifyAt: future.AddMinutes(5));
        await _sut.AddAsync(fired);
        await _sut.MarkFiredAsync("r-fired");

        var result = await _sut.GetPendingAsync("p1");

        result.Should().HaveCount(1);
        result[0].Id.Should().Be("r-active");
    }

    [Fact]
    public async Task GetPendingAsync_ExcludesPastReminders()
    {
        var past = DateTimeOffset.UtcNow.AddHours(-1);
        var future = DateTimeOffset.UtcNow.AddHours(1);

        await _sut.AddAsync(MakeReminder("r-past", "p1", notifyAt: past));
        await _sut.AddAsync(MakeReminder("r-future", "p1", notifyAt: future));

        var result = await _sut.GetPendingAsync("p1");

        result.Should().HaveCount(1);
        result[0].Id.Should().Be("r-future");
    }

    [Fact]
    public async Task GetPendingAsync_ExcludesRemindersForOtherProfiles()
    {
        var future = DateTimeOffset.UtcNow.AddHours(1);

        await _sut.AddAsync(MakeReminder("r-p1", "p1", notifyAt: future));
        await _sut.AddAsync(MakeReminder("r-p2", "p2", notifyAt: future));

        var result = await _sut.GetPendingAsync("p1");

        result.Should().HaveCount(1);
        result[0].Id.Should().Be("r-p1");
    }

    // -------------------------------------------------------------------------
    // AddAsync
    // -------------------------------------------------------------------------

    [Fact]
    public async Task AddAsync_PersistsReminder_SoItIsReturnedByGetPendingAsync()
    {
        var future = DateTimeOffset.UtcNow.AddHours(2);
        var reminder = MakeReminder("r-add", "p1", notifyAt: future);

        await _sut.AddAsync(reminder);

        var result = await _sut.GetPendingAsync("p1");
        result.Should().HaveCount(1);
        result[0].Id.Should().Be("r-add");
        result[0].ProgramName.Should().Be(reminder.ProgramName);
    }

    // -------------------------------------------------------------------------
    // MarkFiredAsync
    // -------------------------------------------------------------------------

    [Fact]
    public async Task MarkFiredAsync_SetsFiredToTrue_WhenReminderExists()
    {
        var future = DateTimeOffset.UtcNow.AddHours(1);
        await _sut.AddAsync(MakeReminder("r-fire", "p1", notifyAt: future));

        await _sut.MarkFiredAsync("r-fire");

        // Fired reminders are excluded from GetPendingAsync
        var pending = await _sut.GetPendingAsync("p1");
        pending.Should().BeEmpty();
    }

    [Fact]
    public async Task MarkFiredAsync_DoesNotThrow_WhenReminderDoesNotExist()
    {
        var act = async () => await _sut.MarkFiredAsync("nonexistent-id");

        await act.Should().NotThrowAsync();
    }

    // -------------------------------------------------------------------------
    // DeleteAsync
    // -------------------------------------------------------------------------

    [Fact]
    public async Task DeleteAsync_RemovesReminder_WhenItExists()
    {
        var future = DateTimeOffset.UtcNow.AddHours(1);
        await _sut.AddAsync(MakeReminder("r-del", "p1", notifyAt: future));

        await _sut.DeleteAsync("r-del");

        var result = await _sut.GetPendingAsync("p1");
        result.Should().BeEmpty();
    }

    [Fact]
    public async Task DeleteAsync_DoesNotThrow_WhenReminderDoesNotExist()
    {
        var act = async () => await _sut.DeleteAsync("nonexistent-id");

        await act.Should().NotThrowAsync();
    }

    [Fact]
    public async Task DeleteAsync_OnlyRemovesTargetReminder_LeavingOthersIntact()
    {
        var future = DateTimeOffset.UtcNow.AddHours(1);
        await _sut.AddAsync(MakeReminder("r-keep", "p1", notifyAt: future.AddMinutes(10)));
        await _sut.AddAsync(MakeReminder("r-remove", "p1", notifyAt: future.AddMinutes(20)));

        await _sut.DeleteAsync("r-remove");

        var result = await _sut.GetPendingAsync("p1");
        result.Should().HaveCount(1);
        result[0].Id.Should().Be("r-keep");
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private static Reminder MakeReminder(
        string id,
        string profileId,
        DateTimeOffset notifyAt) =>
        new()
        {
            Id = id,
            ProfileId = profileId,
            ProgramName = $"Program-{id}",
            ChannelName = "Test Channel",
            StartTime = notifyAt,
            NotifyAt = notifyAt,
            Fired = false,
            CreatedAt = DateTimeOffset.UtcNow,
        };

    public void Dispose() => _factory.Dispose();
}
