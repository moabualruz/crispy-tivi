using System.Globalization;

using Avalonia.Data.Converters;

namespace Crispy.UI.Converters;

/// <summary>
/// Converts a UTC DateTime to a local-time formatted string (HH:mm).
/// Not used directly in AXAML bindings (formatting is done in EpgProgrammeItem),
/// but provided for completeness and future direct-binding use.
/// </summary>
public sealed class UtcToLocalTimeConverter : IValueConverter
{
    /// <inheritdoc />
    public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        if (value is DateTime utc)
        {
            return utc.ToLocalTime().ToString("HH:mm", culture);
        }

        return null;
    }

    /// <inheritdoc />
    public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        throw new NotSupportedException();
    }
}
