using Crispy.Application.Services;
using Crispy.Domain.Enums;
using Crispy.UI.Services;
using Crispy.UI.Themes;

using FluentAssertions;

using NSubstitute;

namespace Crispy.UI.Tests.Services;

/// <summary>
/// Tests for <see cref="ThemeService"/>.
/// </summary>
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

    [Theory]
    [InlineData(ThemeVariant.Dark)]
    [InlineData(ThemeVariant.OledBlack)]
    [InlineData(ThemeVariant.Light)]
    public async Task SetThemeAsync_UpdatesCurrentTheme(ThemeVariant theme)
    {
        await _sut.SetThemeAsync(theme);

        _sut.CurrentTheme.Should().Be(theme);
    }

    [Fact]
    public async Task SetThemeAsync_PersistsViaSettingsService()
    {
        await _sut.SetThemeAsync(ThemeVariant.OledBlack);

        await _settingsService.Received(1)
            .SetThemeAsync(ThemeVariant.OledBlack, Arg.Any<int?>());
    }

    [Fact]
    public async Task SetThemeAsync_FiresThemeChangedEvent()
    {
        ThemeVariant? received = null;
        _sut.ThemeChanged += t => received = t;

        await _sut.SetThemeAsync(ThemeVariant.Light);

        received.Should().Be(ThemeVariant.Light);
    }

    [Fact]
    public async Task SetThemeAsync_DoesNotFireEvent_WhenSameTheme()
    {
        await _sut.InitializeAsync();
        var fired = false;
        _sut.ThemeChanged += _ => fired = true;

        await _sut.SetThemeAsync(ThemeVariant.Dark);

        fired.Should().BeFalse();
    }

    [Fact]
    public async Task InitializeAsync_LoadsPersistedTheme()
    {
        _settingsService.GetThemeAsync(Arg.Any<int?>())
            .Returns(ThemeVariant.Light);

        await _sut.InitializeAsync();

        _sut.CurrentTheme.Should().Be(ThemeVariant.Light);
    }

    [Fact]
    public async Task SetReducedMotionAsync_UpdatesIsReducedMotion()
    {
        await _sut.SetReducedMotionAsync(true);

        _sut.IsReducedMotion.Should().BeTrue();
    }

    [Fact]
    public async Task SetReducedMotionAsync_PersistsViaSettingsService()
    {
        await _sut.SetReducedMotionAsync(true);

        await _settingsService.Received(1)
            .SetAsync("reduced_motion", true, Arg.Any<int?>());
    }

    [Fact]
    public async Task SetAccentColorAsync_UpdatesSelectedAccentIndex()
    {
        await _sut.SetAccentColorAsync(3);

        _sut.SelectedAccentIndex.Should().Be(3);
    }

    [Fact]
    public async Task SetAccentColorAsync_ClampsToValidRange()
    {
        await _sut.SetAccentColorAsync(99);

        _sut.SelectedAccentIndex.Should().BeLessThan(DesignTokens.AccentPalette.Length);
    }
}

/// <summary>
/// Tests for <see cref="DesignTokens"/>.
/// </summary>
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
    public void AccentPalette_Has8Colors()
    {
        DesignTokens.AccentPalette.Should().HaveCount(8);
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
