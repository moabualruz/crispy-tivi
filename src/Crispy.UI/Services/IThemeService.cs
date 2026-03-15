using Crispy.Domain.Enums;

namespace Crispy.UI.Services;

/// <summary>
/// Runtime theme switching with persistence.
/// </summary>
public interface IThemeService
{
    /// <summary>
    /// Currently active theme variant.
    /// </summary>
    ThemeVariant CurrentTheme { get; }

    /// <summary>
    /// Whether reduced motion is enabled.
    /// </summary>
    bool IsReducedMotion { get; }

    /// <summary>
    /// Currently selected accent color palette index.
    /// </summary>
    int SelectedAccentIndex { get; }

    /// <summary>
    /// Switches the active theme and persists the choice.
    /// </summary>
    Task SetThemeAsync(ThemeVariant theme);

    /// <summary>
    /// Loads the persisted theme on startup.
    /// </summary>
    Task InitializeAsync();

    /// <summary>
    /// Sets reduced motion preference and persists.
    /// </summary>
    Task SetReducedMotionAsync(bool enabled);

    /// <summary>
    /// Sets the accent color from the palette and persists.
    /// </summary>
    Task SetAccentColorAsync(int paletteIndex);

    /// <summary>
    /// Fired when the theme variant changes.
    /// </summary>
    event Action<ThemeVariant>? ThemeChanged;
}
