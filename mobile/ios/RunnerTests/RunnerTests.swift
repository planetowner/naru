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

@MainActor
final class PhotoCropTests: XCTestCase {
  private func stripedImage(portrait: Bool, scale: CGFloat = 1) -> UIImage {
    let size = portrait ? CGSize(width: 400, height: 600) : CGSize(width: 600, height: 400)
    let format = UIGraphicsImageRendererFormat()
    format.scale = scale
    format.preferredRange = .standard
    return UIGraphicsImageRenderer(size: size, format: format).image { context in
      for (index, color) in [UIColor.red, .green, .blue].enumerated() {
        color.setFill()
        context.fill(portrait
          ? CGRect(x: 0, y: index * 200, width: 400, height: 200)
          : CGRect(x: index * 200, y: 0, width: 200, height: 400))
      }
    }
  }

  private func pixel(_ image: UIImage, x: Int, y: Int) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: 4)
    let context = CGContext(
      data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let cgImage = image.cgImage!
    context.draw(cgImage.cropping(to: CGRect(x: x, y: y, width: 1, height: 1))!,
                 in: CGRect(x: 0, y: 0, width: 1, height: 1))
    return Array(bytes.prefix(3))
  }

  func testPortraitAndLandscapeStartCenteredWithoutEmptySpace() throws {
    for portrait in [true, false] {
      let view = SquarePhotoCropView(
        frame: CGRect(x: 0, y: 0, width: 200, height: 200),
        image: stripedImage(portrait: portrait)
      )
      let cropped = try XCTUnwrap(view.croppedImage())
      XCTAssertEqual(cropped.size, CGSize(width: 400, height: 400))
      XCTAssertEqual(pixel(cropped, x: 10, y: 10), [255, 0, 0])
      XCTAssertEqual(pixel(cropped, x: 200, y: 200), [0, 255, 0])
      XCTAssertEqual(pixel(cropped, x: 390, y: 390), [0, 0, 255])
    }
  }

  func testZoomAndPanSelectTheVisiblePartAndResizeKeepsIt() throws {
    let view = SquarePhotoCropView(
      frame: CGRect(x: 0, y: 0, width: 200, height: 200),
      image: stripedImage(portrait: false)
    )
    view.layoutIfNeeded()
    view.zoomScale = 1
    view.contentOffset = CGPoint(x: 400, y: 100)
    let cropped = try XCTUnwrap(view.croppedImage())
    XCTAssertEqual(cropped.size, CGSize(width: 200, height: 200))
    XCTAssertEqual(pixel(cropped, x: 10, y: 10), [0, 0, 255])
    XCTAssertEqual(pixel(cropped, x: 190, y: 190), [0, 0, 255])
    view.frame.size = CGSize(width: 300, height: 300)
    let resized = try XCTUnwrap(view.croppedImage())
    XCTAssertEqual(resized.size, cropped.size)
    XCTAssertEqual(pixel(resized, x: 10, y: 10), [0, 0, 255])
  }

  func testCameraOrientationsAndRetinaScaleMatchTheDisplayedPhoto() throws {
    let original = stripedImage(portrait: true, scale: 2)
    for orientation: UIImage.Orientation in [
      .up, .down, .left, .right, .upMirrored, .downMirrored, .leftMirrored, .rightMirrored,
    ] {
      let source = UIImage(cgImage: original.cgImage!, scale: 2, orientation: orientation)
      let view = SquarePhotoCropView(
        frame: CGRect(x: 0, y: 0, width: 200, height: 200), image: source
      )
      let cropped = try XCTUnwrap(view.croppedImage())
      XCTAssertEqual(cropped.size, CGSize(width: 800, height: 800))
      XCTAssertEqual(cropped.imageOrientation, .up)
      let format = UIGraphicsImageRendererFormat()
      format.scale = 2
      let displayed = UIGraphicsImageRenderer(size: source.size, format: format).image { _ in
        source.draw(at: .zero)
      }
      let offsetX = (displayed.cgImage!.width - 800) / 2
      let offsetY = (displayed.cgImage!.height - 800) / 2
      for point in [(10, 10), (790, 10), (10, 790), (790, 790)] {
        XCTAssertEqual(
          pixel(cropped, x: point.0, y: point.1),
          pixel(displayed, x: point.0 + offsetX, y: point.1 + offsetY),
          "orientation: \(orientation.rawValue)"
        )
      }
    }
  }

  func testCropWaitsForAVisibleViewport() {
    let view = SquarePhotoCropView(frame: .zero, image: stripedImage(portrait: true))
    XCTAssertNil(view.croppedImage())
  }
}
