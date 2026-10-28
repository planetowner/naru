import Flutter
import PencilKit
import UIKit

private enum PencilKitEditorStyle {
  // Flutter의 AppMediaViewerChrome.backgroundColor와 같은 #202020을 유지해요.
  static let backgroundColor = UIColor(
    red: 32 / 255,
    green: 32 / 255,
    blue: 32 / 255,
    alpha: 1
  )

  // 사진과 화면의 방향이 같고 로그 비율 차이가 이 값보다 작으면 화면을 채워요.
  // Flutter 사진 뷰어의 _photoViewerFit과 같은 기준을 유지해요.
  static let aspectFillLogRatioThreshold: CGFloat = 0.45
}

private enum PencilKitEditorError: LocalizedError {
  case invalidArguments
  case unreadableImage
  case renderFailed

  var errorDescription: String? {
    switch self {
    case .invalidArguments:
      return "The photo editor received invalid arguments."
    case .unreadableImage:
      return "The selected photo could not be decoded."
    case .renderFailed:
      return "The edited photo could not be rendered."
    }
  }
}

final class PencilKitEditorBridge: NSObject, FlutterPlugin {
  private static let channelName = "naru/pencil-kit-editor"
  private static let viewType = "naru/pencil-kit-editor"

  private var sessions: [String: PencilKitEditorSession] = [:]
  private var activeEditorId: String?
  private var channel: FlutterMethodChannel?

  static func register(with registrar: FlutterPluginRegistrar) {
    let bridge = PencilKitEditorBridge()
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    bridge.channel = channel
    registrar.addMethodCallDelegate(bridge, channel: channel)
    registrar.register(
      PencilKitEditorViewFactory(bridge: bridge),
      withId: viewType
    )
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "activate":
      guard
        let arguments = call.arguments as? [String: Any],
        let editorId = arguments["editor_id"] as? String
      else {
        result(Self.flutterError(PencilKitEditorError.invalidArguments))
        return
      }

      activate(editorId: editorId)
      result(nil)
    case "set-controls-visible":
      guard
        let arguments = call.arguments as? [String: Any],
        let editorId = arguments["editor_id"] as? String,
        let visible = arguments["visible"] as? Bool
      else {
        result(Self.flutterError(PencilKitEditorError.invalidArguments))
        return
      }

      sessions[editorId]?.liveView?.setControlsVisible(visible)
      result(nil)
    case "render":
      guard
        let arguments = call.arguments as? [String: Any],
        let editorIds = arguments["editor_ids"] as? [String]
      else {
        result(Self.flutterError(PencilKitEditorError.invalidArguments))
        return
      }

      do {
        result(try render(editorIds: editorIds))
      } catch {
        result(Self.flutterError(error))
      }
    case "deactivate":
      guard
        let arguments = call.arguments as? [String: Any],
        let editorIds = arguments["editor_ids"] as? [String]
      else {
        result(Self.flutterError(PencilKitEditorError.invalidArguments))
        return
      }

      deactivate(editorIds: editorIds)
      result(nil)
    case "dispose":
      guard
        let arguments = call.arguments as? [String: Any],
        let editorIds = arguments["editor_ids"] as? [String]
      else {
        result(Self.flutterError(PencilKitEditorError.invalidArguments))
        return
      }

      deactivate(editorIds: editorIds)
      for editorId in editorIds {
        sessions.removeValue(forKey: editorId)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  fileprivate func session(
    editorId: String,
    inputPath: String
  ) throws -> PencilKitEditorSession {
    if let session = sessions[editorId] {
      return session
    }
    guard let image = UIImage(contentsOfFile: inputPath) else {
      throw PencilKitEditorError.unreadableImage
    }

    let session = PencilKitEditorSession(sourceImage: image)
    sessions[editorId] = session
    return session
  }

  fileprivate func attach(
    view: PencilKitEditorCanvasView,
    editorId: String,
    active: Bool
  ) {
    sessions[editorId]?.liveView = view
    view.onToolPickerFrameChanged = { [weak self] centerFromBottom in
      self?.channel?.invokeMethod(
        "tool-picker-frame-changed",
        arguments: ["center_from_bottom": centerFromBottom]
      )
    }

    if active {
      activate(editorId: editorId)
    } else {
      view.setActive(false)
    }
  }

  private func activate(editorId: String) {
    activeEditorId = editorId

    for (sessionEditorId, session) in sessions {
      session.liveView?.setActive(sessionEditorId == editorId)
    }
  }

  private func deactivate(editorIds: [String]) {
    for editorId in editorIds {
      sessions[editorId]?.liveView?.setActive(false)
    }
    if let activeEditorId, editorIds.contains(activeEditorId) {
      self.activeEditorId = nil
    }
  }

  private func render(editorIds: [String]) throws -> [[String: Any]] {
    var results: [[String: Any]] = []

    for editorId in editorIds {
      guard let session = sessions[editorId] else {
        continue
      }

      session.liveView?.persistDrawing()

      guard !session.drawing.strokes.isEmpty else {
        continue
      }

      let output = try session.render(editorId: editorId)
      results.append([
        "editor_id": editorId,
        "output_path": output.outputURL.path,
        "preview_path": output.previewURL.path,
      ])
    }

    return results
  }

  private static func flutterError(_ error: Error) -> FlutterError {
    FlutterError(
      code: "pencil-kit-editor-failed",
      message: error.localizedDescription,
      details: nil
    )
  }
}

private final class PencilKitEditorViewFactory: NSObject,
  FlutterPlatformViewFactory
{
  init(bridge: PencilKitEditorBridge) {
    self.bridge = bridge
    super.init()
  }

  private weak var bridge: PencilKitEditorBridge?

  func createArgsCodec() -> (any FlutterMessageCodec & NSObjectProtocol) {
    return FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    guard
      let bridge,
      let arguments = args as? [String: Any],
      let editorId = arguments["editor_id"] as? String,
      let inputPath = arguments["input_path"] as? String,
      let controlsVisible = arguments["controls_visible"] as? Bool,
      let active = arguments["active"] as? Bool,
      let session = try? bridge.session(
        editorId: editorId,
        inputPath: inputPath
      )
    else {
      return PencilKitEditorErrorPlatformView(frame: frame)
    }

    let platformView = PencilKitEditorPlatformView(
      frame: frame,
      session: session,
      controlsVisible: controlsVisible
    )
    bridge.attach(
      view: platformView.canvasView,
      editorId: editorId,
      active: active
    )
    return platformView
  }
}

private final class PencilKitEditorPlatformView: NSObject, FlutterPlatformView {
  init(
    frame: CGRect,
    session: PencilKitEditorSession,
    controlsVisible: Bool
  ) {
    canvasView = PencilKitEditorCanvasView(
      frame: frame,
      session: session,
      controlsVisible: controlsVisible
    )
    super.init()
  }

  let canvasView: PencilKitEditorCanvasView

  func view() -> UIView {
    return canvasView
  }
}

private final class PencilKitEditorErrorPlatformView: NSObject,
  FlutterPlatformView
{
  init(frame: CGRect) {
    errorView = UIView(frame: frame)
    errorView.backgroundColor = PencilKitEditorStyle.backgroundColor
    super.init()
  }

  private let errorView: UIView

  func view() -> UIView {
    return errorView
  }
}

private final class PencilKitEditorSession {
  init(sourceImage: UIImage) {
    self.sourceImage = sourceImage
  }

  let sourceImage: UIImage
  var drawing = PKDrawing()
  var canvasSize = CGSize.zero
  weak var liveView: PencilKitEditorCanvasView?

  func render(editorId: String) throws -> (
    outputURL: URL,
    previewURL: URL
  ) {
    guard canvasSize.width > 0, canvasSize.height > 0 else {
      throw PencilKitEditorError.renderFailed
    }

    let outputSize = sourceImage.size
    let outputBounds = CGRect(origin: .zero, size: outputSize)
    let drawingBounds = CGRect(origin: .zero, size: canvasSize)
    let drawingScale = outputSize.width / canvasSize.width
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(
      size: outputSize,
      format: format
    )
    let composite = renderer.image { _ in
      sourceImage.draw(in: outputBounds)
      drawing.image(from: drawingBounds, scale: drawingScale).draw(
        in: outputBounds
      )
    }

    guard let outputData = composite.jpegData(compressionQuality: 0.95) else {
      throw PencilKitEditorError.renderFailed
    }

    let maximumPreviewDimension: CGFloat = 1280
    let previewScale = min(
      1,
      maximumPreviewDimension / max(outputSize.width, outputSize.height)
    )
    let previewSize = CGSize(
      width: max(1, (outputSize.width * previewScale).rounded()),
      height: max(1, (outputSize.height * previewScale).rounded())
    )
    let previewRenderer = UIGraphicsImageRenderer(
      size: previewSize,
      format: format
    )
    let preview = previewRenderer.image { _ in
      composite.draw(in: CGRect(origin: .zero, size: previewSize))
    }

    guard let previewData = preview.jpegData(compressionQuality: 0.82) else {
      throw PencilKitEditorError.renderFailed
    }

    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("naru-pencil-kit-output", isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    let uniqueName = "\(editorId)-\(UUID().uuidString)"
    let outputURL = directory.appendingPathComponent("\(uniqueName).jpg")
    let previewURL = directory.appendingPathComponent(
      "\(uniqueName)-preview.jpg"
    )
    try outputData.write(to: outputURL, options: .atomic)
    try previewData.write(to: previewURL, options: .atomic)

    return (outputURL, previewURL)
  }
}

private final class PencilKitEditorCanvasView: UIView, PKToolPickerObserver {
  init(
    frame: CGRect,
    session: PencilKitEditorSession,
    controlsVisible: Bool
  ) {
    self.session = session
    self.controlsVisible = controlsVisible
    super.init(frame: frame)

    backgroundColor = PencilKitEditorStyle.backgroundColor
    clipsToBounds = true

    imageView.image = session.sourceImage
    imageView.contentMode = .scaleToFill
    imageView.clipsToBounds = true
    addSubview(imageView)

    canvasView.backgroundColor = .clear
    canvasView.isOpaque = false
    canvasView.isScrollEnabled = false
    canvasView.alwaysBounceHorizontal = false
    canvasView.alwaysBounceVertical = false
    canvasView.drawingPolicy = .anyInput
    canvasView.drawing = session.drawing
    canvasView.overrideUserInterfaceStyle = .dark
    addSubview(canvasView)

    toolPicker.addObserver(canvasView)
    toolPicker.addObserver(self)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private let session: PencilKitEditorSession
  private let imageView = UIImageView()
  private let canvasView = PKCanvasView()
  private let toolPicker = PKToolPicker()
  private var wantsActive = false
  private var controlsVisible: Bool
  var onToolPickerFrameChanged: ((Double) -> Void)?

  deinit {
    persistDrawing()
    toolPicker.removeObserver(canvasView)
    toolPicker.removeObserver(self)
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()

    if window != nil, wantsActive, controlsVisible {
      showToolPicker()
    }
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    let imageSize = session.sourceImage.size
    guard imageSize.width > 0, imageSize.height > 0 else {
      return
    }

    let imageAspectRatio = imageSize.width / imageSize.height
    let viewportAspectRatio = bounds.width / bounds.height
    let sameOrientation = (imageAspectRatio >= 1) == (viewportAspectRatio >= 1)
    let useAspectFill = sameOrientation &&
      abs(log(imageAspectRatio / viewportAspectRatio)) <
        PencilKitEditorStyle.aspectFillLogRatioThreshold
    let widthScale = bounds.width / imageSize.width
    let heightScale = bounds.height / imageSize.height
    let scale = useAspectFill
      ? max(widthScale, heightScale)
      : min(widthScale, heightScale)
    let fittedSize = CGSize(
      width: imageSize.width * scale,
      height: imageSize.height * scale
    )
    let fittedFrame = CGRect(
      x: bounds.midX - fittedSize.width / 2,
      y: bounds.midY - fittedSize.height / 2,
      width: fittedSize.width,
      height: fittedSize.height
    ).integral

    if canvasView.bounds.size != fittedFrame.size,
      !session.drawing.strokes.isEmpty
    {
      let previousSize = canvasView.bounds.size
      if previousSize.width > 0, previousSize.height > 0 {
        let transform = CGAffineTransform(
          scaleX: fittedFrame.width / previousSize.width,
          y: fittedFrame.height / previousSize.height
        )
        canvasView.drawing.transform(using: transform)
      }
    }

    imageView.frame = fittedFrame
    canvasView.frame = fittedFrame
    session.canvasSize = fittedFrame.size
  }

  func setActive(_ active: Bool) {
    wantsActive = active

    if active, controlsVisible {
      showToolPicker()
    } else {
      persistDrawing()
      hideToolPicker(resignFirstResponder: !active)
    }
  }

  func setControlsVisible(_ visible: Bool) {
    controlsVisible = visible

    if visible, wantsActive {
      showToolPicker()
    } else {
      hideToolPicker(resignFirstResponder: false)
    }
  }

  func persistDrawing() {
    session.drawing = canvasView.drawing
    session.canvasSize = canvasView.bounds.size
  }

  private func showToolPicker() {
    guard window != nil else {
      return
    }

    toolPicker.setVisible(true, forFirstResponder: canvasView)
    canvasView.becomeFirstResponder()
    DispatchQueue.main.async { [weak self] in
      self?.reportToolPickerFrame()
    }
  }

  private func hideToolPicker(resignFirstResponder: Bool) {
    toolPicker.setVisible(false, forFirstResponder: canvasView)

    if resignFirstResponder {
      canvasView.resignFirstResponder()
    }
  }

  func toolPickerFramesObscuredDidChange(_ toolPicker: PKToolPicker) {
    reportToolPickerFrame()
  }

  private func reportToolPickerFrame() {
    guard toolPicker.isVisible, let window else {
      return
    }

    let frame = toolPicker.frameObscured(in: window)
    guard !frame.isEmpty else {
      return
    }

    onToolPickerFrameChanged?(Double(window.bounds.height - frame.midY))
  }
}
