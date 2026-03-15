using Crispy.Application.Services;
using Crispy.Domain.Entities;
using Crispy.Domain.Enums;
using Crispy.Domain.Interfaces;

using FluentAssertions;

using NSubstitute;

using Xunit;

namespace Crispy.Application.Tests.Services;

public class SettingsServiceTests
{
    private readonly ISettingsRepository _repository;
    private readonly SettingsService _sut;

    public SettingsServiceTests()
    {
        _repository = Substitute.For<ISettingsRepository>();
        _sut = new SettingsService(_repository);
    }

    [Fact]
    public async Task GetAsync_ShouldReturnDefaultValue_WhenKeyNotFound()
    {
        _repository.GetAsync("missing", null).Returns((Setting?)null);

        var result = await _sut.GetAsync("missing", "default-value");

        result.Should().Be("default-value");
    }

    [Fact]
    public async Task GetAsync_ShouldReturnDeserializedValue_WhenKeyExists()
    {
        _repository.GetAsync("volume", null)
            .Returns(new Setting { Key = "volume", Value = "75" });

        var result = await _sut.GetAsync("volume", 50);

        result.Should().Be(75);
    }

    [Fact]
    public async Task SetAsync_ShouldSerializeAndPersist()
    {
        await _sut.SetAsync("volume", 80);

        await _repository.Received(1).SetAsync("volume", "80", null);
    }

    [Fact]
    public async Task GetThemeAsync_ShouldReturnDarkByDefault()
    {
        _repository.GetAsync("theme", null).Returns((Setting?)null);

        var result = await _sut.GetThemeAsync();

        result.Should().Be(ThemeVariant.Dark);
    }

    [Fact]
    public async Task SetThemeAsync_ShouldPersistThemeValue()
    {
        await _sut.SetThemeAsync(ThemeVariant.Light);

        await _repository.Received(1).SetAsync("theme", "2", null);
    }

    [Fact]
    public async Task GetLocaleAsync_ShouldReturnEnByDefault()
    {
        _repository.GetAsync("locale", null).Returns((Setting?)null);

        var result = await _sut.GetLocaleAsync();

        result.Should().Be("en");
    }

    [Fact]
    public async Task SetLocaleAsync_ShouldPersistLocale()
    {
        await _sut.SetLocaleAsync("ar");

        await _repository.Received(1).SetAsync("locale", "\"ar\"", null);
    }

    [Fact]
    public async Task GetAsync_ShouldReturnDefault_WhenJsonInvalid()
    {
        _repository.GetAsync("broken", null)
            .Returns(new Setting { Key = "broken", Value = "not-valid-json{{" });

        var result = await _sut.GetAsync("broken", 42);

        result.Should().Be(42);
    }
}
