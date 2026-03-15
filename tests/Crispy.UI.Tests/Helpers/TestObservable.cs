namespace Crispy.UI.Tests.Helpers;

/// <summary>
/// Minimal BCL-only observable subject for unit tests — avoids System.Reactive dependency.
/// </summary>
internal sealed class TestSubject<T> : IObservable<T>
{
    private readonly List<IObserver<T>> _observers = [];

    public IDisposable Subscribe(IObserver<T> observer)
    {
        _observers.Add(observer);
        return new Unsubscriber(_observers, observer);
    }

    public void OnNext(T value)
    {
        foreach (var observer in _observers.ToList())
            observer.OnNext(value);
    }

    public void OnCompleted()
    {
        foreach (var observer in _observers.ToList())
            observer.OnCompleted();
    }

    public void OnError(Exception error)
    {
        foreach (var observer in _observers.ToList())
            observer.OnError(error);
    }

    private sealed class Unsubscriber(List<IObserver<T>> observers, IObserver<T> observer) : IDisposable
    {
        public void Dispose() => observers.Remove(observer);
    }
}
