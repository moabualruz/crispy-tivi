---
name: infra-test-patterns
description: Infrastructure.Tests conventions for CrispyTivi. Use when writing tests in Crispy.Infrastructure.Tests. Enforces correct fake/mock patterns, DB factory usage, and avoids common dependency issues.
---

## Infrastructure Test Patterns

### No NSubstitute

**NEVER use NSubstitute in `Crispy.Infrastructure.Tests`** — it is NOT available (NuGet restore is broken and it was never added to this project).

Use hand-written fakes from `tests/Crispy.Infrastructure.Tests/Helpers/`.

```csharp
// WRONG
var player = Substitute.For<IPlayerService>();

// CORRECT
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

### FakePlayerService Warning — Multiple Duplicates Exist

There are MULTIPLE `FakePlayerService` classes in different namespaces:
- `Crispy.Infrastructure.Tests.Helpers.FakePlayerService` — **canonical, use this**
- Local fakes in Equalizer, Multiview, SleepTimer test files — kept for legacy isolation

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

### No Relational Extension Methods

`Microsoft.EntityFrameworkCore.Relational` is NOT available in Infrastructure.Tests.

```csharp
// FORBIDDEN
await db.Database.ExecuteSqlRawAsync("DELETE FROM Channels");
var conn = db.Database.GetDbConnection();

// CORRECT — use the raw SQLite connection from the factory
using var cmd = factory.Connection.CreateCommand();
cmd.CommandText = "DELETE FROM Channels";
await cmd.ExecuteNonQueryAsync();
```

### Test Attributes

```csharp
[Trait("Category", "Unit")]    // every test class
[Trait("Category", "Integration")]  // for integration tests with real DB
```

Use `[Fact]` and `[Theory]` only. Never `[AvaloniaFact]` in Infrastructure.Tests — no Avalonia dependency here.

### Cobertura Artifacts — Do Not Chase These

These classes show ~60% in Cobertura but are well-tested. The low reading is a measurement artifact from compiler-generated async state machine classes:

- `XmltvParser`
- `StalkerClient`
- `CredentialEncryption`
- `MultiviewService`
- `SleepTimerService`

The actual tested state-machine paths are higher than reported. Do not add trivial tests to inflate these numbers.

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
