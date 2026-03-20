---
name: crispy-infra-test-patterns
description: Follow correct testing conventions for Crispy.Infrastructure.Tests. Use whenever writing Infrastructure tests — especially repository tests, service tests, or anything needing IPlayerService mocks. Prevents the most common failures: NSubstitute not available, System.Reactive missing, ExecuteSqlRawAsync not found, duplicate FakePlayerService shadowing.
---

## Infrastructure Test Patterns

### No NSubstitute, No Moq, No System.Reactive

**NEVER use NSubstitute or Moq in `Crispy.Infrastructure.Tests`** — they are NOT available. NuGet restore is broken and these packages were never added to this project.

**NEVER use `System.Reactive` types** (`Subject<T>`, `Observable.*`) — not referenced here either.

Use hand-written fakes from `tests/Crispy.Infrastructure.Tests/Helpers/`.

```csharp
// WRONG — won't compile
var player = Substitute.For<IPlayerService>();
var subject = new Subject<PlayerState>();

// CORRECT
using Crispy.Infrastructure.Tests.Helpers;
var player = new FakePlayerService();
```

### Available Helpers

| Helper | Location | Use For |
|---|---|---|
| `FakePlayerService` | `Helpers/FakePlayerService.cs` | IPlayerService stub with `LastPlayRequest`, `PlayCallCount` |
| `NullDisposable` | `Helpers/NullDisposable.cs` | IDisposable stubs that do nothing |
| `NeverObservable<T>` | `Helpers/NullObservable.cs` | IObservable stubs that never emit |
| `TestDbContextFactory` | `Helpers/TestDbContextFactory.cs` | EF Core repos using shared SQLite in-memory |
| `TestEpgDbContextFactory` | `Helpers/TestEpgDbContextFactory.cs` | EPG repo tests |

### FakePlayerService — Canonical Import Warning

There are MULTIPLE `FakePlayerService` classes in different namespaces:
- `Crispy.Infrastructure.Tests.Helpers.FakePlayerService` — **canonical, always use this**
- Local fakes in Equalizer, Multiview, SleepTimer test files — legacy, kept for isolation

**Always add the explicit using to avoid shadowing:**

```csharp
using Crispy.Infrastructure.Tests.Helpers;  // canonical FakePlayerService lives here
```

For any NEW test, always use the one in `Helpers/`. Do not create another duplicate.

### Logging

```csharp
using Microsoft.Extensions.Logging.Abstractions;
var logger = NullLogger<MyService>.Instance;
```

`Microsoft.Extensions.Logging.Abstractions` IS available. Use it everywhere. Never pass `null` for a logger parameter.

### Database — TestDbContextFactory

```csharp
await using var factory = new TestDbContextFactory();
await using var db = factory.CreateDbContext();
var repo = new ChannelRepository(db);
```

The factory creates a shared in-memory SQLite connection. All contexts from the same factory share the same connection — tests are isolated per factory instance.

For EPG:
```csharp
await using var factory = new TestEpgDbContextFactory();
```

#### Raw SQLite Access via factory.Connection

`TestDbContextFactory` exposes a `Connection` property for raw SQL when needed:

```csharp
using var cmd = factory.Connection.CreateCommand();
cmd.CommandText = "SELECT COUNT(*) FROM Channels";
var count = (long)await cmd.ExecuteScalarAsync();
```

### No Relational Extension Methods

`Microsoft.EntityFrameworkCore.Relational` is NOT available in Infrastructure.Tests. These methods come from the relational package and will not compile.

```csharp
// FORBIDDEN — package not available
await db.Database.ExecuteSqlRawAsync("DELETE FROM Channels");
var conn = db.Database.GetDbConnection();

// CORRECT — use the raw connection from the factory
using var cmd = factory.Connection.CreateCommand();
cmd.CommandText = "DELETE FROM Channels";
await cmd.ExecuteNonQueryAsync();
```

### IAsyncLifetime — Async Setup and Teardown

When a test class needs async setup or teardown (e.g., seeding the DB before all tests), implement `IAsyncLifetime`:

```csharp
public class ChannelRepositoryTests : IAsyncLifetime
{
    private TestDbContextFactory _factory = null!;

    public async Task InitializeAsync()
    {
        _factory = new TestDbContextFactory();
        await using var db = _factory.CreateDbContext();
        db.Channels.Add(new Channel { ... });
        await db.SaveChangesAsync();
    }

    public async Task DisposeAsync()
    {
        await _factory.DisposeAsync();
    }

    [Fact]
    public async Task GetBySourceIdAsync_ReturnsOnlyMatchingChannels_WhenMultipleSourcesExist()
    {
        await using var db = _factory.CreateDbContext();
        var repo = new ChannelRepository(db);
        // ...
    }
}
```

### Test Attributes

```csharp
[Trait("Category", "Unit")]    // every test class
[Trait("Category", "Integration")]  // for integration tests with real DB
```

Use `[Fact]` and `[Theory]` only. Never `[AvaloniaFact]` in Infrastructure.Tests — no Avalonia dependency here.

### Observable Stubs

```csharp
// For a service property returning IObservable<T> that you never need to emit from:
var svc = new FakePlayerService();
// FakePlayerService.StateChanged returns NeverObservable<PlayerState> internally
```

When writing a custom fake that needs `IObservable<T>`:
```csharp
public IObservable<PlayerState> StateChanged => NeverObservable<PlayerState>.Instance;
```

### Cobertura Artifacts — Do Not Chase These

These classes show ~60% in Cobertura but are well-tested. The low reading is a measurement artifact from compiler-generated async state machine classes:

- `XmltvParser`
- `StalkerClient`
- `CredentialEncryption`
- `MultiviewService`
- `SleepTimerService`

The actual tested state-machine paths are higher than reported. Do not add trivial tests to inflate these numbers.

### Test Naming

```csharp
[Trait("Category", "Unit")]
public class ChannelRepositoryTests
{
    [Fact]
    public async Task GetBySourceIdAsync_ReturnsOnlyMatchingChannels_WhenMultipleSourcesExist()
    // Pattern: Method_ExpectedResult_WhenCondition
}
```

### File Mirroring

```
src/Crispy.Infrastructure/Repositories/ChannelRepository.cs
→ tests/Crispy.Infrastructure.Tests/Repositories/ChannelRepositoryTests.cs

src/Crispy.Infrastructure/Services/XtreamParser.cs
→ tests/Crispy.Infrastructure.Tests/Services/XtreamParserTests.cs
```
