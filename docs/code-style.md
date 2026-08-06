# Code Style

> Read this before writing Swift here (conventions + target boundaries).

Formatting is enforced by `swift format` against `.swift-format`
(4-space indent, 100-col lines, ordered imports, public docs required). Run
`make format` to auto-fix and `make lint` to check. Do not hand-argue style —
let the formatter decide.

## One real snippet (the house style)

```swift
/// The two listening modes the app toggles between.
public enum Mode: String, CaseIterable, Sendable {
    case jazz
    case phonk

    /// The opposite mode. A single toggle action flips between the two.
    public var toggled: Mode {
        switch self {
        case .jazz: return .phonk
        case .phonk: return .jazz
        }
    }
}
```

Conventions shown above and expected throughout:
- **Public API is documented.** `swift format` lints missing doc comments on
  public declarations (`AllPublicDeclarationsHaveDocumentation`). Non-public
  helpers need docs only where intent isn't obvious.
- `lowerCamelCase` members, `UpperCamelCase` types. No abbreviations in names
  except well-known ones (URL, JS, YTM).
- Prefer value types (`struct`/`enum`) and `Sendable` where it's free.

## Target boundaries (load-bearing, not cosmetic)
- `PhonkJazzCore`: **pure Swift only.** No `import AppKit`, no `import WebKit`.
  This keeps logic testable without a display. Enforce:

      grep -rn "import AppKit\|import WebKit" Sources/PhonkJazzCore/ && exit 1 || echo OK

  A hit means: GUI/WebKit code leaked into Core. Move it to `Sources/PhonkJazz`
  and expose only the pure decision (a `Mode`, a URL, a config value) to the app.
- `PhonkJazz` (executable): AppKit/WebKit live here. Keep it thin — delegate
  decisions to Core so they stay covered by tests.

## MainActor
AppKit UI (status item, WebView, hotkey callbacks) runs on the main thread; mark
UI-touching types `@MainActor`. Core types are actor-agnostic and `Sendable`.
