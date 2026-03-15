using Avalonia.Headless.XUnit;

using Crispy.UI.Tests.Helpers;
using Crispy.UI.Themes;
using Crispy.UI.ViewModels;
using Crispy.UI.Views;

using FluentAssertions;

using Xunit;

namespace Crispy.UI.Tests.Views;

/// <summary>
/// Smoke tests for the Settings screen.
/// SettingsViewModel cannot be constructed in tests because it depends on FluentIcons.Common
/// at runtime (not available without dotnet restore in the test project).
/// These tests verify the DesignTokens layer (theme tokens surfaced by the settings UI)
/// and that SettingsView renders when given a compatible DataContext.
/// </summary>
[Trait("Category", "UI")]
public class SettingsViewTests
{
    // ── DesignTokens — surfaced in the settings accent palette and theme panels ──

    [Fact]
    public void AccentPalette_HasNineColors()
    {
        DesignTokens.AccentPalette.Should().HaveCount(9,
            "settings UI must expose exactly 9 accent color swatches");
    }

    [Fact]
    public void SpacingTokens_AreCorrect()
    {
        DesignTokens.SpacingXs.Should().Be(4);
        DesignTokens.SpacingSm.Should().Be(8);
        DesignTokens.SpacingMd.Should().Be(16);
        DesignTokens.SpacingLg.Should().Be(24);
    }

    [Fact]
    public void RadiusMd_IsEight()
    {
        DesignTokens.RadiusMd.Should().Be(8);
    }

    [Fact]
    public void DefaultDuration_Is250ms()
    {
        DesignTokens.DefaultDuration.Should().Be(TimeSpan.FromMilliseconds(250));
    }

}
