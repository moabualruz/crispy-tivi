using Crispy.Application.Configuration;
using FluentAssertions;
using Xunit;

namespace Crispy.Application.Tests.Configuration;

[Trait("Category", "Unit")]
public sealed class FeatureFlagTests
{
    // -------------------------------------------------------------------------
    // IsEnabledForPlatform — Enabled = false
    // -------------------------------------------------------------------------

    [Theory]
    [InlineData("Windows")]
    [InlineData("Linux")]
    [InlineData("macOS")]
    [InlineData("Android")]
    [InlineData("iOS")]
    [InlineData("Browser")]
    [InlineData("Unknown")]
    public void IsEnabledForPlatform_ReturnsFalse_WhenEnabledIsFalse(string platform)
    {
        var flag = new FeatureFlag
        {
            Enabled = false,
            Platforms = ["Windows", "Linux", "macOS", "Android", "iOS", "Browser", "*"],
        };

        flag.IsEnabledForPlatform(platform).Should().BeFalse();
    }

    // -------------------------------------------------------------------------
    // IsEnabledForPlatform — Enabled = true, empty platforms → true for any
    // -------------------------------------------------------------------------

    [Theory]
    [InlineData("Windows")]
    [InlineData("Linux")]
    [InlineData("macOS")]
    [InlineData("Android")]
    [InlineData("iOS")]
    [InlineData("Browser")]
    [InlineData("Unknown")]
    public void IsEnabledForPlatform_ReturnsTrue_WhenPlatformsEmpty(string platform)
    {
        var flag = new FeatureFlag { Enabled = true };

        flag.IsEnabledForPlatform(platform).Should().BeTrue();
    }

    // -------------------------------------------------------------------------
    // IsEnabledForPlatform — wildcard "*" → true for any platform
    // -------------------------------------------------------------------------

    [Theory]
    [InlineData("Windows")]
    [InlineData("Linux")]
    [InlineData("macOS")]
    [InlineData("Android")]
    [InlineData("iOS")]
    [InlineData("Browser")]
    [InlineData("Unknown")]
    public void IsEnabledForPlatform_ReturnsTrue_WhenWildcardPresent(string platform)
    {
        var flag = new FeatureFlag { Enabled = true, Platforms = ["*"] };

        flag.IsEnabledForPlatform(platform).Should().BeTrue();
    }

    // -------------------------------------------------------------------------
    // IsEnabledForPlatform — exact match for each platform
    // -------------------------------------------------------------------------

    [Theory]
    [InlineData("Windows")]
    [InlineData("Linux")]
    [InlineData("macOS")]
    [InlineData("Android")]
    [InlineData("iOS")]
    [InlineData("Browser")]
    public void IsEnabledForPlatform_ReturnsTrue_WhenPlatformIsListed(string platform)
    {
        var flag = new FeatureFlag { Enabled = true, Platforms = [platform] };

        flag.IsEnabledForPlatform(platform).Should().BeTrue();
    }

    // -------------------------------------------------------------------------
    // IsEnabledForPlatform — no match
    // -------------------------------------------------------------------------

    [Theory]
    [InlineData("Windows", "Linux")]
    [InlineData("Linux", "macOS")]
    [InlineData("macOS", "Windows")]
    [InlineData("Android", "iOS")]
    [InlineData("iOS", "Browser")]
    [InlineData("Browser", "Android")]
    [InlineData("Unknown", "Windows")]
    public void IsEnabledForPlatform_ReturnsFalse_WhenPlatformNotListed(string platform, string listedPlatform)
    {
        var flag = new FeatureFlag { Enabled = true, Platforms = [listedPlatform] };

        flag.IsEnabledForPlatform(platform).Should().BeFalse();
    }

    // -------------------------------------------------------------------------
    // IsEnabledForCurrentPlatform — delegates to IsEnabledForPlatform
    // (verifies the wrapper behaves consistently; one OS always matches)
    // -------------------------------------------------------------------------

    [Fact]
    public void IsEnabledForCurrentPlatform_ReturnsFalse_WhenEnabledIsFalse()
    {
        var flag = new FeatureFlag
        {
            Enabled = false,
            Platforms = ["Windows", "Linux", "macOS", "Android", "iOS", "Browser", "*"],
        };

        flag.IsEnabledForCurrentPlatform().Should().BeFalse();
    }

    [Fact]
    public void IsEnabledForCurrentPlatform_ReturnsTrue_WhenEnabledAndPlatformsEmpty()
    {
        var flag = new FeatureFlag { Enabled = true };

        flag.IsEnabledForCurrentPlatform().Should().BeTrue();
    }

    [Fact]
    public void IsEnabledForCurrentPlatform_ReturnsTrue_WhenEnabledAndWildcard()
    {
        var flag = new FeatureFlag { Enabled = true, Platforms = ["*"] };

        flag.IsEnabledForCurrentPlatform().Should().BeTrue();
    }

    [Fact]
    public void IsEnabledForCurrentPlatform_ReturnsTrue_WhenCurrentPlatformIsInList()
    {
        // Include all known OS names — at least one must match on any CI agent
        var flag = new FeatureFlag
        {
            Enabled = true,
            Platforms = ["Windows", "Linux", "macOS"],
        };

        flag.IsEnabledForCurrentPlatform().Should().BeTrue();
    }

    [Fact]
    public void IsEnabledForCurrentPlatform_ReturnsFalse_WhenNoPlatformMatches()
    {
        var flag = new FeatureFlag
        {
            Enabled = true,
            Platforms = ["NonExistentOS"],
        };

        flag.IsEnabledForCurrentPlatform().Should().BeFalse();
    }

    // -------------------------------------------------------------------------
    // Default state
    // -------------------------------------------------------------------------

    [Fact]
    public void FeatureFlag_DefaultsToDisabled_WithEmptyPlatforms()
    {
        var flag = new FeatureFlag();

        flag.Enabled.Should().BeFalse();
        flag.Platforms.Should().NotBeNull().And.BeEmpty();
    }
}
