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
    /// </summary>
    public bool IsEnabledForCurrentPlatform()
    {
        if (OperatingSystem.IsWindows()) return IsEnabledForPlatform("Windows");
        if (OperatingSystem.IsLinux()) return IsEnabledForPlatform("Linux");
        if (OperatingSystem.IsMacOS()) return IsEnabledForPlatform("macOS");
        if (OperatingSystem.IsAndroid()) return IsEnabledForPlatform("Android");
        if (OperatingSystem.IsIOS()) return IsEnabledForPlatform("iOS");
        if (OperatingSystem.IsBrowser()) return IsEnabledForPlatform("Browser");
        return IsEnabledForPlatform("Unknown");
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
