import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var playbackControls: NowPlayingControls?
  private var titlebarChannel: FlutterMethodChannel?

  private var titlebarInset: CGFloat {
    guard !styleMask.contains(.fullScreen), let view = contentView else { return 0 }
    return max(0, view.convert(view.bounds, to: nil).maxY - contentLayoutRect.maxY)
  }

  @objc private func fullscreenChanged(_ notification: Notification) {
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
