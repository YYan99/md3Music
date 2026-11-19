import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var playbackControls: NowPlayingControls?
  private var titlebarChannel: FlutterMethodChannel?

  // 以窗口左上角为锚点，缩放或重新布局时不会反复叠加偏移量。
  private func positionWindowButtons() {
    guard !styleMask.contains(.fullScreen), let view = contentView,
          let close = standardWindowButton(.closeButton),
          let group = close.superview, group.window === self else { return }
    let rect = group.convert(close.frame, to: nil)
    let topLeft = view.convert(view.bounds, to: nil)
    let target = group.convert(NSPoint(x: topLeft.minX + 14,
                                       y: topLeft.maxY - 12 - rect.height), from: nil)
    let origin = group.convert(NSPoint(x: rect.minX, y: rect.minY), from: nil)
    let dx = target.x - origin.x
    let dy = target.y - origin.y
    guard abs(dx) > 0.1 || abs(dy) > 0.1 else { return }
    for kind: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
      guard let button = standardWindowButton(kind), button.superview === group else { continue }
      button.setFrameOrigin(NSPoint(x: button.frame.minX + dx, y: button.frame.minY + dy))
    }
  }

  override func update() {
    super.update()
    positionWindowButtons()
  }

  private var titlebarInset: CGFloat {
    guard !styleMask.contains(.fullScreen), let view = contentView else { return 0 }
    let top = view.convert(view.bounds, to: nil).maxY
    let layoutInset = top - contentLayoutRect.maxY
    if let button = standardWindowButton(.closeButton), button.window === self {
      let buttonInset = top - button.convert(button.bounds, to: nil).minY
      return max(layoutInset, buttonInset)
    }
    return max(0, layoutInset)
  }

  @objc private func fullscreenChanged(_ notification: Notification) {
    positionWindowButtons()
    titlebarChannel?.invokeMethod("insetChanged", arguments: Double(titlebarInset))
  }

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    styleMask.insert(.fullSizeContentView)
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    titlebarSeparatorStyle = .none
    self.setFrame(windowFrame, display: true)
    positionWindowButtons()

    RegisterGeneratedPlugins(registry: flutterViewController)
    let titlebar = FlutterMethodChannel(
      name: "md3music/macos_titlebar", binaryMessenger: flutterViewController.engine.binaryMessenger)
    titlebarChannel = titlebar
    titlebar.setMethodCallHandler { [weak self] call, result in
      guard call.method == "getInset" else { result(FlutterMethodNotImplemented); return }
      result(Double(self?.titlebarInset ?? 0))
    }
    for name in [NSWindow.didEnterFullScreenNotification, NSWindow.didExitFullScreenNotification] {
      NotificationCenter.default.addObserver(self, selector: #selector(fullscreenChanged(_:)),
                                             name: name, object: self)
    }
    let channel = FlutterMethodChannel(
      name: "com.md3music.md3music/floating_lyric",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    let controls = NowPlayingControls { method, arguments in
      channel.invokeMethod(method, arguments: arguments)
    }
    playbackControls = controls
    channel.setMethodCallHandler { [weak controls] call, result in
      switch call.method {
      case "updateNotification":
        if let track = call.arguments as? [String: Any] { controls?.update(track) }
      case "hideNotification":
        controls?.clear()
      default:
        result(FlutterMethodNotImplemented)
        return
      }
      result(nil)
    }

    super.awakeFromNib()
  }
}
