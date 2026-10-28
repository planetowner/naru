import Flutter
import QuickLook
import UIKit

final class MediaFileBridge: NSObject, FlutterPlugin {
  private static let channelName = "naru/media-file"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(MediaFileBridge(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "share-file" || call.method == "preview-file" else {
      result(FlutterMethodNotImplemented)
      return
    }

    guard
      let arguments = call.arguments as? [String: Any],
      let path = arguments["path"] as? String,
      !path.isEmpty,
      FileManager.default.fileExists(atPath: path)
    else {
      result(
        FlutterError(
          code: "media_unavailable",
          message: "The media file is unavailable.",
          details: nil
        )
      )
      return
    }

    Task { @MainActor in
      guard let presenter = Self.topViewController() else {
        result(
          FlutterError(
            code: "presentation_unavailable",
            message: "The file action could not be presented.",
            details: nil
          )
        )
        return
      }

      let fileURL = URL(fileURLWithPath: path)
      if call.method == "preview-file" {
        let controller = FilePreviewController(fileURL: fileURL)
        controller.modalPresentationStyle = .fullScreen
        presenter.present(controller, animated: true) {
          result(nil)
        }
        return
      }

      let controller = UIActivityViewController(
        activityItems: [fileURL],
        applicationActivities: nil
      )
      controller.completionWithItemsHandler = { _, _, _, error in
        if let error {
          result(
            FlutterError(
              code: "share_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        } else {
          result(nil)
        }
      }

      if let popover = controller.popoverPresentationController {
        popover.sourceView = presenter.view
        popover.sourceRect = CGRect(
          x: presenter.view.bounds.midX,
          y: presenter.view.bounds.maxY,
          width: 0,
          height: 0
        )
      }

      presenter.present(controller, animated: true)
    }
  }

  @MainActor
  private static func topViewController() -> UIViewController? {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
    let root = windows.first(where: \.isKeyWindow)?.rootViewController
      ?? windows.first?.rootViewController

    return topViewController(from: root)
  }

  @MainActor
  private static func topViewController(
    from root: UIViewController?
  ) -> UIViewController? {
    if let presented = root?.presentedViewController {
      return topViewController(from: presented)
    }
    if let navigation = root as? UINavigationController {
      return topViewController(from: navigation.visibleViewController)
    }
    if let tab = root as? UITabBarController {
      return topViewController(from: tab.selectedViewController)
    }
    return root
  }
}

private final class FilePreviewController: QLPreviewController, QLPreviewControllerDataSource {
  private let fileURL: URL

  init(fileURL: URL) {
    self.fileURL = fileURL
    super.init(nibName: nil, bundle: nil)
    // 파일 형식별 보기와 재생 UI는 Quick Look이 제공해요.
    dataSource = self
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
    return 1
  }

  func previewController(
    _ controller: QLPreviewController,
    previewItemAt index: Int
  ) -> QLPreviewItem {
    return fileURL as NSURL
  }
}
