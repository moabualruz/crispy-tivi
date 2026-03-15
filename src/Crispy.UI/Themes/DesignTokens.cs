using Avalonia.Media;

namespace Crispy.UI.Themes;

/// <summary>
/// Design system constants for spacing, radii, focus, and animation.
/// All UI elements reference these tokens for consistent layout.
/// </summary>
public static class DesignTokens
{
    // Spacing (4px grid)
    /// <summary>Extra small spacing: 4px.</summary>
    public const double SpacingXs = 4;

    /// <summary>Small spacing: 8px.</summary>
    public const double SpacingSm = 8;

    /// <summary>Medium spacing: 16px.</summary>
    public const double SpacingMd = 16;

    /// <summary>Large spacing: 24px.</summary>
    public const double SpacingLg = 24;

    /// <summary>Extra large spacing: 32px.</summary>
    public const double SpacingXl = 32;

    // Radii
    /// <summary>Small corner radius: 4px.</summary>
    public const double RadiusSm = 4;

    /// <summary>Medium corner radius: 8px.</summary>
    public const double RadiusMd = 8;

    /// <summary>Large corner radius: 12px.</summary>
    public const double RadiusLg = 12;

    // Focus
    /// <summary>Scale factor for focused elements (TV visibility).</summary>
    public const double FocusScaleFactor = 1.05;

    /// <summary>Blur radius for focus shadow glow.</summary>
    public const double FocusShadowBlur = 16;

    // Animation durations
    /// <summary>Default animation duration.</summary>
    public static readonly TimeSpan DefaultDuration = TimeSpan.FromMilliseconds(250);

    /// <summary>Fast animation duration.</summary>
    public static readonly TimeSpan FastDuration = TimeSpan.FromMilliseconds(150);

    /// <summary>Slow animation duration.</summary>
    public static readonly TimeSpan SlowDuration = TimeSpan.FromMilliseconds(400);

    /// <summary>
    /// Curated accent color palette (8 colors).
    /// Index maps to user selection in settings.
    /// </summary>
    public static readonly Color[] AccentPalette =
    [
        Color.Parse("#9CA3AF"), // Gray (default — professional)
        Color.Parse("#6366F1"), // Indigo
        Color.Parse("#14B8A6"), // Teal
        Color.Parse("#F43F5E"), // Rose
        Color.Parse("#F59E0B"), // Amber
        Color.Parse("#10B981"), // Emerald
        Color.Parse("#3B82F6"), // Blue
        Color.Parse("#8B5CF6"), // Purple
        Color.Parse("#F97316"), // Orange
    ];
}
