# Hide the recording pill: handoff for Codex

## Request and boundaries

Add an option to **hide the pill entirely while recording** in **ericnchen/EnviousWispr**. Even the existing Capsule style is too tall for the owner; recommending that style or disabling Live Preview is not sufficient.

Open a separate implementation PR against this fork's `main` and **leave it unmerged** for Mac testing and owner review. Do not submit upstream. Keep this independent of the trailing-whitespace fix, already merged in [PR #1](https://github.com/ericnchen/EnviousWispr/pull/1).

Build instructions: [PERSONAL_BUILD.md](../../PERSONAL_BUILD.md). Main is ready to clone and build with the whitespace fix. The optional pill feature is not on main.

## What was inspected

Source baseline: `f28285130d4aacd5eeaf0e406251781cadb3c14d`.

- `Sources/EnviousWisprAppKit/Views/Settings/PillSettingsView.swift`: Dictation > Recording Pill settings page. Exposes position and style; no hide switch or free-form size slider.
- `Sources/EnviousWisprAppKit/Views/Settings/RecordingPillAppearancePanel.swift`: current style picker.
- `Sources/EnviousWisprAppKit/App/PillAppearanceModel.swift`: `chooseCoupled` also changes Live Preview when choosing a style. Wordless styles disable Live Preview.
- `Sources/EnviousWisprCore/SettingsEnums.swift`: classic, levelRail, and readingWell recording designs. The classic capsule reserves a **185 × 92 pt interaction frame**, including locked and expanded-notice states; not all that area necessarily paints a visible capsule. The reading well is **400 pt wide** with content-sized height.
- `Sources/EnviousWisprAppKit/App/Overlay/PillCatalog.swift`: builds recording definitions using the resolved design's width and reserved height. Changing the NSPanel's initial dimensions alone does not change this authority.
- `Sources/EnviousWisprAppKit/App/Overlay/OverlayDirector.swift`: owns the presentation transaction, recording receipts and render model, bridge lifecycle, and transition to processing/errors. Read `render`, `performRender`, `presentRecording`, `showInPanelNotice`, and result/receipt handling.
- `Sources/EnviousWisprAppKit/App/Overlay/OverlayWindowHost.swift`: shared overlay host. `hide()` orders the window out and detaches its content view to stop view-side polling. This host also presents processing, warnings, errors and recovery, so globally disabling it would be too broad.
- `Sources/EnviousWisprAppKit/App/Overlay/Views/RecordingOverlayView.swift`: view-side audio polling and height callbacks require attention when hiding.
- `Tests/EnviousWisprTests/App/Overlay/OverlayDirectorTests.swift`: existing injectable host, scheduling, lifecycle and receipt test patterns.

## Suggested implementation

Add a persisted, opt-in **Hide while recording** toggle on the Recording Pill settings page, default **off**. Capture its value per fresh recording so a mid-recording settings change takes effect on the next recording. Suppress only the recording window; keep recording itself and later non-recording notices intact.

An unpublished local prototype used:
1. A shared preference key `personalHideRecordingPill`.
2. `@AppStorage` in the settings page and an injectable preference-reader closure in the director.
3. A per-recording visibility snapshot keyed by `PresentationID`.
4. A recording-only branch before `host.present` that hides an incumbent window while retaining the logical recording state and receipt.
5. Focused tests for the recording lifecycle/receipt, subsequent processing and errors, a preference frozen for one recording, and the normal visible path.

**This is a proposal, not validated implementation.** Prototype source was prepared locally in the previous cloud session but not published, compiled, or run. The remote `feat/hide-recording-pill` branch may exist without changes, starting at the baseline main commit. Inspect it before reusing it.

## Design points to resolve

- Do not dismiss the recording or clear its reducer state merely to hide its window. Preserve recording shortcuts, stop, cancel, transcription, paste, and required `LivePreviewBridge` lifecycle events.
- Audit **logical acceptance versus actual visibility**. The existing `performRender` Boolean, presentation result/receipt paths and callbacks often mean something was actually shown. A prototype's early `return true` for a hidden recording needs deliberate review; do not claim a notice was visible when it was not.
- In particular audit `showInPanelNotice`, announcements, timers/expiry, first-render deferral/coalescing, render markers, and any callback that records a presentation as shown.
- When hidden recording starts, remove any incumbent overlay instead of leaving its old warning/card onscreen.
- When processing or errors replace the hidden recording, restore normal presentation and placement; do not inherit an “already visible” assumption or stale anchor.
- Avoid opacity-zero or zero-size windows: they can retain invisible interactive surfaces, polling, or misleading presentation results.
- Explain the toggle's effect in the UI: recording indicator and live words are hidden; existing keyboard shortcuts still stop/cancel. In-panel recording notices need explicit behavior. The prototype hid them with the recording window, while leaving non-recording notices visible.
- Hiding the pill need not disable the Live Preview engine. Keep that independent unless a separate behavior is deliberately chosen and documented.
- A smaller painted pill is an alternative only if it is materially shorter than the existing Capsule. The owner's preferred direction is complete hiding.

## Acceptance checks

1. Off: current visible behavior remains intact.
2. On: no recording pill appears or flashes, including first display, audio changes, locking, and Live Preview on/off.
3. Preference persists across relaunch and applies to the next recording.
4. Push-to-talk and toggle/hands-free still stop and cancel correctly; normal transcription and paste succeed.
5. Logical recording receipt/state and bridge lifecycle remain correct.
6. Processing, errors, clipboard fallback, and recovery notices remain available after a hidden recording.
7. An already visible overlay is removed when the hidden recording starts.
8. No invisible window intercepts clicks; view polling/layout callbacks do not keep running unnecessarily.
9. Add focused tests using existing host and scheduling seams, including hidden-to-processing/error transitions, frozen preference, normal visible mode and first-render behavior.
10. Build and visually test on macOS before considering merge. The original cloud session only performed source inspection and static checks.

Use the existing build path in PERSONAL_BUILD.md: full Xcode, mise-managed `tuist@4.195.11`, local signing identity `EnviousWispr Dev`, then `./scripts/build-dev-app.sh`.

Some upstream tests explicitly expect the trailing space intentionally removed in #1. Distinguish those existing expectation differences from new pill regressions. Do not mix unrelated whitespace changes into this feature.

## Publication note

This handoff is a draft PR because Issues are disabled on the fork and the connected GitHub integration lacks permission to enable them. The handoff itself changes documentation only; no pill implementation has been merged.
