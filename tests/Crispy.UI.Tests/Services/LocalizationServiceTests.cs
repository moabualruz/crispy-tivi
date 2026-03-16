using Crispy.Application.Services;
using Crispy.UI.Services;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.UI.Tests.Services;

/// <summary>
/// Tests for <see cref="LocalizationService"/>.
/// </summary>
[Trait("Category", "Unit")]
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

    [Fact]
    public async Task SetLocaleAsync_InvalidLocale_DoesNotFireEvent()
    {
        var fired = false;
        _sut.LocaleChanged += _ => fired = true;

        await _sut.SetLocaleAsync("xx-bad");

        fired.Should().BeFalse();
    }

    [Fact]
    public async Task SetLocaleAsync_InvalidLocale_DoesNotPersist()
    {
        await _sut.SetLocaleAsync("zz");

        await _settingsService.DidNotReceive().SetLocaleAsync(Arg.Any<string>(), Arg.Any<int?>());
    }

    [Fact]
    public void AvailableLocales_FirstEntry_IsEnglish()
    {
        _sut.AvailableLocales[0].Code.Should().Be("en");
        _sut.AvailableLocales[0].NativeName.Should().Be("English");
    }

    [Fact]
    public void AvailableLocales_ContainsTurkish()
    {
        _sut.AvailableLocales.Should().Contain(l => l.Code == "tr");
    }

    [Fact]
    public async Task SetLocaleAsync_NoSubscribers_DoesNotThrow()
    {
        // LocaleChanged has no subscribers — null-conditional invoke must not throw
        var act = async () => await _sut.SetLocaleAsync("de");

        await act.Should().NotThrowAsync();
        _sut.CurrentLocale.Should().Be("de");
    }

    [Fact]
    public async Task InitializeAsync_SetsIsRightToLeft_WhenLocaleIsFrench()
    {
        // French is LTR — verifies the false-branch of IsRightToLeft in InitializeAsync
        _settingsService.GetLocaleAsync(Arg.Any<int?>())
            .Returns("fr");

        await _sut.InitializeAsync();

        _sut.IsRightToLeft.Should().BeFalse();
    }

    [Fact]
    public async Task SetLocaleAsync_SameLocaleTwice_DoesNotPersistSecondTime()
    {
        // First call persists; second call with same locale is a no-op and must not persist
        await _sut.SetLocaleAsync("de");
        _settingsService.ClearReceivedCalls();

        await _sut.SetLocaleAsync("de");

        await _settingsService.DidNotReceive().SetLocaleAsync(Arg.Any<string>(), Arg.Any<int?>());
    }

    [Fact]
    public async Task SetLocaleAsync_CaseInsensitiveCode_IsAccepted()
    {
        // ValidCodes uses OrdinalIgnoreCase — "FR" must be treated as valid
        await _sut.SetLocaleAsync("FR");

        _sut.CurrentLocale.Should().Be("FR");
    }

    [Theory]
    [InlineData("en")]
    [InlineData("ar")]
    [InlineData("tr")]
    [InlineData("fr")]
    [InlineData("de")]
    public async Task InitializeAsync_SetsCurrentLocale_ForEachValidCode(string locale)
    {
        _settingsService.GetLocaleAsync(Arg.Any<int?>()).Returns(locale);

        await _sut.InitializeAsync();

        _sut.CurrentLocale.Should().Be(locale);
    }

    [Fact]
    public async Task SetLocaleAsync_MultipleSubscribers_AllReceiveEvent()
    {
        var received = new List<string>();
        _sut.LocaleChanged += l => received.Add("a:" + l);
        _sut.LocaleChanged += l => received.Add("b:" + l);

        await _sut.SetLocaleAsync("tr");

        received.Should().Contain("a:tr").And.Contain("b:tr");
    }
}
