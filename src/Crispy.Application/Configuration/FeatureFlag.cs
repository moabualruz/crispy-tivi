namespace Crispy.Application.Configuration;

/// <summary>
/// Represents a single feature flag with platform-aware evaluation.
/// </summary>
public class FeatureFlag
{
    /// <summary>
    /// Whether the feature is enabled globally.
    /// </summary>
    public bool Enabled { get; set; }

    /// <summary>
    /// List of platform identifiers where the feature is active.
    /// Use "*" to match all platforms.
    /// Valid values: "Windows", "Linux", "macOS", "Android", "iOS", "Browser", "*"
    /// </summary>
    public List<string> Platforms { get; set; } = [];

    /// <summary>
    /// Evaluates whether the feature is enabled for the current platform.
    /// Delegates to <see cref="ResolvePlatformName"/> for OS detection so subclasses
    /// (or test doubles) can override the detection logic without changing callers.
    /// </summary>
    public bool IsEnabledForCurrentPlatform() =>
        IsEnabledForPlatform(ResolvePlatformName());

    /// <summary>
    /// Returns the name of the current platform.
    /// Override in tests via subclass to exercise non-host platform branches.
    /// </summary>
    protected internal virtual string ResolvePlatformName()
    {
        if (OperatingSystem.IsWindows()) return "Windows";
        if (OperatingSystem.IsLinux()) return "Linux";
        if (OperatingSystem.IsMacOS()) return "macOS";
        if (OperatingSystem.IsAndroid()) return "Android";
        if (OperatingSystem.IsIOS()) return "iOS";
        if (OperatingSystem.IsBrowser()) return "Browser";
        return "Unknown";
    }

    /// <summary>
    /// Evaluates whether the feature is enabled for the specified platform name.
    /// Valid platform names: "Windows", "Linux", "macOS", "Android", "iOS", "Browser".
    /// </summary>
    public bool IsEnabledForPlatform(string platformName)
    {
        if (!Enabled)
            return false;

        if (Platforms.Count == 0 || Platforms.Contains("*"))
            return true;

        return Platforms.Contains(platformName);
    }
}
