namespace Crispy.Application.Player;

/// <summary>
/// Minimal Subject implementation that avoids a dependency on System.Reactive.
/// Implements IObservable&lt;T&gt;. Thread-safe observer list.
///
/// Used by player services as a drop-in replacement for
/// System.Reactive.Subjects.Subject&lt;T&gt; until the System.Reactive package
/// can be restored (blocked by the NuGet restore issue documented in STATE.md).
/// </summary>
public sealed class SimpleSubject<T> : IObservable<T>, IDisposable
{
    private readonly List<IObserver<T>> _observers = [];
    private readonly Lock _lock = new();
    private bool _completed;
    private Exception? _error;

    /// <summary>Emits a value to all active observers.</summary>
    public void OnNext(T value)
    {
        IObserver<T>[] snapshot;
        lock (_lock)
        {
            if (_completed)
            {
                return;
            }

            snapshot = [.. _observers];
        }

        foreach (var observer in snapshot)
        {
            observer.OnNext(value);
        }
    }

    /// <summary>Signals completion to all observers and unsubscribes them.</summary>
    public void OnCompleted()
    {
        IObserver<T>[] snapshot;
        lock (_lock)
        {
            if (_completed)
            {
                return;
            }

            _completed = true;
            snapshot = [.. _observers];
            _observers.Clear();
        }

        foreach (var observer in snapshot)
        {
            observer.OnCompleted();
        }
    }

    /// <summary>Signals an error to all observers and unsubscribes them.</summary>
    public void OnError(Exception error)
    {
        _error = error;
        IObserver<T>[] snapshot;
        lock (_lock)
        {
            if (_completed)
            {
                return;
            }

            _completed = true;
            snapshot = [.. _observers];
            _observers.Clear();
        }

        foreach (var observer in snapshot)
        {
            observer.OnError(error);
        }
    }

    /// <inheritdoc />
    public IDisposable Subscribe(IObserver<T> observer)
    {
        lock (_lock)
        {
            if (_completed)
            {
                if (_error != null)
                {
                    observer.OnError(_error);
                }
                else
                {
                    observer.OnCompleted();
                }

                return NullDisposable.Instance;
            }

            _observers.Add(observer);
        }

        return new Subscription(this, observer);
    }

    /// <inheritdoc />
    public void Dispose() => OnCompleted();

    private void Unsubscribe(IObserver<T> observer)
    {
        lock (_lock)
        {
            _observers.Remove(observer);
        }
    }

    private sealed class Subscription : IDisposable
    {
        private readonly SimpleSubject<T> _subject;
        private readonly IObserver<T> _observer;
        private bool _disposed;

        public Subscription(SimpleSubject<T> subject, IObserver<T> observer)
        {
            _subject = subject;
            _observer = observer;
        }

        public void Dispose()
        {
            if (_disposed)
            {
                return;
            }

            _disposed = true;
            _subject.Unsubscribe(_observer);
        }
    }

    private sealed class NullDisposable : IDisposable
    {
        public static readonly NullDisposable Instance = new();

        public void Dispose() { }
    }
}
