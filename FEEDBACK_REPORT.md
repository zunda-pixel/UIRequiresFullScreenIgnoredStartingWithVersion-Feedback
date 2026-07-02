# UIRequiresFullScreenIgnoredStartingWithVersion has no observable effect on iPadOS 27 (does not re-enable continuous resizing)

## Summary
On iOS/iPadOS 27, `UIRequiresFullScreen = true` is **honored** and enables **discrete resizing** — as documented at WWDC26 ("Modernize your UIKit app", Session 278): the app is not opted out of resizing; instead, changing the scene size transitions it between whole *screen configurations* rather than resizing continuously.

This project confirms that behavior with a controlled test, and reports one problem: **`UIRequiresFullScreenIgnoredStartingWithVersion` has no observable effect.** Setting it to a version at or below the running OS (which per the documentation should make the system *ignore* `UIRequiresFullScreen`, i.e. restore continuous resizing) does **not** do so — resizing stays discrete.

Controlled measurement on iPadOS 27.0 (identical slow-drag method):
- `UIRequiresFullScreen = false` → **continuous** resizing (60+ finely-spaced sizes, ~1–4 pt increments).
- `UIRequiresFullScreen = true`, threshold `27.0` → **discrete** (snaps between ~3 configurations).
- `UIRequiresFullScreen = true`, threshold `26.0` (**below** the running OS) → **discrete** (5 sizes, large gaps) — expected to be *ignored/continuous*, but was not.

## Environment
- Xcode 27.0 (27A5209h), macOS 27.0
- iPadOS 27.0 simulator — iPad Pro 11-inch (M5), 24A5370g, "Windowed Apps" mode
- App: SwiftUI lifecycle; deployment target iOS 26.0; device family iPhone/iPad.

## Reference
- WWDC26 Session 278 "Modernize your UIKit app": "UIRequiresFullscreen is honored on iPhone in resizable environments starting in iOS 27. Its behavior has also been updated and no longer opts your app fully out of resizing. Instead, it enables discrete resizing … the system transitions the scene to a new screen configuration matching that size."
- `UIRequiresFullScreenIgnoredStartingWithVersion`: "The system ignores the key starting in the version you specify and in later versions of iOS. The system only uses this key when your information property list also contains `UIRequiresFullScreen` with a value of `true`."

## Methodology
The correct signal is **continuous vs discrete** resizing, not aspect ratio. The diagnostic view records every distinct window size (`keyWindow.bounds`; `UIScreen` is virtualized per-window on iPadOS 26+) as the window is slowly drag-resized across a wide range. Continuous resizing produces many finely-spaced sizes; discrete resizing produces a few configurations separated by large jumps. A `UIRequiresFullScreen = false` build is used as the control.

## Results — iPadOS 27.0 (Windowed mode)
| Config | UIRequiresFullScreen | Threshold | Distinct sizes over a slow drag | Result |
|---|---|---|---|---|
| Control | false | 27.0 | 60+ (e.g. 759×898, 758×897, 757×896, 755×894 … 1–4 pt steps) | **CONTINUOUS** |
| Ignored | true | 27.0 | ~3 (771×793, 780×999, 375×486) | **DISCRETE** |
| True-Ignore-26 | true | 26.0 | 5 (759×898, 791×1179, 375×486, 797×1176, 463×808) | **DISCRETE** |

- `true` vs `false` is clearly distinguishable, so the method is sensitive: `UIRequiresFullScreen` **works** on iOS 27 (discrete resizing), matching WWDC26.
- The threshold value never switched behavior to continuous — including `26.0`, which is below the running OS and should therefore be ignored.

## Context — iPadOS 26.5 (pre-"discrete resizing")
Discrete resizing starts in iOS 27; on 26.5 the older/transitional behavior was observed (Windowed mode):
- Restricted-orientation app (e.g. Portrait-only) → locked to full screen; Landscape-only → keeps landscape aspect, **letterboxed** (black bars) on a portrait display. (See `265_portrait_thr99.png`, `265_landscape_thr99_letterbox.png`.)
- All-orientations app → resizes freely. (See `265_all_thr99_resized.png`.)
- The threshold value (`26.0` vs `99.0`) made no difference here either.

## Expected vs actual (the reported problem)
- Expected (per docs): iPadOS 27.0 + `UIRequiresFullScreen = true` + `UIRequiresFullScreenIgnoredStartingWithVersion = 26.0` (≤ running OS) → key ignored → **continuous** resizing (same as `false`).
- Actual: **discrete** resizing (same as when the threshold is `27.0`). The key had no observable effect.

## Question for Apple
Does `UIRequiresFullScreenIgnoredStartingWithVersion` function on iPadOS 27? A threshold at or below the running OS did not cause `UIRequiresFullScreen` to be ignored — resizing remained discrete rather than becoming continuous — so the documented "ignore starting at the specified version" behavior was not observed.

## Notes / limitations
- "Windowed Apps" multitasking mode must be enabled per simulator; it has no discoverable programmatic toggle.
- `UIScreen` (bounds/nativeBounds) and `UIWindowScene.isFullScreen` are unreliable on iPadOS 26+; `keyWindow.bounds` is the sole geometry signal.
- Resizes were driven by synthesized drags on the window's resize handle; the control (`false`) yielding 60+ finely-spaced sizes confirms the method captures continuous resizing when it occurs.

## Attachments
- `screenshots/27_true_thr26_discrete.png` — iPadOS 27, `true` + threshold 26.0: only 5 distinct sizes, "looks DISCRETE" (threshold below OS did not restore continuous resizing).
- `screenshots/265_portrait_thr99.png`, `265_landscape_thr99_letterbox.png`, `265_all_thr99_resized.png` — iPadOS 26.5 pre-27 behavior (orientation-dependent lock/letterbox vs free).
- `screenshots/27_all_*`, `265_all_*_launch` — earlier launch-state / Info.plist evidence.
