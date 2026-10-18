# Hide while recording: implementation and Mac validation

This implements the handoff in fork PR #2. The implementation PR stays unmerged until Mac testing and owner review.

In **Dictation > Recording Pill**, **Hide while recording** is off by default. The preference is stored under `personalHideRecordingPill` in the local app's UserDefaults and is read once for each fresh recording. Changes during a recording apply to the next recording.

When enabled, the recording window is ordered out and its content detached through the existing host `hide()` operation. There is no transparent or zero-size interactive window. Suppression runs before the first-render gate, so a hidden recording does not request root construction or mount a recording view through the host. An incumbent warning or card is removed. The recording retains reducer ownership, its receipt, providers and Live Preview bridge lifecycle; hiding does not change the Live Preview setting or engine.

A hidden recording reports `.notPresented` through presentation-result callbacks while its receipt remains current. In-pill recording notices are skipped, return false from `showInPanelNotice`, and do not announce or start expiry timers. Processing, terminal errors, clipboard fallback and recovery use the normal presentation path. Their first window after a hidden recording is fresh and uses normal placement rather than an old drag anchor.

## Validation completed on Linux

- `git diff --check`
- `bash scripts/check-dependency-direction.sh` (25 modules)
- Source review of first-render coalescing, callback reentrancy, visibility results, receipt ownership, provider cleanup, window teardown, expiry and subsequent presentation placement.

The new `HiddenRecordingPillTests` suite has not been compiled or run here. This Linux VPS has no Swift or Xcode installation, and the fork has no registered self-hosted runner; its inherited macOS workflow requests the custom `xcode-27` runner label. No macOS build, UI observation, or live dictation success is claimed.

## Run on the Mac

Follow [PERSONAL_BUILD.md](../../PERSONAL_BUILD.md) for Xcode, pinned Tuist and local signing setup. Check out `feat/hide-recording-pill-implementation`, then build using `./scripts/build-dev-app.sh`.

Run the focused logic suites in both configurations:

```sh
./scripts/xcode-test.sh --release \
  --filter EnviousWisprTests/HiddenRecordingPillTests \
  --filter EnviousWisprTests/OverlayDirectorTests
```

The focused suite covers hidden receipt ownership, lock/audio morphs, Live Preview capability on/off, frozen visibility in both directions, removal of an incumbent warning, visible processing/errors/clipboard/recovery/warnings, notice suppression, visible-mode control, deferred-card replacement, deferred first visible successor, and reentrant result callbacks. The existing real-panel polling test remains relevant to AppKit content detachment and needs Mac execution too:

```sh
./scripts/xcode-test.sh \
  --filter EnviousWisprDesktopEffectsTests/RecordingPollingRealPanelTests
```

Before merging, run the full normal validation required by the repository. The inherited test-recipe gate also requires a hardening declaration for this new suite; none is claimed from Linux. Issues are disabled in this fork, so an upstream-style issue-backed recipe is not currently available. Do not substitute a false parent-red declaration.

## Manual acceptance

1. With the toggle off, confirm the existing recording pill and in-pill notices behave normally.
2. Enable the toggle. Start both push-to-talk and toggle/hands-free recordings, with Live Preview on and off. Confirm no recording pill flashes or appears when audio or lock state changes.
3. Confirm keyboard stop/cancel, transcription and paste work. Verify clicks reach the application beneath the former recording area.
4. Change the toggle during a recording. Confirm the current recording keeps its original visibility and the next one uses the new choice. Relaunch the local app and check persistence.
5. Begin a hidden recording while a warning/card is visible. Confirm the old window disappears. Stop recording and confirm processing, errors, clipboard fallback and recovery remain visible as applicable.
6. With VoiceOver if used, confirm hidden recording notices are not announced as shown, while subsequent visible notices remain announced normally.

The already-merged whitespace change is independent. Any existing tests that require its former trailing spaces are baseline expectation differences, not changes introduced by this feature.
