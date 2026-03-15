using System.Globalization;

using Avalonia.Headless.XUnit;
using Avalonia.Media;

using Crispy.UI.Converters;
using Crispy.UI.ViewModels;

using FluentAssertions;

using FluentIcons.Common;

using Xunit;

namespace Crispy.UI.Tests.Converters;

/// <summary>
/// Unit tests for CategoryMatchConverter.
/// </summary>
[Trait("Category", "Unit")]
public class CategoryMatchConverterTests
{
    private readonly CategoryMatchConverter _sut = CategoryMatchConverter.Instance;

    [Fact]
    public void Convert_ReturnsTrue_WhenCategoryNameMatchesParameter()
    {
        var category = new SettingsCategory("Playback", Symbol.Play, "SettingsPlayback");

        var result = _sut.Convert(category, typeof(bool), "Playback", CultureInfo.InvariantCulture);

        result.Should().Be(true);
    }

    [Fact]
    public void Convert_ReturnsFalse_WhenCategoryNameDoesNotMatchParameter()
    {
        var category = new SettingsCategory("General", Symbol.Settings, "SettingsGeneral");

        var result = _sut.Convert(category, typeof(bool), "Playback", CultureInfo.InvariantCulture);

        result.Should().Be(false);
    }

    [Fact]
    public void Convert_ReturnsFalse_WhenValueIsNull()
    {
        var result = _sut.Convert(null, typeof(bool), "Playback", CultureInfo.InvariantCulture);

        result.Should().Be(false);
    }

    [Fact]
    public void Convert_ReturnsFalse_WhenParameterIsNull()
    {
        var category = new SettingsCategory("General", Symbol.Settings, "SettingsGeneral");

        var result = _sut.Convert(category, typeof(bool), null, CultureInfo.InvariantCulture);

        result.Should().Be(false);
    }

    [Fact]
    public void Convert_ReturnsFalse_WhenValueIsNotSettingsCategory()
    {
        var result = _sut.Convert("not a category", typeof(bool), "General", CultureInfo.InvariantCulture);

        result.Should().Be(false);
    }

    [Fact]
    public void ConvertBack_ThrowsNotSupportedException()
    {
        var act = () => _sut.ConvertBack(true, typeof(SettingsCategory), null, CultureInfo.InvariantCulture);

        act.Should().Throw<NotSupportedException>();
    }
}

/// <summary>
/// Unit tests for ProgrammeHighlightConverter.
/// </summary>
[Trait("Category", "Unit")]
public class ProgrammeHighlightConverterTests
{
    private readonly ProgrammeHighlightConverter _sut = ProgrammeHighlightConverter.Instance;

    [AvaloniaFact]
    public void Convert_ReturnsSolidColorBrush_WhenValueIsTrue()
    {
        var result = _sut.Convert(true, typeof(IBrush), null, CultureInfo.InvariantCulture);

        result.Should().BeOfType<SolidColorBrush>();
        var brush = (SolidColorBrush)result;
        brush.Color.A.Should().Be(40);
    }

    [Fact]
    public void Convert_ReturnsTransparent_WhenValueIsFalse()
    {
        var result = _sut.Convert(false, typeof(IBrush), null, CultureInfo.InvariantCulture);

        result.Should().Be(Brushes.Transparent);
    }

    [Fact]
    public void Convert_ReturnsTransparent_WhenValueIsNull()
    {
        var result = _sut.Convert(null, typeof(IBrush), null, CultureInfo.InvariantCulture);

        result.Should().Be(Brushes.Transparent);
    }

    [Fact]
    public void Convert_ReturnsTransparent_WhenValueIsNotBool()
    {
        var result = _sut.Convert("not a bool", typeof(IBrush), null, CultureInfo.InvariantCulture);

        result.Should().Be(Brushes.Transparent);
    }

    [Fact]
    public void ConvertBack_ThrowsNotSupportedException()
    {
        var act = () => _sut.ConvertBack(Brushes.Transparent, typeof(bool), null, CultureInfo.InvariantCulture);

        act.Should().Throw<NotSupportedException>();
    }
}

/// <summary>
/// Unit tests for UtcToLocalTimeConverter.
/// </summary>
[Trait("Category", "Unit")]
public class UtcToLocalTimeConverterTests
{
    private readonly UtcToLocalTimeConverter _sut = new();

    [Fact]
    public void Convert_ReturnsFormattedLocalTime_WhenValueIsDateTimeUtc()
    {
        var utc = new DateTime(2024, 6, 15, 14, 30, 0, DateTimeKind.Utc);

        var result = _sut.Convert(utc, typeof(string), null, CultureInfo.InvariantCulture);

        result.Should().NotBeNull();
        result.Should().BeOfType<string>();
        ((string)result!).Should().MatchRegex(@"^\d{2}:\d{2}$");
    }

    [Fact]
    public void Convert_ReturnsNull_WhenValueIsNull()
    {
        var result = _sut.Convert(null, typeof(string), null, CultureInfo.InvariantCulture);

        result.Should().BeNull();
    }

    [Fact]
    public void Convert_ReturnsNull_WhenValueIsNotDateTime()
    {
        var result = _sut.Convert("not a date", typeof(string), null, CultureInfo.InvariantCulture);

        result.Should().BeNull();
    }

    [Fact]
    public void Convert_ReturnsNull_WhenValueIsDateTimeOffset()
    {
        // UtcToLocalTimeConverter only handles DateTime, not DateTimeOffset
        var dto = new DateTimeOffset(2024, 6, 15, 14, 30, 0, TimeSpan.Zero);

        var result = _sut.Convert(dto, typeof(string), null, CultureInfo.InvariantCulture);

        result.Should().BeNull();
    }

    [Fact]
    public void ConvertBack_ThrowsNotSupportedException()
    {
        var act = () => _sut.ConvertBack("14:30", typeof(DateTime), null, CultureInfo.InvariantCulture);

        act.Should().Throw<NotSupportedException>();
    }
}
