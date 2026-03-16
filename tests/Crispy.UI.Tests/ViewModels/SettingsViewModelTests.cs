using Crispy.Application.Configuration;
using Crispy.Application.Services;
using Crispy.Domain.Enums;
using Crispy.Domain.Interfaces;
using Crispy.UI.Navigation;
using Crispy.UI.Services;
using Crispy.UI.ViewModels;

using FluentAssertions;

using Microsoft.Extensions.Options;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.ViewModels;

[Trait("Category", "Unit")]
public class SettingsViewModelTests
{
    private readonly IThemeService _themeService;
    private readonly ILocalizationService _localizationService;
    private readonly ISettingsService _settingsService;
    private readonly IOptions<FeatureFlagOptions> _featureFlags;
    private readonly SourcesViewModel _sourcesVm;
    private readonly SettingsViewModel _sut;

    public SettingsViewModelTests()
    {
        _themeService = Substitute.For<IThemeService>();
        _themeService.CurrentTheme.Returns(ThemeVariant.Dark);
        _themeService.SelectedAccentIndex.Returns(0);
        _themeService.IsReducedMotion.Returns(false);
        _themeService.SetThemeAsync(Arg.Any<ThemeVariant>()).Returns(Task.CompletedTask);
        _themeService.SetAccentColorAsync(Arg.Any<int>()).Returns(Task.CompletedTask);
        _themeService.SetReducedMotionAsync(Arg.Any<bool>()).Returns(Task.CompletedTask);

        _localizationService = Substitute.For<ILocalizationService>();
        _localizationService.CurrentLocale.Returns("en");
        _localizationService.SetLocaleAsync(Arg.Any<string>()).Returns(Task.CompletedTask);

        _settingsService = Substitute.For<ISettingsService>();
        _featureFlags = Options.Create(new FeatureFlagOptions());

        var sourceRepository = Substitute.For<ISourceRepository>();
        sourceRepository.GetAllAsync()
            .Returns(Task.FromResult<IReadOnlyList<Crispy.Domain.Entities.Source>>([]));
        var navigationService = Substitute.For<INavigationService>();
        _sourcesVm = new SourcesViewModel(sourceRepository, navigationService);

        _sut = new SettingsViewModel(
            _themeService,
            _localizationService,
            _settingsService,
            _featureFlags,
            _sourcesVm);
    }

    // ── Constructor / defaults ─────────────────────────────────────────────────

    [Fact]
    public void Constructor_DoesNotThrow()
    {
        var act = () => new SettingsViewModel(
            _themeService, _localizationService, _settingsService, _featureFlags, _sourcesVm);
        act.Should().NotThrow();
    }

    [Fact]
    public void Title_IsSettings()
    {
        _sut.Title.Should().Be("Settings");
    }

    [Fact]
    public void Categories_HasSixItems()
    {
        _sut.Categories.Should().HaveCount(6);
    }

    [Fact]
    public void SelectedCategory_DefaultsToFirst()
    {
        _sut.SelectedCategory.Should().Be(_sut.Categories[0]);
    }

    [Fact]
    public void SelectedTheme_ReadsFromThemeService()
    {
        _sut.SelectedTheme.Should().Be(ThemeVariant.Dark);
    }

    [Fact]
    public void SelectedAccentIndex_ReadsFromThemeService()
    {
        _sut.SelectedAccentIndex.Should().Be(0);
    }

    [Fact]
    public void IsReducedMotion_ReadsFromThemeService()
    {
        _sut.IsReducedMotion.Should().BeFalse();
    }

    [Fact]
    public void SelectedLocaleOption_DefaultsToEnglish()
    {
        _sut.SelectedLocaleOption.Code.Should().Be("en");
    }

    [Fact]
    public void SourcesVm_IsNotNull()
    {
        _sut.SourcesVm.Should().NotBeNull();
        _sut.SourcesVm.Should().Be(_sourcesVm);
    }

    [Fact]
    public void AvailableLocales_IsNotEmpty()
    {
        _sut.AvailableLocales.Should().NotBeEmpty();
    }

    // ── Theme change propagates to service ────────────────────────────────────

    [Fact]
    public void SelectedTheme_WhenChanged_CallsSetThemeAsync()
    {
        _sut.SelectedTheme = ThemeVariant.Light;
        _themeService.Received(1).SetThemeAsync(ThemeVariant.Light);
    }

    // ── Locale change propagates to service ───────────────────────────────────

    [Fact]
    public void SelectedLocaleOption_WhenChanged_CallsSetLocaleAsync()
    {
        var arLocale = _sut.AvailableLocales.First(l => l.Code == "ar");
        _sut.SelectedLocaleOption = arLocale;
        _localizationService.Received(1).SetLocaleAsync("ar");
    }

    // ── AccentIndex change propagates ─────────────────────────────────────────

    [Fact]
    public void SelectedAccentIndex_WhenChanged_CallsSetAccentColorAsync()
    {
        _sut.SelectedAccentIndex = 3;
        _themeService.Received(1).SetAccentColorAsync(3);
    }

    // ── IsReducedMotion change propagates ─────────────────────────────────────

    [Fact]
    public void IsReducedMotion_WhenChanged_CallsSetReducedMotionAsync()
    {
        _sut.IsReducedMotion = true;
        _themeService.Received(1).SetReducedMotionAsync(true);
    }

    // ── ResetCategoryCommand ──────────────────────────────────────────────────

    [Fact]
    public async Task ResetCategoryCommand_WhenGeneralCategory_ResetsToDefaults()
    {
        _sut.SelectedCategory = _sut.Categories.First(c => c.Name == "General");
        _sut.SelectedTheme = ThemeVariant.Light;
        _sut.SelectedAccentIndex = 2;
        _sut.IsReducedMotion = true;

        await _sut.ResetCategoryCommand.ExecuteAsync(null);

        _sut.SelectedTheme.Should().Be(ThemeVariant.Dark);
        _sut.SelectedAccentIndex.Should().Be(0);
        _sut.IsReducedMotion.Should().BeFalse();
        _sut.SelectedLocaleOption.Code.Should().Be("en");
    }

    [Fact]
    public async Task ResetCategoryCommand_WhenNullCategory_DoesNotThrow()
    {
        _sut.SelectedCategory = null;
        var act = async () => await _sut.ResetCategoryCommand.ExecuteAsync(null);
        await act.Should().NotThrowAsync();
    }

    // ── FactoryResetCommand ───────────────────────────────────────────────────

    [Fact]
    public async Task FactoryResetCommand_ResetsAllSettingsToDefaults()
    {
        _sut.SelectedTheme = ThemeVariant.Light;
        _sut.SelectedAccentIndex = 5;
        _sut.IsReducedMotion = true;
        _sut.SelectedCategory = _sut.Categories[3];

        await _sut.FactoryResetCommand.ExecuteAsync(null);

        _sut.SelectedTheme.Should().Be(ThemeVariant.Dark);
        _sut.SelectedAccentIndex.Should().Be(0);
        _sut.IsReducedMotion.Should().BeFalse();
        _sut.SelectedLocaleOption.Code.Should().Be("en");
        _sut.SelectedCategory.Should().Be(_sut.Categories[0]);
    }

    // ── BuildDate is not null ─────────────────────────────────────────────────

    [Fact]
    public void BuildDate_IsNotNullOrEmpty()
    {
        _sut.BuildDate.Should().NotBeNullOrEmpty();
    }

    // ── AppVersion ────────────────────────────────────────────────────────────

    [Fact]
    public void AppVersion_IsNotNullOrEmpty()
    {
        _sut.AppVersion.Should().NotBeNullOrEmpty();
    }

    // ── AvailableThemes ───────────────────────────────────────────────────────

    [Fact]
    public void AvailableThemes_HasThreeItems()
    {
        _sut.AvailableThemes.Should().HaveCount(3,
            "Dark, OledBlack, and Light are the three supported theme variants");
    }

    // ── IsDebugDiagnosticsEnabled ─────────────────────────────────────────────

    [Fact]
    public void IsDebugDiagnosticsEnabled_ReturnsFalse_WhenFeatureFlagNotSet()
    {
        // Default FeatureFlagOptions has no flags enabled.
        _sut.IsDebugDiagnosticsEnabled.Should().BeFalse();
    }

    // ── ResetCategoryCommand — non-General category ───────────────────────────

    [Fact]
    public async Task ResetCategoryCommand_WhenNonGeneralCategory_DoesNotResetTheme()
    {
        _sut.SelectedCategory = _sut.Categories.First(c => c.Name == "Sources");
        _sut.SelectedTheme = ThemeVariant.Light;

        await _sut.ResetCategoryCommand.ExecuteAsync(null);

        // Non-General category reset is a no-op — theme should stay as set.
        _sut.SelectedTheme.Should().Be(ThemeVariant.Light,
            "resetting a non-General category must not touch the theme setting");
    }

    // ── AccentPalette ─────────────────────────────────────────────────────────

    [Fact]
    public void AccentPalette_IsNotEmpty()
    {
        _sut.AccentPalette.Should().NotBeEmpty("design tokens must define at least one accent color");
    }
}
