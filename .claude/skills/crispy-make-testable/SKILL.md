---
name: crispy-make-testable
description: Refactor CrispyTivi production code to be testable without changing its public API. Use when tests can't reach code paths due to hardcoded dependencies, static calls, missing InitializeComponent, FindControl usage, or untestable code-behind logic. Patterns: injectable constructors, InternalsVisibleTo, AXAML-generated fields, internal method extraction.
---

## Make Testable

### Rule Zero

Production behavior MUST be unchanged after refactoring. The parameterless constructor is always preserved for the DI container. No test-only hacks in production code.

Without this discipline, the alternative is worse: tests that break production API, `if (testing)` guards in production code, or skipped tests hiding real bugs. Preserving the parameterless constructor keeps DI wiring untouched while giving tests a seam.

### Pattern 1 — Hardcoded Path Injection

**Problem:** `Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData)` baked into constructor.

**Fix:** Add overload accepting the path:

```csharp
// Production constructor (preserved)
public CredentialEncryption() : this(GetDefaultKeyPath()) { }

// Injectable constructor for tests
internal CredentialEncryption(string keyPath) { _keyPath = keyPath; }

private static string GetDefaultKeyPath() =>
    Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "crispy", "key");
```

Add `InternalsVisibleTo` to the csproj so tests can call internal constructors:
```xml
<ItemGroup>
  <InternalsVisibleTo Include="Crispy.Infrastructure.Tests" />
</ItemGroup>
```

### Pattern 2 — Static Platform Call Injection

**Problem:** `OperatingSystem.IsWindows()` inside method — can't change at test time.

**Fix:** Inject a delegate or interface:

```csharp
internal FeatureFlag(Func<bool> isWindowsProvider) { _isWindows = isWindowsProvider; }
public FeatureFlag() : this(OperatingSystem.IsWindows) { }
```

### Pattern 3 — FindControl → AXAML-Generated Fields

**Problem:** `this.FindControl<Button>("PlayButton")` returns null in headless tests.

**Fix:** Use AXAML-generated fields (Avalonia generates them from `x:Name`):

```xml
<!-- AXAML: ensure x:Name is set -->
<Button x:Name="PlayButton" ... />
```

```csharp
// Code-behind: use generated field directly
PlayButton.Click += ...;
// NOT: this.FindControl<Button>("PlayButton")
```

**CRITICAL — InitializeComponent():** The control constructor MUST call `InitializeComponent()` — without it, all `x:Name` fields are null:

```csharp
public MyView()
{
    InitializeComponent();  // MUST be present — generates x:Name fields
}
```

### Pattern 4 — OnAttachedToVisualTree Access

**Problem:** Code-behind accesses `x:Name` fields or subscribes to events in `OnAttachedToVisualTree`, but tests instantiate with `new FooView()` — `OnAttachedToVisualTree` never fires.

**Fix:** Always attach via `HeadlessTestHelpers.CreateWindow<T>()` to trigger the full lifecycle:

```csharp
// WRONG — OnAttachedToVisualTree never fires
var view = new FooView();

// CORRECT — full lifecycle fires including OnAttachedToVisualTree
var window = HeadlessTestHelpers.CreateWindow<FooView>(vm);
// x:Name fields are now live and subscriptions are registered
```

If logic in `OnAttachedToVisualTree` still can't be reached, extract it to an `internal` method:

```csharp
protected override void OnAttachedToVisualTree(VisualTreeAttachmentEventArgs e)
{
    base.OnAttachedToVisualTree(e);
    SetupSubscriptions();
}

internal void SetupSubscriptions() { ... }  // testable directly
```

### Pattern 5 — New HttpClient Inside Method

**Problem:** `new HttpClient()` inside a method — can't inject a fake.

**Fix:** Inject `HttpClient` or `IHttpClientFactory`:

```csharp
internal XtreamParser(HttpClient httpClient) { _http = httpClient; }
public XtreamParser() : this(new HttpClient()) { }
```

### Pattern 6 — Pointer/Drag Logic Extraction

**Problem:** `e.GetPosition(parent)` returns `(0,0)` in headless — drag logic untestable.

**Fix:** Extract to internal method accepting coordinates directly:

```csharp
internal void HandleDrag(double deltaX, double deltaY) { ... }

// Event handler calls extracted method
private void OnPointerMoved(object? sender, PointerEventArgs e)
{
    var pos = e.GetPosition(this);
    HandleDrag(pos.X - _lastX, pos.Y - _lastY);
}
```

Tests call `HandleDrag()` directly with known values.

### Pattern 7 — Internal Visibility for Tests

Add to the production project's `.csproj`:

```xml
<ItemGroup>
  <InternalsVisibleTo Include="Crispy.UI.Tests" />
  <InternalsVisibleTo Include="Crispy.Infrastructure.Tests" />
</ItemGroup>
```

### Verification Checklist

After applying any pattern:
- [ ] Parameterless constructor still works (DI container unaffected)
- [ ] `dotnet build --no-restore -warnaserror` passes
- [ ] Existing tests still pass
- [ ] New tests can now reach previously unreachable branches
- [ ] No test-only code paths in production (no `if (testing)` guards)
