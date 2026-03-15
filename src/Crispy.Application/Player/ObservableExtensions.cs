namespace Crispy.Application.Player;

/// <summary>
/// Lightweight extension methods for IObservable&lt;T&gt; that replicate the
/// System.Reactive Subscribe(Action) overloads.
/// Used until System.Reactive is restorable (NuGet restore blocker — see STATE.md).
/// </summary>
public static class ObservableExtensions
{
    /// <summary>Subscribes with an onNext action; errors and completion are no-ops.</summary>
    public static IDisposable Subscribe<T>(this IObservable<T> observable, Action<T> onNext)
    {
        ArgumentNullException.ThrowIfNull(observable);
        ArgumentNullException.ThrowIfNull(onNext);
        return observable.Subscribe(new ActionObserver<T>(onNext));
    }

    private sealed class ActionObserver<T> : IObserver<T>
    {
        private readonly Action<T> _onNext;

        public ActionObserver(Action<T> onNext) => _onNext = onNext;

        public void OnNext(T value) => _onNext(value);
        public void OnError(Exception error) { }
        public void OnCompleted() { }
    }
}
