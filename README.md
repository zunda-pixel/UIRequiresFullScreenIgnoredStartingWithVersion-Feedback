# TestFullScreen

A minimal iPad app for investigating how **`UIRequiresFullScreen`** and
**`UIRequiresFullScreenIgnoredStartingWithVersion`** behave on iOS/iPadOS 26–27.

Full write-up (for Feedback Assistant): **[FEEDBACK_REPORT.md](FEEDBACK_REPORT.md)**.

## Conclusion (short)
Per [WWDC26 Session 278 "Modernize your UIKit app"](https://developer.apple.com/videos/play/wwdc2026/278/), starting in iOS 27 `UIRequiresFullScreen` is **honored** and no longer opts the app out of resizing — instead it enables **discrete resizing** (the scene snaps between whole *screen configurations* instead of resizing continuously). This project confirms that, and finds the migration key has no effect:

- **`UIRequiresFullScreen = true` → discrete resizing; `false` → continuous.** Verified on iPadOS 27 with a controlled slow-drag: `false` produced 60+ finely-spaced sizes (~1–4 pt steps); `true` snapped between only a few configurations.
- **`UIRequiresFullScreenIgnoredStartingWithVersion` has no observable effect.** On iPadOS 27, a threshold of `26.0` (≤ the running OS, so the key should be *ignored* → continuous) still produced discrete resizing — same as `27.0`.
- **iPadOS 26.5 (pre-27):** older behavior — a restricted-orientation app is locked (Portrait fills the screen; Landscape is letterboxed), an all-orientations app resizes freely; the threshold value made no difference.

| OS | UIRequiresFullScreen | Threshold | Resizing |
|---|---|---|---|
| 27.0 | false | — | continuous (60+ sizes) |
| 27.0 | true | 27.0 / 26.0 | **discrete** (few configs) |
| 26.5 | true | 99.0 / 26.0 | orientation-dependent lock/letterbox (all-orient: free) |

## Test harness
- Two build configurations, **`Locked`** and **`Ignored`**, differing only by `FULLSCREEN_IGNORE_VERSION` (`99.0` vs `27.0`), injected into `Info.plist` (`UIRequiresFullScreenIgnoredStartingWithVersion = $(FULLSCREEN_IGNORE_VERSION)`); switch via the matching schemes.
- [`Info.plist`](Info.plist) is a manual plist (`GENERATE_INFOPLIST_FILE = NO`) so the two keys and `ConfigurationName = $(CONFIGURATION)` are set explicitly.
- [`TestFullScreen/ContentView.swift`](TestFullScreen/ContentView.swift) is a diagnostic view: it reads the keys back and logs every distinct window size (`keyWindow.bounds`) so you can drag-resize and see whether the sizes form a smooth ramp (**continuous**) or a few chunky configurations (**discrete**).
- Other threshold / orientation / `false` variants were produced by PlistBuddy-patching the built `.app` (no project-file edits).

## How to reproduce
1. Build `Locked`/`Ignored` (or a patched variant) and run on an **iPad simulator in "Windowed Apps" mode**.
2. Tap **Reset**, then slowly drag a window corner across a wide range.
3. Read **"Resizing looks"** and the **Observed sizes** list: many finely-spaced sizes = continuous (requirement ignored); a few configurations = discrete (`UIRequiresFullScreen` honored).

## Screenshots
See [`screenshots/`](screenshots/). Key evidence: `27_true_thr26_discrete.png` (iPadOS 27, `true`+threshold 26.0 → still discrete) and the iPadOS 26.5 `265_*` set (orientation-dependent lock/letterbox).
