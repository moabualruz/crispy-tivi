---
name: headless-ui-test
description: Write Avalonia headless UI tests correctly for CrispyTivi. Use when writing tests for Views or Controls with code-behind logic. Enforces correct patterns and prevents common mistakes with TestSubject, NSubstitute, HeadlessTestHelpers, and AXAML-generated fields.
---

## Headless UI Test Patterns

### Always Use AvaloniaFact

```csharp
[AvaloniaFact]
public async Task MyView_DoesX_WhenY()
```

Never `[Fact]` for headless tests. ViewModels that use `Dispatcher.UIThread` require `[AvaloniaFact]` — `[Fact]` causes silent failures when state updates are posted to the dispatcher but never processed.

### Window Creation

Use `HeadlessTestHelpers.CreateWindow<TView>(vm)` from `tests/Crispy.UI.Tests/Helpers/`:

```csharp
var vm = new FooViewModel(mockService);
var window = HeadlessTestHelpers.CreateWindow<FooView>(vm);
```

The helper attaches the view to a headless window, sets DataContext, and runs InitializeComponent.

### TestSubject — CRITICAL

Use `TestSubject<T>` from `Crispy.UI.Tests.Helpers` namespace.

**NEVER** use `System.Reactive.Subjects.Subject<T>` — `System.Reactive` is NOT referenced in `Crispy.UI.Tests`.

```csharp
// Correct
using Crispy.UI.Tests.Helpers;
var stateSubject = new TestSubject<PlayerState>();

// WRONG — won't compile
using System.Reactive.Subjects;
var stateSubject = new Subject<PlayerState>();
```

### Mocking with NSubstitute

NSubstitute IS available in `Crispy.UI.Tests`. Use it for all interface mocks.

#### PlayerViewModel Mock Setup

`PlayerViewModel` requires these mocked services:

```csharp
var playerService = Substitute.For<IPlayerService>();
var stateSubject = new TestSubject<PlayerState>();
playerService.State.Returns(PlayerState.Idle);
playerService.StateChanged.Returns(stateSubject);
playerService.AudioSamples.Returns(Observable.Never<float[]>());
playerService.AudioTracks.Returns(Observable.Never<IReadOnlyList<AudioTrack>>());
playerService.SubtitleTracks.Returns(Observable.Never<IReadOnlyList<SubtitleTrack>>());

var timeshiftService = Substitute.For<ITimeshiftService>();
var timeshiftSubject = new TestSubject<TimeshiftState>();
timeshiftService.State.Returns(TimeshiftState.Inactive);
timeshiftService.StateChanged.Returns(timeshiftSubject);

var sleepService = Substitute.For<ISleepTimerService>();
var sleepSubject = new TestSubject<TimeSpan?>();
sleepService.Remaining.Returns((TimeSpan?)null);
sleepService.RemainingChanged.Returns(sleepSubject);

var vm = new PlayerViewModel(playerService, timeshiftService, sleepService);
```

### Pushing State Reactively

Push state AFTER DataContext is set:

```csharp
var window = HeadlessTestHelpers.CreateWindow<PlayerView>(vm);
// Now push state — VM properties update reactively
stateSubject.OnNext(new PlayerState { IsPlaying = true });
// Assert
vm.IsPlaying.Should().BeTrue();
```

### AXAML-Generated Fields

Never use `FindControl<T>(name)` in production code-behind. Use generated fields.

If a field is null in tests: the constructor is missing `InitializeComponent()`.

```csharp
public MyView()
{
    InitializeComponent();  // MANDATORY — without this, x:Name fields are null
}
```

### Pointer / Drag Testing

`e.GetPosition(parent)` returns `(0,0)` in headless — don't test through pointer events.
Extract drag logic to `internal` methods and call directly:

```csharp
// In test
view.HandleDrag(50.0, 0.0);
view.Position.X.Should().Be(50.0);
```

### Keyboard Testing

```csharp
window.KeyPressQwerty(Key.Space);
```

### Never Short-Circuit

If a control can't be found or a property is null:
1. Check `InitializeComponent()` is called in constructor
2. Check window has a DataContext
3. Check the view is attached to the window (use `CreateWindow`, not `new FooView()`)
4. Fix the setup — do NOT weaken or skip the assertion

### Test Naming

```csharp
[Trait("Category", "UI")]
public class FooViewTests
{
    [AvaloniaFact]
    public async Task Play_SetsIsPlayingTrue_WhenStateChangesToPlaying()
    // Pattern: Action_ExpectedResult_WhenCondition
}
```

### File Mirroring

```
src/Crispy.UI/Views/PlayerView.axaml.cs
→ tests/Crispy.UI.Tests/Views/PlayerViewTests.cs

src/Crispy.UI/ViewModels/PlayerViewModel.cs
→ tests/Crispy.UI.Tests/ViewModels/PlayerViewModelTests.cs
```
