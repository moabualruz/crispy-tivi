using System.Globalization;

using Avalonia.Data.Converters;
using Avalonia.Media;

namespace Crispy.UI.Converters;

/// <summary>
/// Converts a bool (IsCurrent) to a background brush for the current EPG programme.
/// Returns a semi-transparent accent brush when true, Transparent when false.
/// </summary>
public sealed class ProgrammeHighlightConverter : IValueConverter
{
    /// <summary>
    /// Singleton instance.
    /// </summary>
    public static readonly ProgrammeHighlightConverter Instance = new();

    /// <inheritdoc />
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        if (value is true)
        {
            return new SolidColorBrush(Color.FromArgb(40, 98, 0, 238));
        }

        return Brushes.Transparent;
    }

    /// <inheritdoc />
    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        throw new NotSupportedException();
    }
}
