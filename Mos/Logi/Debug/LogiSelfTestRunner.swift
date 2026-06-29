//
//  LogiSelfTestRunner.swift
//  Mos
//
//  DEBUG-only step runner that drives the Self-Test Wizard. Skeleton —
//  detailed Bolt/BLE step lists per spec §7 Tier 3c land in a later pass.
//

#if DEBUG
import Foundation

/// What kind of action a wizard step performs.
/// Closure-based so wizard steps can bridge physical confirmation callbacks.
enum StepKind {
    case automatic(detail: String,
                   run: (@escaping (StepOutcome) -> Void) -> Void)
    case physicalAutoVerified(instruction: String,
                              expectation: String,
                              wait: WaitCondition,
                              timeout: TimeInterval)
    case physicalUserConfirmed(instruction: String,
                               expectation: String,
                               confirmPrompt: String)
}

/// Async wait condition for a `physicalAutoVerified` step. The wizard
/// observes a notification or a session state transition and resolves.
enum WaitCondition {
    case rawButtonEvent(mosCode: UInt16?, cid: UInt16?)
    case sessionConnected(mode: LogiDeviceSession.ConnectionMode)
    case sessionDisconnected
    case divertApplied(cid: UInt16, expectBit0: Bool)
    case dpiChanged(direction: Direction)
}

enum StepOutcome {
    case pass
    case fail(reason: String)
}

/// Read-only description of a session reachable for the wizard.
enum DetectedConnection {
    case bleDirect(snapshot: LogiDeviceSessionSnapshot, name: String)
}

/// Single self-test step shown in the wizard.
struct Step {
    let index: Int          // 1-based
    let total: Int
    let title: String       // 1-line
    let instruction: String
    let expectation: String
    let kind: StepKind
}

final class LogiSelfTestRunner {

    /// Inspect the first active session and classify connection mode.
    /// Returns nil when no session is reachable.
    func detectConnection() -> DetectedConnection? {
        guard let snapshot = LogiCenter.shared.activeSessionsSnapshot().first else { return nil }
        return .bleDirect(snapshot: snapshot, name: snapshot.deviceInfo.name)
    }

    // TODO: runStep(_:) / handleCancel()
}

extension LogiSelfTestRunner {

    /// Minimal BLE suite for the dedicated MX Anywhere 2S Bluetooth fork.
    func buildBLESuite() -> [Step] {
        var steps: [Step] = []
        steps.append(Step(
            index: 1, total: 2,
            title: "BLE device detection",
            instruction: "Confirm the MX Anywhere 2S is connected over Bluetooth.",
            expectation: "LogiCenter reports an active BLE session.",
            kind: .automatic(detail: "Reads detectConnection() and asserts a .bleDirect result.") { completion in
                let outcome: StepOutcome
                if case .bleDirect = self.detectConnection() {
                    outcome = .pass
                } else {
                    outcome = .fail(reason: "detectConnection did not return .bleDirect")
                }
                completion(outcome)
            }
        ))
        steps.append(Step(
            index: 2, total: 2,
            title: "Back button raw event",
            instruction: "Press the Back button on your Logi mouse within 30 seconds.",
            expectation: "rawButtonEvent fires with mosCode = 1006 (Back).",
            kind: .physicalAutoVerified(
                instruction: "Press the Back button on your Logi mouse within 30 seconds.",
                expectation: "rawButtonEvent fires with mosCode 1006.",
                wait: .rawButtonEvent(mosCode: 1006, cid: nil),
                timeout: 30
            )
        ))
        return steps
    }
}
#endif
