using Crispy.Application.Configuration;

using FluentAssertions;

using Xunit;

namespace Crispy.Application.Tests.Configuration;

public class FeatureFlagTests
{
    [Fact]
    public void IsEnabledForCurrentPlatform_ShouldReturnFalse_WhenDisabled()
    {
        var flag = new FeatureFlag { Enabled = false, Platforms = ["*"] };

        flag.IsEnabledForCurrentPlatform().Should().BeFalse();
    }

    [Fact]
    public void IsEnabledForCurrentPlatform_ShouldReturnTrue_WhenEnabledWithWildcard()
    {
        var flag = new FeatureFlag { Enabled = true, Platforms = ["*"] };

        flag.IsEnabledForCurrentPlatform().Should().BeTrue();
    }

    [Fact]
    public void IsEnabledForCurrentPlatform_ShouldReturnTrue_WhenEnabledWithEmptyPlatforms()
    {
        var flag = new FeatureFlag { Enabled = true, Platforms = [] };

        flag.IsEnabledForCurrentPlatform().Should().BeTrue();
    }

    [Fact]
    public void IsEnabledForCurrentPlatform_ShouldReturnTrue_WhenCurrentPlatformInList()
    {
        // This test runs on Windows in CI/dev
        var flag = new FeatureFlag { Enabled = true, Platforms = ["Windows", "Linux", "macOS"] };

        // Should be true on any desktop OS
        flag.IsEnabledForCurrentPlatform().Should().BeTrue();
    }

    [Fact]
    public void IsEnabledForCurrentPlatform_ShouldReturnFalse_WhenCurrentPlatformNotInList()
    {
        // This test runs on desktop, so Android/iOS/Browser should not match
        var flag = new FeatureFlag { Enabled = true, Platforms = ["Android", "iOS", "Browser"] };

        flag.IsEnabledForCurrentPlatform().Should().BeFalse();
    }
}
