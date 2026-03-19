# Test Fixtures — Override Pattern

## Files

| File | Tracked | Purpose |
|------|---------|---------|
| `test-settings.json` | Yes | Stub sources, profiles, app settings |
| `test-settings.local.json` | **No** | Real credentials/sources (overrides stubs) |
| `test-seed.json` | Yes | Stub channels, EPG, movies, series |
| `test-seed.local.json` | **No** | Real data (overrides stubs) |

## How It Works

1. Tests always load the base `.json` file first
2. If a `.local.json` file exists, its top-level fields override the base
3. `.local` files are gitignored — never committed
4. Tests MUST pass with stub data alone (no `.local` required)

## Creating a `.local` Override

Copy the base file and replace values with real data:

```bash
cp test-settings.json test-settings.local.json
# Edit test-settings.local.json with real source credentials
```

Only include fields you want to override — unspecified fields keep base values.
