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
        if (!Enabled)
        {
            return false;
        }

        if (Platforms.Count == 0 || Platforms.Contains("*"))
        {
            return true;
        }

        if (OperatingSystem.IsWindows() && Platforms.Contains("Windows"))
        {
            return true;
        }

        if (OperatingSystem.IsLinux() && Platforms.Contains("Linux"))
        {
            return true;
        }

        if (OperatingSystem.IsMacOS() && Platforms.Contains("macOS"))
        {
            return true;
        }

        if (OperatingSystem.IsAndroid() && Platforms.Contains("Android"))
        {
            return true;
        }

        if (OperatingSystem.IsIOS() && Platforms.Contains("iOS"))
        {
            return true;
        }

        if (OperatingSystem.IsBrowser() && Platforms.Contains("Browser"))
        {
            return true;
        }

        return false;
    }
}
