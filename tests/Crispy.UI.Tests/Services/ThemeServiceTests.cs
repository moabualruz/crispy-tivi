using Avalonia.Headless.XUnit;

using Crispy.Application.Services;
using Crispy.Domain.Enums;
using Crispy.UI.Services;
using Crispy.UI.Themes;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.Services;

/// <summary>
/// Tests for <see cref="ThemeService"/>.
/// </summary>
[Trait("Category", "Unit")]
public class ThemeServiceTests
{
    private readonly ISettingsService _settingsService;
    private readonly ThemeService _sut;

    public ThemeServiceTests()
    {
        _settingsService = Substitute.For<ISettingsService>();
        _settingsService.GetThemeAsync(Arg.Any<int?>())
            .Returns(ThemeVariant.Dark);
        _sut = new ThemeService(_settingsService);
    }

    [Fact]
    public void CurrentTheme_DefaultsTo_Dark()
    {
        _sut.CurrentTheme.Should().Be(ThemeVariant.Dark);
    }

    [AvaloniaTheory]
    [InlineData(ThemeVariant.Dark)]
    [InlineData(ThemeVariant.OledBlack)]
    [InlineData(ThemeVariant.Light)]
    public async Task SetThemeAsync_UpdatesCurrentTheme(ThemeVariant theme)
    {
        await _sut.SetThemeAsync(theme);

        _sut.CurrentTheme.Should().Be(theme);
    }

    [AvaloniaFact]
    public async Task SetThemeAsync_PersistsViaSettingsService()
    {
        await _sut.SetThemeAsync(ThemeVariant.OledBlack);

        await _settingsService.Received(1)
            .SetThemeAsync(ThemeVariant.OledBlack, Arg.Any<int?>());
    }

    [AvaloniaFact]
    public async Task SetThemeAsync_FiresThemeChangedEvent()
    {
        ThemeVariant? received = null;
        _sut.ThemeChanged += t => received = t;

        await _sut.SetThemeAsync(ThemeVariant.Light);

        received.Should().Be(ThemeVariant.Light);
    }

    [AvaloniaFact]
    public async Task SetThemeAsync_DoesNotFireEvent_WhenSameTheme()
    {
        await _sut.InitializeAsync();
        var fired = false;
        _sut.ThemeChanged += _ => fired = true;

        await _sut.SetThemeAsync(ThemeVariant.Dark);

        fired.Should().BeFalse();
    }

    [AvaloniaFact]
    public async Task InitializeAsync_LoadsPersistedTheme()
    {
        _settingsService.GetThemeAsync(Arg.Any<int?>())
            .Returns(ThemeVariant.Light);

        await _sut.InitializeAsync();

        _sut.CurrentTheme.Should().Be(ThemeVariant.Light);
    }

    [AvaloniaFact]
    public async Task SetReducedMotionAsync_UpdatesIsReducedMotion()
    {
        await _sut.SetReducedMotionAsync(true);

        _sut.IsReducedMotion.Should().BeTrue();
    }

    [AvaloniaFact]
    public async Task SetReducedMotionAsync_PersistsViaSettingsService()
    {
        await _sut.SetReducedMotionAsync(true);

        await _settingsService.Received(1)
            .SetAsync("reduced_motion", true, Arg.Any<int?>());
    }

    [AvaloniaFact]
    public async Task SetAccentColorAsync_UpdatesSelectedAccentIndex()
    {
        await _sut.SetAccentColorAsync(3);

        _sut.SelectedAccentIndex.Should().Be(3);
    }

    [AvaloniaFact]
    public async Task SetAccentColorAsync_ClampsToValidRange()
    {
        await _sut.SetAccentColorAsync(99);

        _sut.SelectedAccentIndex.Should().BeLessThan(DesignTokens.AccentPalette.Length);
    }

    [AvaloniaFact]
    public async Task SetAccentColorAsync_ClampNegative_SetsIndexToZero()
    {
        await _sut.SetAccentColorAsync(-1);

        _sut.SelectedAccentIndex.Should().Be(0);
    }

    [AvaloniaFact]
    public async Task SetAccentColorAsync_ZeroIndex_SetsIndexToZero()
    {
        await _sut.SetAccentColorAsync(0);

        _sut.SelectedAccentIndex.Should().Be(0);
    }

    [AvaloniaFact]
    public async Task SetAccentColorAsync_PersistsClamped_WhenNegativeInput()
    {
        await _sut.SetAccentColorAsync(-5);

        await _settingsService.Received(1)
            .SetAsync(Arg.Is("accent_index"), Arg.Is<object>(v => (int)v == 0), Arg.Any<int?>());
    }

    [AvaloniaFact]
    public async Task SetAccentColorAsync_PersistsClamped_WhenOverflowInput()
    {
        var maxIndex = DesignTokens.AccentPalette.Length - 1;
        await _sut.SetAccentColorAsync(1000);

        await _settingsService.Received(1)
            .SetAsync(Arg.Is("accent_index"), Arg.Is<object>(v => (int)v == maxIndex), Arg.Any<int?>());
    }

    [AvaloniaFact]
    public async Task InitializeAsync_SetsIsReducedMotion_WhenStoredTrue()
    {
        _settingsService.GetAsync("reduced_motion", false, Arg.Any<int?>())
            .Returns(true);

        await _sut.InitializeAsync();

        _sut.IsReducedMotion.Should().BeTrue();
    }

    [AvaloniaFact]
    public async Task InitializeAsync_SetsIsReducedMotion_WhenStoredFalse()
    {
        _settingsService.GetAsync("reduced_motion", false, Arg.Any<int?>())
            .Returns(false);

        await _sut.InitializeAsync();

        _sut.IsReducedMotion.Should().BeFalse();
    }

    [AvaloniaFact]
    public async Task InitializeAsync_LoadsAccentIndex_AndAppliesColor_WhenInRange()
    {
        _settingsService.GetAsync("accent_index", 0, Arg.Any<int?>())
            .Returns(2);

        await _sut.InitializeAsync();

        _sut.SelectedAccentIndex.Should().Be(2);
    }

    [AvaloniaFact]
    public async Task InitializeAsync_DoesNotApplyAccentColor_WhenIndexOutOfRange()
    {
        // Stored index that is out of bounds — should not throw, just skip ApplyAccentColor
        _settingsService.GetAsync("accent_index", 0, Arg.Any<int?>())
            .Returns(999);

        var act = async () => await _sut.InitializeAsync();

        await act.Should().NotThrowAsync();
        _sut.SelectedAccentIndex.Should().Be(999);
    }

    [AvaloniaFact]
    public async Task InitializeAsync_WithLightTheme_SetsCurrentThemeLight()
    {
        _settingsService.GetThemeAsync(Arg.Any<int?>())
            .Returns(ThemeVariant.Light);

        await _sut.InitializeAsync();

        _sut.CurrentTheme.Should().Be(ThemeVariant.Light);
    }

    [AvaloniaFact]
    public async Task InitializeAsync_WithOledBlackTheme_SetsCurrentTheme()
    {
        _settingsService.GetThemeAsync(Arg.Any<int?>())
            .Returns(ThemeVariant.OledBlack);

        await _sut.InitializeAsync();

        _sut.CurrentTheme.Should().Be(ThemeVariant.OledBlack);
    }

    [AvaloniaFact]
    public async Task SetReducedMotionAsync_False_UpdatesIsReducedMotion()
    {
        await _sut.SetReducedMotionAsync(true);
        await _sut.SetReducedMotionAsync(false);

        _sut.IsReducedMotion.Should().BeFalse();
    }

    [AvaloniaFact]
    public async Task SetThemeAsync_FiresThemeChangedEvent_ForOledBlack()
    {
        ThemeVariant? received = null;
        _sut.ThemeChanged += t => received = t;

        await _sut.SetThemeAsync(ThemeVariant.OledBlack);

        received.Should().Be(ThemeVariant.OledBlack);
    }

    [AvaloniaFact]
    public async Task SetThemeAsync_NoSubscribers_DoesNotThrow()
    {
        // ThemeChanged has no subscribers — null-conditional invoke must not throw
        var act = async () => await _sut.SetThemeAsync(ThemeVariant.Light);

        await act.Should().NotThrowAsync();
        _sut.CurrentTheme.Should().Be(ThemeVariant.Light);
    }

    [AvaloniaFact]
    public async Task SetThemeAsync_ReappliesAccentColor_WhenAccentIndexIsNonZero()
    {
        // Set a non-zero accent index first, then change the theme —
        // ApplyAccentColor(SelectedAccentIndex) must be re-invoked after the theme swap.
        await _sut.SetAccentColorAsync(2);
        _sut.SelectedAccentIndex.Should().Be(2);

        // Switching theme must not reset the accent index
        await _sut.SetThemeAsync(ThemeVariant.Light);

        _sut.SelectedAccentIndex.Should().Be(2);
    }

    [Fact]
    public void IsReducedMotion_DefaultsFalse()
    {
        _sut.IsReducedMotion.Should().BeFalse();
    }

    [Fact]
    public void SelectedAccentIndex_DefaultsZero()
    {
        _sut.SelectedAccentIndex.Should().Be(0);
    }
}

/// <summary>
/// Tests for <see cref="DesignTokens"/>.
/// </summary>
[Trait("Category", "Unit")]
public class DesignTokensTests
{
    [Fact]
    public void SpacingSm_Equals8()
    {
        DesignTokens.SpacingSm.Should().Be(8);
    }

    [Fact]
    public void SpacingXs_Equals4()
    {
        DesignTokens.SpacingXs.Should().Be(4);
    }

    [Fact]
    public void SpacingMd_Equals16()
    {
        DesignTokens.SpacingMd.Should().Be(16);
    }

    [Fact]
    public void FocusScaleFactor_Equals1_05()
    {
        DesignTokens.FocusScaleFactor.Should().Be(1.05);
    }

    [Fact]
    public void AccentPalette_Has9Colors()
    {
        DesignTokens.AccentPalette.Should().HaveCount(9);
    }

    [Fact]
    public void RadiusMd_Equals8()
    {
        DesignTokens.RadiusMd.Should().Be(8);
    }

    [Fact]
    public void DefaultDuration_Equals250ms()
    {
        DesignTokens.DefaultDuration.Should().Be(TimeSpan.FromMilliseconds(250));
    }
}
