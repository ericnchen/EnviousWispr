import AppKit
import EnviousWisprAppKitTestSupport
import EnviousWisprCore
import EnviousWisprPipeline
import Foundation
import Testing

@testable import EnviousWisprAppKit

@MainActor
@Suite(.tags(.productOutcome))
struct HiddenRecordingPillTests {
  init() { _ = NSApplication.shared }

  @MainActor
  private final class Rig {
    let host = WindowlessOverlayHost()
    var hide = true
    var preferenceReads = 0
    var bridgeEvents: [Bool] = []
    var announcements: [OverlayAnnouncement] = []
    var scheduledExpiry: [OverlayScheduledWork] = []
    var pendingRender: (() -> Void)?
    var deferFirstRender = false
    var preview = false

    lazy var director = OverlayDirector(
      host: host,
      scheduler: .manual { [unowned self] in scheduledExpiry.append($0) },
      announce: { [unowned self] in announcements.append($0) },
      livePreview: LivePreviewBridge(
        recordingDidChange: { [unowned self] in bridgeEvents.append($0) },
        isEnabledForGeometry: { [unowned self] in preview },
        wordsCapability: { [unowned self] in preview ? .available : .previewOff },
        display: { .off }),
      grantAccessibility: {}, openMicrophoneSettings: {}, advisoryHint: { _ in nil },
      selections: { .shipped },
      hideRecordingPill: { [unowned self] in
        preferenceReads += 1
        return hide
      },
      firstRenderSchedule: { [unowned self] work in
        if deferFirstRender { pendingRender = work } else { work() }
      })

    func record(level: Float = 0.2, locked: Bool = false) -> PillRequest {
      .recording(
        RecordingPillInput(
          audioLevel: level, audioLevelProvider: { level },
          recordingElapsedProvider: { 3 }, isLocked: locked))
    }

    func flushRender() {
      let work = pendingRender
      pendingRender = nil
      work?()
    }
  }

  @Test("hidden recording retains ownership and bridge lifecycle, without a visible result",
        arguments: [false, true])
  func hiddenRecordingLifecycle(preview: Bool) throws {
    let rig = Rig()
    rig.preview = preview
    var results: [PillPresentationResult] = []
    let receipt = try #require(rig.director.present(rig.record(), onResult: { results.append($0) }))

    #expect(rig.director.isCurrent(receipt))
    #expect(!rig.director.featureSlotIsAvailable)
    #expect(results == [.notPresented])
    #expect(rig.host.presented.isEmpty)
    #expect(!rig.host.isShowing)
    #expect(rig.pendingRender == nil)
    #expect(rig.bridgeEvents == [true])
    #expect(rig.announcements.isEmpty)
    #expect(rig.scheduledExpiry.isEmpty)
    #expect(rig.director.renderModel.state.recording?.recordingElapsedProvider() == 3)

    rig.director.update(.recordingLock(true))
    rig.director.present(rig.record(level: 0.7, locked: true), onResult: { results.append($0) })
    #expect(rig.director.isCurrent(receipt))
    #expect(rig.director.renderModel.state.recording?.isLocked == true)
    #expect(rig.host.presented.isEmpty)
    #expect(results == [.notPresented, .notPresented])
    #expect(rig.preferenceReads == 1)
    rig.director.renderModel.state.recording?.onContentHeightChange(250)
    #expect(rig.host.resizes.isEmpty)

    rig.director.dismissIfCurrent(receipt)
    #expect(!rig.director.isCurrent(receipt))
    #expect(rig.director.featureSlotIsAvailable)
    #expect(rig.director.renderModel.state.recording == nil)
    #expect(rig.bridgeEvents == [true, false])
  }

  @Test("visibility is frozen in both directions until the next recording", arguments: [false, true])
  func preferenceFrozen(initiallyHidden: Bool) throws {
    let rig = Rig()
    rig.hide = initiallyHidden
    let first = try #require(rig.director.present(rig.record()))
    rig.hide.toggle()
    rig.director.update(.recordingLock(true))
    rig.director.present(rig.record(level: 0.8, locked: true))
    #expect(rig.director.isCurrent(first))
    #expect(rig.host.isShowing == !initiallyHidden)
    #expect(rig.preferenceReads == 1)

    rig.director.dismissIfCurrent(first)
    let next = try #require(rig.director.present(rig.record()))
    #expect(next != first)
    #expect(rig.host.isShowing == initiallyHidden)
    #expect(rig.preferenceReads == 2)
  }

  @Test("hidden recording removes an already visible warning")
  func removesIncumbentWindow() throws {
    let rig = Rig()
    rig.director.present(.warning(reason: .polishFailed))
    #expect(rig.host.isShowing)
    let warningExpiry = try #require(rig.scheduledExpiry.first)
    let recording = try #require(rig.director.present(rig.record()))
    #expect(!rig.host.isShowing)
    #expect(rig.host.presented.count == 1)
    #expect(rig.director.renderModel.state.recording != nil)
    warningExpiry.fire()
    #expect(rig.director.isCurrent(recording))
  }

  @Test("later pipeline notices present normally and start with fresh placement", arguments: 0..<5)
  func successorVisible(successor: Int) throws {
    let rig = Rig()
    let recording = try #require(rig.director.present(rig.record()))
    let request: PillRequest
    switch successor {
    case 0: request = .processing(phase: .transcribing)
    case 1: request = .error(reason: .asrFailed)
    case 2: request = .clipboardFallback
    case 3: request = .recoverySucceeded
    default: request = .warning(reason: .polishFailed)
    }
    var results: [PillPresentationResult] = []
    let successorReceipt = try #require(
      rig.director.present(request, onResult: { results.append($0) }))
    #expect(results == [.presented(successorReceipt)])
    #expect(rig.host.isShowing)
    #expect(rig.host.presented.last?.isFresh == true)
    #expect(!rig.director.isCurrent(recording))
    #expect(rig.director.renderModel.state.recording == nil)
    #expect(rig.bridgeEvents == [true, false])
  }

  @Test("hidden in-panel notices report false and never announce or arm expiry")
  func noticesNotShown() {
    let rig = Rig()
    rig.director.present(rig.record())
    #expect(!rig.director.showInPanelNotice(.secureInputActive, dismissAfter: 5))
    rig.director.update(.inPanelNotice(.autoStopUnavailable, dismissAfter: 4))
    #expect(rig.director.renderModel.state.recording?.noticeText == nil)
    #expect(rig.scheduledExpiry.isEmpty)
    #expect(rig.announcements.isEmpty)
    #expect(rig.host.presented.isEmpty)
  }

  @Test("visible mode still reports presentation and shows recording notices")
  func visibleMode() throws {
    let rig = Rig()
    rig.hide = false
    var results: [PillPresentationResult] = []
    let receipt = try #require(rig.director.present(rig.record(), onResult: { results.append($0) }))
    #expect(results == [.presented(receipt)])
    #expect(rig.host.isShowing)
    #expect(rig.director.showInPanelNotice(.autoStopUnavailable, dismissAfter: 4))
    #expect(rig.director.renderModel.state.recording?.noticeText != nil)
    #expect(rig.scheduledExpiry.count == 1)
  }

  @Test("hidden recording settles a pending card without flashing either presentation")
  func pendingCardSuperseded() {
    let rig = Rig()
    rig.deferFirstRender = true
    var cardResults: [PillPresentationResult] = []
    rig.director.present(
      .bluetoothAwareness(onAcknowledge: {}, onClose: {}, onOpenSettings: {}),
      onResult: { cardResults.append($0) })
    #expect(cardResults.isEmpty)
    rig.director.present(rig.record())
    #expect(cardResults == [.notPresented])
    rig.flushRender()
    #expect(cardResults == [.notPresented])
    #expect(rig.host.presented.isEmpty)
    #expect(rig.announcements.isEmpty)
    #expect(rig.director.renderModel.state.recording != nil)
  }

  @Test("the first visible successor remains deferred after a hidden recording")
  func hiddenDoesNotConsumeFirstRender() throws {
    let rig = Rig()
    rig.deferFirstRender = true
    rig.director.present(rig.record())
    #expect(rig.pendingRender == nil)
    var results: [PillPresentationResult] = []
    let receipt = try #require(rig.director.present(
      .processing(phase: .transcribing), onResult: { results.append($0) }))
    #expect(results.isEmpty)
    #expect(rig.host.presented.isEmpty)
    rig.flushRender()
    #expect(results == [.presented(receipt)])
    #expect(rig.host.presented.count == 1)
    #expect(rig.host.presented.last?.isFresh == true)
  }

  @Test("a superseded card's callback can present an error during recording suppression")
  func reentrantPendingResult() {
    let rig = Rig()
    rig.deferFirstRender = true
    rig.director.present(
      .bluetoothAwareness(onAcknowledge: {}, onClose: {}, onOpenSettings: {}),
      onResult: { _ in rig.director.present(.error(reason: .asrFailed)) })
    rig.director.present(rig.record())
    rig.flushRender()
    #expect(rig.host.isShowing)
    #expect(rig.host.presented.count == 1)
    #expect(rig.director.renderModel.state.recording == nil)
    #expect(rig.bridgeEvents == [true, false])
  }
}
