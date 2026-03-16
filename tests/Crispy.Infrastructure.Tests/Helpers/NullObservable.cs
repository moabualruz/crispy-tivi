namespace Crispy.Infrastructure.Tests.Helpers;

/// <summary>
/// Minimal BCL-only no-op observable for unit test stubs — avoids System.Reactive dependency.
/// </summary>
internal sealed class NullObservable<T> : IObservable<T>
{
    public IDisposable Subscribe(IObserver<T> observer) => NullDisposable.Instance;
}

