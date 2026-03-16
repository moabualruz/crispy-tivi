---
name: make-testable
description: Refactor production code to be testable without changing behavior. Use when a class has untestable branches due to hardcoded paths, static calls, or internal visibility. Patterns include injectable constructor overloads, InternalsVisibleTo, replacing FindControl with AXAML-generated fields.
---

## Make Testable

### Rule Zero

Production behavior MUST be unchanged after refactoring. The parameterless constructor is always preserved for the DI container. No test-only hacks in production code.

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

**CRITICAL:** The control constructor MUST call `InitializeComponent()` — without it, all `x:Name` fields are null:

```csharp
public MyView()
{
    InitializeComponent();  // MUST be present
}
```

### Pattern 4 — New HttpClient Inside Method

**Problem:** `new HttpClient()` inside a method — can't inject a fake.

**Fix:** Inject `HttpClient` or `IHttpClientFactory`:

```csharp
internal XtreamParser(HttpClient httpClient) { _http = httpClient; }
public XtreamParser() : this(new HttpClient()) { }
```

### Pattern 5 — Pointer/Drag Logic Extraction

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

### Pattern 6 — Internal Visibility for Tests

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
