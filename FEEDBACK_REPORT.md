# UIRequiresFullScreenIgnoredStartingWithVersion has no observable effect; UIRequiresFullScreen is honored only on iPadOS 26.5 (restricted-orientation apps) and ignored on iPadOS 27.0

## Summary
Two findings from testing a minimal app whose `Info.plist` sets `UIRequiresFullScreen = true` and `UIRequiresFullScreenIgnoredStartingWithVersion = <varied>`:

1. **`UIRequiresFullScreenIgnoredStartingWithVersion` has no observable effect.** Across every combination tested (thresholds `26.0`, `27.0`, `99.0`, and `UIRequiresFullScreen = false`), the value never changed the window's behavior on a given OS + orientation configuration.
2. **`UIRequiresFullScreen`'s effect is governed by OS version and by the app's declared orientations, not by the threshold key:**
   - **iPadOS 26.5:** honored **only** for apps that declare a restricted orientation set (e.g. Portrait-only) → the window is **locked to full screen and cannot be resized**. Apps declaring all orientations resize freely.
   - **iPadOS 27.0:** ignored in all cases → the window resizes freely, even a Portrait-only app can be dragged wider-than-tall.

Per the documentation, a threshold **above** the running OS should keep `UIRequiresFullScreen` **honored**, and a threshold **at/below** the running OS should make it **ignored**. Neither holds: on iPadOS 27 a threshold of `99.0` (> 27) is still ignored, and on iPadOS 26.5 a threshold of `26.0` (≤ 26.5) is still honored (Portrait-only stays full-screen-locked).

## Environment
- Xcode 27.0 (27A5209h), macOS 27.0
- iPadOS 27.0 simulator — iPad Pro 11-inch (M5), 24A5370g
- iPadOS 26.5 simulator — iPad Air 11-inch (M4), 23F77
- App: SwiftUI lifecycle; deployment target iOS 26.0; device family iPhone/iPad. Both "all iPad orientations" and "Portrait-only" variants tested.
- Both simulators set to "Windowed Apps" multitasking mode so windows are resizable.

## Reference
- `UIRequiresFullScreenIgnoredStartingWithVersion`: "The system ignores the key starting in the version you specify and in later versions of iOS. The system only uses this key when your information property list also contains `UIRequiresFullScreen` with a value of `true`."
- TN3192: Migrating your iPad app from the deprecated UIRequiresFullScreen key.

## Methodology
The app reads the two keys back at runtime and records the min/max window aspect ratio (`keyWindow.bounds.width / height`) across a resize session (`keyWindow.bounds` is the only reliable geometry on iPadOS 26+; `UIScreen` is virtualized per-window). Resizing was done by dragging the window's resize handle. "Resizable at all" was judged by whether the window size could change from full screen; "aspect free vs locked" by the min/max spread.

## Results

| OS | Orientations | UIReqFS | Threshold | Resizable? | Aspect | Screenshot |
|---|---|---|---|---|---|---|
| 27.0 | all | true  | 27.0 | yes | FREE 0.366→1.716 | — |
| 27.0 | all | true  | 99.0 | yes | FREE 0.366→0.772 | — |
| 27.0 | all | false | 99.0 | yes | FREE | — |
| 27.0 | Portrait only | true | 99.0 | **yes (to landscape)** | FREE 0.365→1.613 | — |
| 26.5 | all | true | 99.0 | yes | FREE 0.695→1.439 | 265_all_thr99_resized.png |
| 26.5 | all | true | 26.0 | yes | FREE 0.466→0.815 | 265_all_thr26_resized.png |
| 26.5 | Portrait only | true | 99.0 | **no (full-screen locked 820×1180)** | LOCKED | 265_portrait_thr99.png |
| 26.5 | Portrait only | true | 26.0 | **no (full-screen locked 820×1180)** | LOCKED | 265_portrait_thr26.png |
| 26.5 | Landscape ×2 | true | 99.0 | keeps landscape aspect, **letterboxed** (window 1180×820 on a portrait display, black bars top/bottom) | LOCKED 1.439 | 265_landscape_thr99_letterbox.png |

Key observations:
- The threshold value (`26.0` vs `99.0`) never changed behavior in any row.
- On iPadOS 26.5, a Portrait-only app with `UIRequiresFullScreen = true` is locked to full screen (cannot be resized at all), regardless of threshold — including `26.0`, which is ≤ the running OS and should therefore be *ignored*.
- On iPadOS 27.0, the same Portrait-only app resizes freely (even wider-than-tall), regardless of threshold — including `99.0`, which is > the running OS and should therefore be *honored*.
- Apps declaring all orientations resize freely on both OSes (the requirement has no visible effect for them).
- The aspect-ratio-preserving behavior described for iPadOS 26 IS reproducible on 26.5 for a restricted-orientation app: a Landscape-only app keeps its 1.439 landscape aspect and is **letterboxed** (black bars) when placed on a portrait display, rather than stretching. (The Portrait-only "full-screen lock" is the same mechanism — a portrait app fills a portrait display exactly, so no letterbox is visible.) This confirms the residual effect is an aspect-ratio/letterbox lock tied to the declared orientation set — but it is still governed by OS version, not by `UIRequiresFullScreenIgnoredStartingWithVersion`.

## Expected vs actual (threshold key)
- Expected: iPadOS 27.0 + threshold `99.0` (> OS) → honored (Portrait-only locked). Actual: ignored (freely resizable).
- Expected: iPadOS 26.5 + threshold `26.0` (≤ OS) → ignored (Portrait-only resizable). Actual: honored (full-screen locked).

So `UIRequiresFullScreenIgnoredStartingWithVersion` does not gate the behavior at the version it specifies; behavior tracks the OS version and orientation set instead.

## Questions for Apple
1. Does `UIRequiresFullScreenIgnoredStartingWithVersion` still function on iPadOS 26.5 / 27.0? In testing, its value had no observable effect and the documented "honor below the threshold, ignore at/above" contract was not met on either OS.
2. Is `UIRequiresFullScreen` intended to be fully ignored on iPadOS 27.0 (so the key is meaningful only on 26.x)? If so, the documentation should state the system's own cutoff version.
3. Is the residual `UIRequiresFullScreen` effect intended to apply only to apps that declare a restricted orientation set? For a Portrait-only app on 26.5 it produced a full-screen lock (not merely an aspect-ratio constraint); an all-orientations app was unaffected.

## Notes / limitations
- The multitasking mode ("Windowed Apps") must be enabled per simulator; it has no discoverable programmatic toggle.
- `UIScreen` (bounds/nativeBounds) and `UIWindowScene.isFullScreen` were unreliable on iPadOS 26+; `keyWindow.bounds` was used as the sole geometry signal.
- A Landscape-only (2-orientation) app on 26.5 keeps its aspect ratio and letterboxes, but it was not confirmed whether it can be resized to *smaller* sizes while preserving that aspect (vs. being fully full-screen-locked like the Portrait-only case).

## Attachments
- `screenshots/265_all_thr99_resized.png`, `265_all_thr26_resized.png` — 26.5, all orientations, aspect FREE.
- `screenshots/265_portrait_thr99.png`, `265_portrait_thr26.png` — 26.5, Portrait-only, full-screen LOCKED regardless of threshold.
- `screenshots/27_all_thr27.png`, `27_all_thr99.png`, `27_all_false.png`, `265_all_thr99_launch.png`, `265_all_thr26_launch.png` — earlier diagnostic build: launch-state / Info.plist evidence per OS/config.
