using Crispy.Application.Services;
using Crispy.Domain.Entities;
using Crispy.Domain.Enums;
using Crispy.Domain.Interfaces;
using FluentAssertions;
using NSubstitute;
using Xunit;

namespace Crispy.Application.Tests.Services;

[Trait("Category", "Unit")]
public class SettingsServiceTests
{
    private readonly ISettingsRepository _repository;
    private readonly SettingsService _sut;

    public SettingsServiceTests()
    {
        _repository = Substitute.For<ISettingsRepository>();
        _sut = new SettingsService(_repository);
    }

    // ── GetAsync ──────────────────────────────────────────────────────────────

    [Fact]
    public async Task GetAsync_WhenSettingNotFound_ReturnsDefaultValue()
    {
        _repository.GetAsync("missing", null).Returns((Setting?)null);

        var result = await _sut.GetAsync("missing", "default-value");

        result.Should().Be("default-value");
    }

    [Fact]
    public async Task GetAsync_WhenSettingExists_DeserializesAndReturnsValue()
    {
        _repository.GetAsync("volume", null)
            .Returns(new Setting { Key = "volume", Value = "75" });

        var result = await _sut.GetAsync("volume", 50);

        result.Should().Be(75);
    }

    [Fact]
    public async Task GetAsync_WhenValueIsInvalidJson_ReturnsDefaultValue()
    {
        _repository.GetAsync("broken", null)
            .Returns(new Setting { Key = "broken", Value = "not-valid-json{{" });

        var result = await _sut.GetAsync("broken", 42);

        result.Should().Be(42);
    }

    [Fact]
    public async Task GetAsync_WhenDeserializedValueIsNull_ReturnsDefaultValue()
    {
        _repository.GetAsync("nullable", null)
            .Returns(new Setting { Key = "nullable", Value = "null" });

        var result = await _sut.GetAsync("nullable", "fallback");

        result.Should().Be("fallback");
    }

    [Fact]
    public async Task GetAsync_WithProfileId_PassesProfileIdToRepository()
    {
        _repository.GetAsync("key", 5).Returns((Setting?)null);

        await _sut.GetAsync("key", "default", profileId: 5);

        await _repository.Received(1).GetAsync("key", 5);
    }

    // ── SetAsync ──────────────────────────────────────────────────────────────

    [Fact]
    public async Task SetAsync_SerializesValueAndCallsRepository()
    {
        await _sut.SetAsync("volume", 80);

        await _repository.Received(1).SetAsync("volume", "80", null);
    }

    [Fact]
    public async Task SetAsync_WithProfileId_PassesProfileIdToRepository()
    {
        await _sut.SetAsync("volume", 50, profileId: 3);

        await _repository.Received(1).SetAsync("volume", "50", 3);
    }

    [Fact]
    public async Task SetAsync_StringValue_SerializesWithJsonQuotes()
    {
        await _sut.SetAsync("name", "hello");

        await _repository.Received(1).SetAsync("name", "\"hello\"", null);
    }

    // ── GetThemeAsync ─────────────────────────────────────────────────────────

    [Fact]
    public async Task GetThemeAsync_WhenNotSet_ReturnsDarkDefault()
    {
        _repository.GetAsync("theme", null).Returns((Setting?)null);

        var result = await _sut.GetThemeAsync();

        result.Should().Be(ThemeVariant.Dark);
    }

    [Fact]
    public async Task GetThemeAsync_WhenSetToLight_ReturnsLight()
    {
        // ThemeVariant.Light = 2
        _repository.GetAsync("theme", null)
            .Returns(new Setting { Key = "theme", Value = "2" });

        var result = await _sut.GetThemeAsync();

        result.Should().Be(ThemeVariant.Light);
    }

    [Fact]
    public async Task GetThemeAsync_WithProfileId_PassesProfileIdToRepository()
    {
        _repository.GetAsync("theme", 7).Returns((Setting?)null);

        await _sut.GetThemeAsync(profileId: 7);

        await _repository.Received(1).GetAsync("theme", 7);
    }

    // ── SetThemeAsync ─────────────────────────────────────────────────────────

    [Fact]
    public async Task SetThemeAsync_PersistsThemeValue()
    {
        await _sut.SetThemeAsync(ThemeVariant.Light);

        await _repository.Received(1).SetAsync("theme", "2", null);
    }

    [Fact]
    public async Task SetThemeAsync_WithProfileId_PassesProfileIdToRepository()
    {
        await _sut.SetThemeAsync(ThemeVariant.Dark, profileId: 2);

        await _repository.Received(1).SetAsync("theme", Arg.Any<string>(), 2);
    }

    // ── GetLocaleAsync ────────────────────────────────────────────────────────

    [Fact]
    public async Task GetLocaleAsync_WhenNotSet_ReturnsEnDefault()
    {
        _repository.GetAsync("locale", null).Returns((Setting?)null);

        var result = await _sut.GetLocaleAsync();

        result.Should().Be("en");
    }

    [Fact]
    public async Task GetLocaleAsync_WhenSetToAr_ReturnsAr()
    {
        _repository.GetAsync("locale", null)
            .Returns(new Setting { Key = "locale", Value = "\"ar\"" });

        var result = await _sut.GetLocaleAsync();

        result.Should().Be("ar");
    }

    [Fact]
    public async Task GetLocaleAsync_WithProfileId_PassesProfileIdToRepository()
    {
        _repository.GetAsync("locale", 4).Returns((Setting?)null);

        await _sut.GetLocaleAsync(profileId: 4);

        await _repository.Received(1).GetAsync("locale", 4);
    }

    // ── SetLocaleAsync ────────────────────────────────────────────────────────

    [Fact]
    public async Task SetLocaleAsync_PersistsLocale()
    {
        await _sut.SetLocaleAsync("ar");

        await _repository.Received(1).SetAsync("locale", "\"ar\"", null);
    }

    [Fact]
    public async Task SetLocaleAsync_WithProfileId_PassesProfileIdToRepository()
    {
        await _sut.SetLocaleAsync("de", profileId: 9);

        await _repository.Received(1).SetAsync("locale", "\"de\"", 9);
    }

    // ── Roundtrip ─────────────────────────────────────────────────────────────

    [Fact]
    public async Task SetAndGetLocale_Roundtrip_ReturnsOriginalValue()
    {
        string? stored = null;
        _repository
            .When(r => r.SetAsync(Arg.Any<string>(), Arg.Any<string>(), Arg.Any<int?>()))
            .Do(ci => stored = ci.ArgAt<string>(1));
        _repository
            .GetAsync("locale", null)
            .Returns(_ => stored is null
                ? null
                : new Setting { Key = "locale", Value = stored });

        await _sut.SetLocaleAsync("ja");
        var result = await _sut.GetLocaleAsync();

        result.Should().Be("ja");
    }
}
