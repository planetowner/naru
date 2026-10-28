import Flutter
import UIKit

final class PhotoCropBridge: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  static func register(with registrar: FlutterPluginRegistrar) {
    registrar.register(PhotoCropBridge(messenger: registrar.messenger()), withId: "naru/photo-crop")
  }

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
    -> FlutterPlatformView
  {
    PhotoCropPlatformView(frame: frame, viewId: viewId, arguments: args, messenger: messenger)
  }
}

private final class PhotoCropPlatformView: NSObject, FlutterPlatformView {
  private let cropView: SquarePhotoCropView?
  private let placeholder = UIView()
  private let channel: FlutterMethodChannel

  init(frame: CGRect, viewId: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    let bytes = (arguments as? [String: Any])?["bytes"] as? FlutterStandardTypedData
    // 앨범과 카메라가 같은 메모리 입력을 사용해 임시 파일 없이 사진을 바꿔요.
    cropView = bytes.flatMap { UIImage(data: $0.data) }.map {
      SquarePhotoCropView(frame: frame, image: $0)
    }
    channel = FlutterMethodChannel(name: "naru/photo-crop/\(viewId)", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let cropView = self?.cropView else {
        result(FlutterError(code: "photo_unavailable", message: "Cannot decode photo.", details: nil))
        return
      }
      switch call.method {
      case "ready":
        result(nil)
      case "crop":
        guard let data = cropView.croppedImage()?.jpegData(compressionQuality: 0.92) else {
          result(FlutterError(code: "crop_failed", message: "Cannot crop photo.", details: nil))
          return
        }
        // 결과를 메모리로 돌려줘서 크롭용 임시 파일을 남기지 않아요.
        result(FlutterStandardTypedData(bytes: data))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  func view() -> UIView { cropView ?? placeholder }
}

// 사진 선택과 카메라 촬영 모두 같은 정사각형 영역에서 이동·확대해요.
final class SquarePhotoCropView: UIScrollView, UIScrollViewDelegate {
  private let image: UIImage
  private let imageView: UIImageView
  private var viewportSize = CGSize.zero
  private var selectionCenter: CGPoint

  init(frame: CGRect, image: UIImage) {
    self.image = image
    selectionCenter = CGPoint(x: image.size.width / 2, y: image.size.height / 2)
    imageView = UIImageView(image: image)
    super.init(frame: frame)
    imageView.frame = CGRect(origin: .zero, size: image.size)
    addSubview(imageView)
    delegate = self
    clipsToBounds = true
    bounces = false
    bouncesZoom = false
    showsHorizontalScrollIndicator = false
    showsVerticalScrollIndicator = false
    contentInsetAdjustmentBehavior = .never
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func layoutSubviews() {
    super.layoutSubviews()
    guard bounds.width > 0, bounds.height > 0, bounds.size != viewportSize else { return }
    // 화면이 커지면 UIKit이 스크롤 위치를 먼저 줄여요. 변경 전 사진 중심을 유지해요.
    let center = selectionCenter
    let relativeZoom = viewportSize == .zero ? 1 : zoomScale / minimumZoomScale
    viewportSize = bounds.size
    let fillScale = max(bounds.width / image.size.width, bounds.height / image.size.height)
    minimumZoomScale = fillScale
    maximumZoomScale = fillScale * 4
    zoomScale = fillScale * relativeZoom
    contentOffset = CGPoint(
      x: min(max(0, center.x * zoomScale - bounds.width / 2), max(0, contentSize.width - bounds.width)),
      y: min(max(0, center.y * zoomScale - bounds.height / 2), max(0, contentSize.height - bounds.height))
    )
  }

  func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    guard bounds.size == viewportSize else { return }
    selectionCenter = CGPoint(
      x: (contentOffset.x + bounds.width / 2) / zoomScale,
      y: (contentOffset.y + bounds.height / 2) / zoomScale
    )
  }

  func scrollViewDidZoom(_ scrollView: UIScrollView) {
    scrollViewDidScroll(scrollView)
  }

  func croppedImage() -> UIImage? {
    layoutIfNeeded()
    guard bounds.width > 0, bounds.height > 0 else { return nil }
    let visible = imageView.convert(bounds, from: self)
    let side = min(visible.width, visible.height, image.size.width, image.size.height)
    let origin = CGPoint(
      x: min(max(0, visible.minX), image.size.width - side),
      y: min(max(0, visible.minY), image.size.height - side)
    )
    let pixels = max(1, floor(side * image.scale))
    let outputSize = CGSize(width: pixels, height: pixels)
    let scale = pixels / side
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    // UIImage.draw가 카메라의 EXIF 회전·반전을 적용하므로 보이는 방향 그대로 저장돼요.
    return UIGraphicsImageRenderer(size: outputSize, format: format).image { context in
      UIColor.white.setFill()
      context.fill(CGRect(origin: .zero, size: outputSize))
      image.draw(in: CGRect(
        x: -origin.x * scale, y: -origin.y * scale,
        width: image.size.width * scale, height: image.size.height * scale
      ))
    }
  }
}
