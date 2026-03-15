using System.Globalization;

using Avalonia.Data.Converters;

namespace Crispy.UI.Converters;

/// <summary>
/// Converts a SettingsCategory to bool by comparing its Name to the ConverterParameter.
/// </summary>
public sealed class CategoryMatchConverter : IValueConverter
{
    /// <summary>
    /// Singleton instance.
    /// </summary>
    public static readonly CategoryMatchConverter Instance = new();

    /// <inheritdoc />
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        if (value is ViewModels.SettingsCategory category && parameter is string name)
        {
            return category.Name == name;
        }

        return false;
    }

    /// <inheritdoc />
    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        throw new NotSupportedException();
    }
}
