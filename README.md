# UIRequiresFullScreenIgnoredStartingWithVersion has no observable effect; UIRequiresFullScreen is ignored on iPadOS 27 regardless of the threshold

## Summary
The `Info.plist` key `UIRequiresFullScreenIgnoredStartingWithVersion` does not appear to control when `UIRequiresFullScreen` is honored vs. ignored.

Per the documentation, when `UIRequiresFullScreen` is `true`, the system should ignore it **starting at the version specified in `UIRequiresFullScreenIgnoredStartingWithVersion` and later**, and should **honor** it on versions **below** that threshold.

In practice, on iPadOS 27.0 the app is always presented as a freely resizable window even when the threshold is set to a version far above the running OS (e.g. `99.0`), and even when `UIRequiresFullScreen` is set to `false` — i.e. the value of both keys makes no observable difference. Changing the threshold value (`26.0` / `27.0` / `99.0`) never changed behavior on any single device.

This is either (a) an intended end state (iPadOS 27 always ignores `UIRequiresFullScreen`, making the threshold key relevant only on iPadOS 26.x — in which case the documentation is over-general / stale), or (b) a bug. The report asks Apple to confirm which, and to clarify the documented contract.

## Environment
- Xcode 27.0 (27A5209h)
- macOS 27.0 (26A5368g)
- Simulator runtimes: iOS 27.0 (24A5370g), iOS 26.5 (23F77)
- Device: iPad Pro 13-inch (M5) simulator (both runtimes)
- App: SwiftUI lifecycle, deployment target iOS 26.0, `TARGETED_DEVICE_FAMILY = 1,2,7`

## Reference
- Documentation: `UIRequiresFullScreenIgnoredStartingWithVersion` — "Use this key only if you've already updated your app so that it no longer uses `UIRequiresFullScreen` in later versions of iOS. … The system ignores the key starting in the version you specify and in later versions of iOS. The system only uses this key when your information property list also contains `UIRequiresFullScreen` with a value of `true`."
- TN3192: Migrating your iPad app from the deprecated UIRequiresFullScreen key.

## Test setup
A minimal SwiftUI app whose `Info.plist` contains:
```
UIRequiresFullScreen = true
UIRequiresFullScreenIgnoredStartingWithVersion = <varied: 26.0 / 27.0 / 99.0>
```
The app reads these keys back at runtime via `Bundle.main.object(forInfoDictionaryKey:)` and displays the live window size (`keyWindow.bounds.size`). The window size is the authoritative signal because, under iPadOS 26+ windowing, `UIScreen` (`bounds` and `nativeBounds`) is virtualized to the per-window screen and no longer reports the physical display size; `UIWindowScene.isFullScreen` was also observed to be unreliable (see Notes). The simulator screenshots are ground truth.

The iPad Pro 13-inch (M5) physical display is 1032 × 1376 pt. A window of 1032 × 1376 = full screen; a smaller window (observed 375 × 486) = freely resized / windowed.

## Steps to reproduce
1. Build the attached app with `UIRequiresFullScreen = true` and a chosen `UIRequiresFullScreenIgnoredStartingWithVersion`.
2. Run on an iPad simulator and observe the reported `Window` size and whether the app is a full-screen or a floating, resizable window.
3. Repeat with different threshold values and on both iPadOS 26.5 and 27.0.

## Results

### iPadOS 27.0 (simulator default: Windowed Apps mode)
| # | UIRequiresFullScreen | IgnoredStartingWithVersion | Window | Presentation | Screenshot |
|---|---|---|---|---|---|
| 1 | true  | 27.0 | 375 × 486 | windowed / resizable | `screenshots/01_iPadOS27_true_ignore27.png` |
| 2 | true  | 99.0 | 375 × 486 | windowed / resizable | `screenshots/02_iPadOS27_true_ignore99.png` |
| 3 | false | 99.0 | 375 × 486 | windowed / resizable | `screenshots/03_iPadOS27_false_control.png` |

Cases 2 and 3 are pixel-identical: `UIRequiresFullScreen = true` (threshold 99.0, which is **above** the running OS and should therefore be **honored**) behaves exactly like `UIRequiresFullScreen = false`. The key has no effect on iPadOS 27.

### iPadOS 26.5 (simulator default: Full Screen Apps mode)
| # | UIRequiresFullScreen | IgnoredStartingWithVersion | Window | Presentation | Screenshot |
|---|---|---|---|---|---|
| 4 | true  | 99.0 | 1032 × 1376 | full screen | `screenshots/04_iPadOS26_5_true_ignore99.png` |
| 5 | true  | 26.0 | 1032 × 1376 | full screen | `screenshots/05_iPadOS26_5_true_ignore26.png` |

On 26.5 the threshold value also makes no difference (cases 4 and 5 identical). Note this device was in "Full Screen Apps" multitasking mode, so all apps are full screen regardless — see Notes; this run is included for completeness but is not, by itself, conclusive about the key.

## Expected behavior
On iPadOS 27.0 with `UIRequiresFullScreen = true` and `UIRequiresFullScreenIgnoredStartingWithVersion = 99.0` (i.e. threshold > running OS), the system should **honor** `UIRequiresFullScreen` and present the app full screen / non-resizable, as documented.

## Actual behavior
The app is presented as a freely resizable window (375 × 486, far smaller than the 1032 × 1376 display). The behavior is identical for `UIRequiresFullScreen = true` (any threshold) and `UIRequiresFullScreen = false`, i.e. the requirement is ignored on iPadOS 27 regardless of the threshold key.

## Notes / caveats (for accurate triage)
1. **Multitasking mode confound.** Window presentation is also influenced by the per-device "Windowed Apps" vs "Full Screen Apps" setting (Settings → Multitasking). The two simulators used here defaulted to different modes (27.0 = Windowed, 26.5 = Full Screen), so the cross-version difference is not solely attributable to the keys. The cleanest within-device, mode-controlled evidence is on iPadOS 27.0 (cases 1–3): varying the threshold, and even toggling `UIRequiresFullScreen` true↔false, produced no change. A fully isolated test of the threshold on iPadOS 26.x in "Windowed Apps" mode is still desirable but was not automatable in this environment.
2. **`UIScreen` virtualization.** Under iPadOS 26+ windowing, `UIScreen.bounds` and `UIScreen.nativeBounds` report the per-window size, not the physical display. Apps that derive the display size from `UIScreen` will get the window size instead. (Reported as context; may be intended.)
3. **`UIWindowScene.isFullScreen`** returned `false` even when the app filled the entire display in "Full Screen Apps" mode on iPadOS 26.5, so it could not be used as a reliable full-screen indicator here.

## Question for Apple
Is iPadOS 27 intended to ignore `UIRequiresFullScreen` unconditionally (making `UIRequiresFullScreenIgnoredStartingWithVersion` meaningful only on iPadOS 26.x)? If so, the documentation for `UIRequiresFullScreenIgnoredStartingWithVersion` should state the system's own cutoff version. If not, this is a bug: a threshold above the running OS is not honoring `UIRequiresFullScreen`.

## Attachments
- `screenshots/01_iPadOS27_true_ignore27.png`
- `screenshots/02_iPadOS27_true_ignore99.png`
- `screenshots/03_iPadOS27_false_control.png`
- `screenshots/04_iPadOS26_5_true_ignore99.png`
- `screenshots/05_iPadOS26_5_true_ignore26.png`
