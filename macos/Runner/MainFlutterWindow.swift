import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var playbackControls: NowPlayingControls?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
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
