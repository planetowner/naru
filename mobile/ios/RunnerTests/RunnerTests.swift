import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testCallResultKeepsOriginalCallIdentity() {
    let callID = UUID()
    for outcome in ["cancelled", "no_answer", "ended", "missed"] {
      let event: [String: Any] = [
        "type": "message.created",
        "message": [
          "id": UUID().uuidString,
          "metadata": [
            "outcome": outcome,
            "call_start_message_id": callID.uuidString,
          ],
        ],
      ]
      XCTAssertEqual(NotificationBridge.callOutcome(from: event, callUUID: callID), outcome)
      XCTAssertNil(NotificationBridge.callOutcome(from: event, callUUID: UUID()))
    }
  }

  func testLegacyCallUpdatesStillEndTheOriginalCall() {
    let callID = UUID()
    let event: [String: Any] = [
      "type": "message.updated",
      "message": ["id": callID.uuidString, "metadata": ["outcome": "cancelled"]],
    ]
    XCTAssertEqual(NotificationBridge.callOutcome(from: event, callUUID: callID), "cancelled")
  }

  func testStartedOrUnrelatedEventsDoNotEndACall() {
    let callID = UUID()
    for type in ["message.created", "message.updated", "messages.read"] {
      let event: [String: Any] = [
        "type": type,
        "message": ["id": callID.uuidString, "metadata": ["outcome": "started"]],
      ]
      XCTAssertNil(NotificationBridge.callOutcome(from: event, callUUID: callID))
    }
    XCTAssertNil(NotificationBridge.callOutcome(from: [:], callUUID: callID))
  }

}
