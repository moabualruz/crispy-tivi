#!/usr/bin/env python3
"""Generate CrispyTivi Widgetbook coverage matrix from Dart widget sources."""

from __future__ import annotations

import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "design/docs/widgetbook-coverage.md"
WIDGETBOOK = ROOT / "app/flutter/lib/widgetbook"

SOURCE_PATTERNS = [
    "app/flutter/lib/core/widgets/*.dart",
    "app/flutter/lib/core/navigation/*.dart",
    "app/flutter/lib/features/**/presentation/widgets/*.dart",
    "app/flutter/lib/features/**/presentation/screens/*.dart",
]

CLASS_RE = re.compile(
    r"^class\s+(?P<name>[_A-Za-z][\w]*)(?:<[^>{}]+>)?\s+extends\s+(?P<extends>[^\{]+?)\s*\{",
    re.MULTILINE,
)
USE_CASE_RE = re.compile(
    r"@widgetbook\.UseCase\(.*?type:\s*(?P<type>[A-Za-z_]\w*)\s*,.*?path:\s*'(?P<path>[^']+)'",
    re.DOTALL,
)

WIDGET_BASES = (
    "Widget",
    "StatefulWidget",
    "StatelessWidget",
    "ConsumerWidget",
    "ConsumerStatefulWidget",
    "HookConsumerWidget",
    "SearchDelegate",
    "CustomPainter",
    "TraversalPolicy",
)

FEATURE_LABELS = {
    "iptv": "Live TV",
    "epg": "EPG",
    "dvr": "DVR",
    "vod": "VOD",
    "home": "Home",
    "favorites": "Favorites",
    "player": "Player",
    "multiview": "Multiview",
    "settings": "Settings",
    "profiles": "Profiles",
    "search": "Search",
    "cloud_sync": "Cloud Sync",
    "casting": "Casting",
    "onboarding": "Onboarding",
    "notifications": "Notifications",
    "recommendations": "Recommendations",
    "voice_search": "Voice Search",
    "media_servers": "Media Servers",
}


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def direct_use_cases() -> dict[str, str]:
    direct: dict[str, str] = {}
    for path in sorted(WIDGETBOOK.glob("*.dart")):
        text = path.read_text()
        for match in USE_CASE_RE.finditer(text):
            direct[match.group("type")] = match.group("path")
    return direct


def is_widgetish(base: str) -> bool:
    return any(token in base for token in WIDGET_BASES)


def feature_name(path: str) -> str:
    parts = path.split("/")
    if "features" in parts:
        feature = parts[parts.index("features") + 1]
        return FEATURE_LABELS.get(feature, feature.replace("_", " ").title())
    if "navigation" in parts:
        return "Navigation"
    return "Core widgets"


def decision_for(path: str, name: str, base: str, direct: dict[str, str]) -> tuple[str, str, str]:
    feature = feature_name(path)
    is_private = name.startswith("_")
    is_screen = "/presentation/screens/" in path or path.endswith("screen.dart")
    is_provider_bound = any(
        marker in base
        for marker in ("ConsumerWidget", "ConsumerStatefulWidget", "HookConsumerWidget")
    )
    is_delegate_or_painter = "SearchDelegate" in base or "CustomPainter" in base or "TraversalPolicy" in base

    if is_private:
        return (
            "private-helper",
            "parent",
            "Private implementation helper covered by owning public widget or deferred parent fixture.",
        )

    if name in direct:
        return (
            "direct-use-case",
            direct[name],
            "Annotated direct Widgetbook use case exists with a Penpot design link.",
        )

    if path.startswith("app/flutter/lib/core/navigation/"):
        return (
            "deferred-provider-fixture" if is_provider_bound or name == "AppShell" else "family-use-case",
            "[Core navigation]/Navigation shell",
            "Navigation shell depends on router, window, playback, or provider state; needs stable shell fixture before direct coverage.",
        )

    if path.startswith("app/flutter/lib/core/widgets/"):
        return (
            "family-use-case",
            "[Core widgets]/Primitive family",
            "Core primitive is represented by related annotated fixtures or needs a tight primitive family fixture before direct promotion.",
        )

    if is_delegate_or_painter:
        return (
            "family-use-case",
            f"[Feature widgets]/{feature} family",
            "Non-widget visual/control helper is covered by parent/family fixture unless promoted to direct catalog coverage.",
        )

    if is_screen or is_provider_bound:
        return (
            "deferred-provider-fixture",
            f"[Feature fixtures]/{feature} provider harness",
            f"Deferred until {feature} providers, routes, platform services, or controllers have stable Widgetbook overrides.",
        )

    return (
        "family-use-case",
        f"[Feature widgets]/{feature} family",
        f"Covered by {feature} family fixture or pending a tighter direct fixture when stable sample data exists.",
    )


def collect_rows() -> list[tuple[str, str, str, str, str, str]]:
    direct = direct_use_cases()
    files: set[Path] = set()
    for pattern in SOURCE_PATTERNS:
        files.update(ROOT.glob(pattern))

    rows: list[tuple[str, str, str, str, str, str]] = []
    for path in sorted(files):
        text = path.read_text(errors="ignore")
        for match in CLASS_RE.finditer(text):
            name = match.group("name")
            base = " ".join(match.group("extends").split())
            if not is_widgetish(base):
                continue
            path_rel = rel(path)
            decision, use_case, reason = decision_for(path_rel, name, base, direct)
            rows.append((path_rel, name, base, decision, use_case, reason))
    return rows


def main() -> None:
    rows = collect_rows()
    counts = Counter(row[3] for row in rows)
    lines = [
        "# Widgetbook Coverage Matrix",
        "",
        f"Total scanned UI classes: {len(rows)}",
        "",
        "## Summary",
        "",
    ]
    for decision in sorted(counts):
        lines.append(f"- `{decision}`: {counts[decision]}")
    lines.extend(
        [
            "",
            "## Matrix",
            "",
            "| File | Widget | Extends | Decision | Use case / family | Reason |",
            "| --- | --- | --- | --- | --- | --- |",
        ]
    )
    for path, name, base, decision, use_case, reason in rows:
        lines.append(
            f"| `{path}` | `{name}` | `{base}` | `{decision}` | `{use_case}` | {reason} |"
        )
    OUT.write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
