namespace Crispy.Application.Configuration;

/// <summary>
/// Strongly-typed options for feature flags, bound from appsettings.json.
/// </summary>
public class FeatureFlagOptions
{
    /// <summary>
    /// Configuration section name.
    /// </summary>
    public const string Section = "FeatureFlags";

    /// <summary>
    /// Enables the embedded web server for remote control.
    /// </summary>
    public FeatureFlag EmbeddedWebServer { get; set; } = new();

    /// <summary>
    /// Enables XY focus navigation (TV/gamepad mode).
    /// </summary>
    public FeatureFlag UseXYFocus { get; set; } = new();

    /// <summary>
    /// Enables the custom focus manager for TV navigation.
    /// </summary>
    public FeatureFlag UseCustomFocusManager { get; set; } = new();

    /// <summary>
    /// Enables debug diagnostics overlay.
    /// </summary>
    public FeatureFlag DebugDiagnostics { get; set; } = new();
}
