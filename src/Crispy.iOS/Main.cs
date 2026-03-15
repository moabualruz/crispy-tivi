using UIKit;

namespace Crispy.iOS;

/// <summary>
/// iOS application entry point.
/// </summary>
public static class Application
{
    /// <summary>
    /// Main entry point for the iOS application.
    /// </summary>
    static void Main(string[] args)
    {
        UIApplication.Main(args, null, typeof(AppDelegate));
    }
}
