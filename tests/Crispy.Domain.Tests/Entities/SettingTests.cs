using Crispy.Domain.Entities;

using FluentAssertions;

using Xunit;

namespace Crispy.Domain.Tests.Entities;

public class SettingTests
{
    [Fact]
    public void Setting_ShouldAllowNullProfileId_ForGlobalSettings()
    {
        var setting = new Setting { Key = "theme", Value = "0" };

        setting.ProfileId.Should().BeNull();
    }

    [Fact]
    public void Setting_ShouldAcceptProfileId_ForProfileScopedSettings()
    {
        var setting = new Setting { Key = "theme", Value = "1", ProfileId = 42 };

        setting.ProfileId.Should().Be(42);
    }
}
