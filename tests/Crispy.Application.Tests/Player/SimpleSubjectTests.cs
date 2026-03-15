using Crispy.Application.Player;
using FluentAssertions;
using Xunit;

namespace Crispy.Application.Tests.Player;

[Trait("Category", "Unit")]
public sealed class SimpleSubjectTests
{
    // -------------------------------------------------------------------------
    // OnNext
    // -------------------------------------------------------------------------

    [Fact]
    public void OnNext_DeliversValueToSubscriber_WhenSubscribed()
    {
        var subject = new SimpleSubject<int>();
        var received = new List<int>();
        subject.Subscribe(new ActionObserver<int>(received.Add));

        subject.OnNext(42);

        received.Should().ContainSingle().Which.Should().Be(42);
    }

    [Fact]
    public void OnNext_DeliversValueToAllSubscribers_WhenMultipleSubscribed()
    {
        var subject = new SimpleSubject<string>();
        var a = new List<string>();
        var b = new List<string>();
        subject.Subscribe(new ActionObserver<string>(a.Add));
        subject.Subscribe(new ActionObserver<string>(b.Add));

        subject.OnNext("hello");

        a.Should().ContainSingle("hello");
        b.Should().ContainSingle("hello");
    }

    [Fact]
    public void OnNext_DoesNotDeliver_AfterSubscriptionDisposed()
    {
        var subject = new SimpleSubject<int>();
        var received = new List<int>();
        var sub = subject.Subscribe(new ActionObserver<int>(received.Add));

        sub.Dispose();
        subject.OnNext(99);

        received.Should().BeEmpty();
    }

    [Fact]
    public void OnNext_IsSilent_AfterSubjectCompleted()
    {
        var subject = new SimpleSubject<int>();
        var received = new List<int>();
        subject.Subscribe(new ActionObserver<int>(received.Add));
        subject.OnCompleted();

        subject.OnNext(1);

        received.Should().BeEmpty();
    }

    // -------------------------------------------------------------------------
    // OnCompleted
    // -------------------------------------------------------------------------

    [Fact]
    public void OnCompleted_NotifiesObserver()
    {
        var subject = new SimpleSubject<int>();
        var completed = false;
        subject.Subscribe(new ActionObserver<int>(_ => { }, () => completed = true));

        subject.OnCompleted();

        completed.Should().BeTrue();
    }

    [Fact]
    public void OnCompleted_IsIdempotent_WhenCalledTwice()
    {
        var subject = new SimpleSubject<int>();
        var count = 0;
        subject.Subscribe(new ActionObserver<int>(_ => { }, () => count++));

        subject.OnCompleted();
        subject.OnCompleted();

        count.Should().Be(1);
    }

    [Fact]
    public void Subscribe_AfterCompleted_ImmediatelyCallsOnCompleted()
    {
        var subject = new SimpleSubject<int>();
        subject.OnCompleted();
        var completed = false;

        subject.Subscribe(new ActionObserver<int>(_ => { }, () => completed = true));

        completed.Should().BeTrue();
    }

    // -------------------------------------------------------------------------
    // OnError
    // -------------------------------------------------------------------------

    [Fact]
    public void OnError_NotifiesObserverWithException()
    {
        var subject = new SimpleSubject<int>();
        Exception? received = null;
        subject.Subscribe(new ActionObserver<int>(_ => { }, null, ex => received = ex));

        var expected = new InvalidOperationException("boom");
        subject.OnError(expected);

        received.Should().BeSameAs(expected);
    }

    [Fact]
    public void OnError_IsSilentAfterAlreadyCompleted()
    {
        var subject = new SimpleSubject<int>();
        var errors = new List<Exception>();
        subject.Subscribe(new ActionObserver<int>(_ => { }, null, errors.Add));
        subject.OnCompleted();

        subject.OnError(new Exception("late"));

        errors.Should().BeEmpty();
    }

    [Fact]
    public void Subscribe_AfterError_ImmediatelyCallsOnError()
    {
        var subject = new SimpleSubject<int>();
        var err = new InvalidOperationException("pre-error");
        subject.OnError(err);
        Exception? received = null;

        subject.Subscribe(new ActionObserver<int>(_ => { }, null, ex => received = ex));

        received.Should().BeSameAs(err);
    }

    // -------------------------------------------------------------------------
    // Dispose (= OnCompleted)
    // -------------------------------------------------------------------------

    [Fact]
    public void Dispose_SilencesSubject_NoExceptionThrown()
    {
        var subject = new SimpleSubject<int>();
        var received = new List<int>();
        subject.Subscribe(new ActionObserver<int>(received.Add));

        subject.Dispose();
        var act = () => subject.OnNext(1);

        act.Should().NotThrow();
        received.Should().BeEmpty();
    }

    // -------------------------------------------------------------------------
    // Subscription double-dispose guard
    // -------------------------------------------------------------------------

    [Fact]
    public void Subscription_DoubleDispose_DoesNotThrow()
    {
        var subject = new SimpleSubject<int>();
        var sub = subject.Subscribe(new ActionObserver<int>(_ => { }));

        sub.Dispose();
        var act = () => sub.Dispose();

        act.Should().NotThrow();
    }

    // -------------------------------------------------------------------------
    // NullDisposable — returned when subscribing to an already-completed subject
    // -------------------------------------------------------------------------

    [Fact]
    public void Subscribe_AfterCompleted_ReturnsDisposableThatDoesNotThrow()
    {
        var subject = new SimpleSubject<int>();
        subject.OnCompleted();

        var sub = subject.Subscribe(new ActionObserver<int>(_ => { }, () => { }));
        var act = () => sub.Dispose();

        act.Should().NotThrow();
    }

    [Fact]
    public void Subscribe_AfterError_ReturnsDisposableThatDoesNotThrow()
    {
        var subject = new SimpleSubject<int>();
        subject.OnError(new InvalidOperationException("pre"));

        var sub = subject.Subscribe(new ActionObserver<int>(_ => { }, null, _ => { }));
        var act = () => sub.Dispose();

        act.Should().NotThrow();
    }

    // -------------------------------------------------------------------------
    // Helper observer
    // -------------------------------------------------------------------------

    private sealed class ActionObserver<T>(
        Action<T> onNext,
        Action? onCompleted = null,
        Action<Exception>? onError = null) : IObserver<T>
    {
        public void OnNext(T value) => onNext(value);
        public void OnCompleted() => onCompleted?.Invoke();
        public void OnError(Exception error) => onError?.Invoke(error);
    }
}

[Trait("Category", "Unit")]
public sealed class ObservableExtensionsTests
{
    [Fact]
    public void Subscribe_DeliversValues_WhenActionProvided()
    {
        var subject = new SimpleSubject<int>();
        var received = new List<int>();

        subject.Subscribe(received.Add);
        subject.OnNext(7);
        subject.OnNext(13);

        received.Should().Equal(7, 13);
    }

    [Fact]
    public void Subscribe_StopsDelivery_AfterDispose()
    {
        var subject = new SimpleSubject<int>();
        var received = new List<int>();
        var sub = subject.Subscribe(received.Add);

        subject.OnNext(1);
        sub.Dispose();
        subject.OnNext(2);

        received.Should().ContainSingle().Which.Should().Be(1);
    }

    [Fact]
    public void Subscribe_ThrowsArgumentNullException_WhenObservableIsNull()
    {
        IObservable<int> observable = null!;

        var act = () => observable.Subscribe(_ => { });

        act.Should().Throw<ArgumentNullException>();
    }

    [Fact]
    public void Subscribe_ThrowsArgumentNullException_WhenActionIsNull()
    {
        var subject = new SimpleSubject<int>();

        var act = () => subject.Subscribe((Action<int>)null!);

        act.Should().Throw<ArgumentNullException>();
    }

    [Fact]
    public void Subscribe_DoesNotThrow_WhenSubjectCompletesOrErrors()
    {
        var subject = new SimpleSubject<int>();
        subject.Subscribe(_ => { });

        var act = () =>
        {
            subject.OnCompleted();
            subject.OnError(new Exception("ignored"));
        };

        act.Should().NotThrow();
    }
}
