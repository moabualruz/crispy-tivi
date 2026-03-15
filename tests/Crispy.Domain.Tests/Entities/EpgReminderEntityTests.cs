using Crispy.Domain.Entities;
using FluentAssertions;
using Xunit;

namespace Crispy.Domain.Tests.Entities;

[Trait("Category", "Unit")]
public class EpgReminderEntityTests
{
    [Fact]
    public void EpgReminder_ProfileId_IsSet()
    {
        var reminder = new EpgReminder { ProfileId = 7, EpgProgrammeId = 42 };

        reminder.ProfileId.Should().Be(7);
    }

    [Fact]
    public void EpgReminder_EpgProgrammeId_IsSet()
    {
        var reminder = new EpgReminder { ProfileId = 1, EpgProgrammeId = 99 };

        reminder.EpgProgrammeId.Should().Be(99);
    }

    [Fact]
    public void EpgReminder_ReminderMinutesBefore_DefaultsToFive()
    {
        var reminder = new EpgReminder { ProfileId = 1, EpgProgrammeId = 1 };

        reminder.ReminderMinutesBefore.Should().Be(5);
    }

    [Fact]
    public void EpgReminder_ReminderMinutesBefore_CanBeSet()
    {
        var reminder = new EpgReminder
        {
            ProfileId = 1,
            EpgProgrammeId = 1,
            ReminderMinutesBefore = 15,
        };

        reminder.ReminderMinutesBefore.Should().Be(15);
    }

    [Fact]
    public void EpgReminder_IsFired_DefaultsToFalse()
    {
        var reminder = new EpgReminder { ProfileId = 1, EpgProgrammeId = 1 };

        reminder.IsFired.Should().BeFalse();
    }

    [Fact]
    public void EpgReminder_IsFired_CanBeSetToTrue()
    {
        var reminder = new EpgReminder
        {
            ProfileId = 1,
            EpgProgrammeId = 1,
            IsFired = true,
        };

        reminder.IsFired.Should().BeTrue();
    }

    [Fact]
    public void EpgReminder_EpgProgramme_DefaultsToNull()
    {
        var reminder = new EpgReminder { ProfileId = 1, EpgProgrammeId = 1 };

        reminder.EpgProgramme.Should().BeNull();
    }
}
