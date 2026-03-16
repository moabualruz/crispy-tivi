namespace Crispy.Infrastructure.Tests.Helpers;

/// <summary>
/// No-op IDisposable — avoids System.Reactive dependency for test stubs.
/// </summary>
internal sealed class NullDisposable : IDisposable
{
    public static readonly NullDisposable Instance = new();
    public void Dispose() { }
}
