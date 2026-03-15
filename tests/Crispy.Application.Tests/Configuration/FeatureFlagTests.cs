using Crispy.Application.Configuration;
using FluentAssertions;
using Xunit;

namespace Crispy.Application.Tests.Configuration;

[Trait("Category", "Unit")]
public sealed class FeatureFlagTests
{
    // -------------------------------------------------------------------------
    // Enabled = false — always returns false regardless of Platforms
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
    public void IsEnabledForCurrentPlatform_ReturnsFalse_WhenEnabledFalseAndEmptyPlatforms()
    {
        var flag = new FeatureFlag { Enabled = false };

        flag.IsEnabledForCurrentPlatform().Should().BeFalse();
    }

    // -------------------------------------------------------------------------
    // Enabled = true, wildcard / empty
    // -------------------------------------------------------------------------

    [Fact]
    public void IsEnabledForCurrentPlatform_ReturnsTrue_WhenEnabledAndPlatformsEmpty()
    {
        var flag = new FeatureFlag { Enabled = true };

        flag.IsEnabledForCurrentPlatform().Should().BeTrue();
    }

    [Fact]
    public void IsEnabledForCurrentPlatform_ReturnsTrue_WhenEnabledAndPlatformsContainsStar()
    {
        var flag = new FeatureFlag { Enabled = true, Platforms = ["*"] };

        flag.IsEnabledForCurrentPlatform().Should().BeTrue();
    }

    [Fact]
    public void IsEnabledForCurrentPlatform_ReturnsTrue_WhenEnabledAndPlatformsContainsStarAmongOthers()
    {
        var flag = new FeatureFlag
        {
            Enabled = true,
            Platforms = ["NonExistentOS", "*"],
        };

        flag.IsEnabledForCurrentPlatform().Should().BeTrue();
    }

    // -------------------------------------------------------------------------
    // Enabled = true, current platform in list
    // -------------------------------------------------------------------------

    [Fact]
    public void IsEnabledForCurrentPlatform_ReturnsTrue_WhenCurrentPlatformIsInList()
    {
        // Include all desktop OS names — at least one must match the running agent
        var flag = new FeatureFlag
        {
            Enabled = true,
            Platforms = ["Windows", "Linux", "macOS"],
        };

        flag.IsEnabledForCurrentPlatform().Should().BeTrue();
    }

    // -------------------------------------------------------------------------
    // Enabled = true, no matching platform
    // -------------------------------------------------------------------------

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

    [Fact]
    public void IsEnabledForCurrentPlatform_ReturnsFalse_WhenOnlyMobilePlatformsListed_OnDesktop()
    {
        // Tests run on desktop (Windows/Linux/macOS) — Android/iOS/Browser should not match
        var flag = new FeatureFlag
        {
            Enabled = true,
            Platforms = ["Android", "iOS", "Browser"],
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
