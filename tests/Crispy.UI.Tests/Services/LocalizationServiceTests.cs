using Crispy.Application.Services;
using Crispy.UI.Services;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.Services;

/// <summary>
/// Tests for <see cref="LocalizationService"/>.
/// </summary>
public class LocalizationServiceTests
{
    private readonly ISettingsService _settingsService;
    private readonly LocalizationService _sut;

    public LocalizationServiceTests()
    {
        _settingsService = Substitute.For<ISettingsService>();
        _settingsService.GetLocaleAsync(Arg.Any<int?>())
            .Returns("en");
        _sut = new LocalizationService(_settingsService);
    }

    [Fact]
    public void CurrentLocale_DefaultsToEnglish()
    {
        _sut.CurrentLocale.Should().Be("en");
    }

    [Theory]
    [InlineData("en")]
    [InlineData("ar")]
    [InlineData("tr")]
    [InlineData("fr")]
    [InlineData("de")]
    public async Task SetLocaleAsync_UpdatesCurrentLocale(string locale)
    {
        await _sut.SetLocaleAsync(locale);

        _sut.CurrentLocale.Should().Be(locale);
    }

    [Fact]
    public async Task SetLocaleAsync_PersistsViaSettingsService()
    {
        await _sut.SetLocaleAsync("ar");

        await _settingsService.Received(1)
            .SetLocaleAsync("ar", Arg.Any<int?>());
    }

    [Fact]
    public async Task SetLocaleAsync_FiresLocaleChangedEvent()
    {
        string? received = null;
        _sut.LocaleChanged += l => received = l;

        await _sut.SetLocaleAsync("fr");

        received.Should().Be("fr");
    }

    [Fact]
    public async Task SetLocaleAsync_DoesNotFireEvent_WhenSameLocale()
    {
        await _sut.InitializeAsync();
        var fired = false;
        _sut.LocaleChanged += _ => fired = true;

        await _sut.SetLocaleAsync("en");

        fired.Should().BeFalse();
    }

    [Fact]
    public async Task SetLocaleAsync_Arabic_SetsRtlDirection()
    {
        await _sut.SetLocaleAsync("ar");

        _sut.IsRightToLeft.Should().BeTrue();
    }

    [Fact]
    public async Task SetLocaleAsync_English_SetsLtrDirection()
    {
        await _sut.SetLocaleAsync("ar");
        await _sut.SetLocaleAsync("en");

        _sut.IsRightToLeft.Should().BeFalse();
    }

    [Fact]
    public void AvailableLocales_ContainsFiveLocales()
    {
        _sut.AvailableLocales.Should().HaveCount(5);
    }

    [Fact]
    public void AvailableLocales_ContainsArabicWithNativeName()
    {
        _sut.AvailableLocales.Should().Contain(l =>
            l.Code == "ar" && l.NativeName == "\u0627\u0644\u0639\u0631\u0628\u064a\u0629");
    }

    [Fact]
    public async Task InitializeAsync_LoadsPersistedLocale()
    {
        _settingsService.GetLocaleAsync(Arg.Any<int?>())
            .Returns("de");

        await _sut.InitializeAsync();

        _sut.CurrentLocale.Should().Be("de");
    }

    [Fact]
    public async Task SetLocaleAsync_InvalidLocale_DoesNotChange()
    {
        await _sut.SetLocaleAsync("zz");

        _sut.CurrentLocale.Should().Be("en");
    }

    [Fact]
    public async Task InitializeAsync_InvalidLocaleFromSettings_StaysAtDefault()
    {
        _settingsService.GetLocaleAsync(Arg.Any<int?>())
            .Returns("xx-invalid");

        await _sut.InitializeAsync();

        _sut.CurrentLocale.Should().Be("en");
    }

    [Fact]
    public async Task InitializeAsync_SetsIsRightToLeft_WhenLocaleIsArabic()
    {
        _settingsService.GetLocaleAsync(Arg.Any<int?>())
            .Returns("ar");

        await _sut.InitializeAsync();

        _sut.IsRightToLeft.Should().BeTrue();
    }

    [Fact]
    public void IsRightToLeft_DefaultsFalse()
    {
        _sut.IsRightToLeft.Should().BeFalse();
    }
}
