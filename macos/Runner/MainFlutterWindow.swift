import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Same default size as the Windows / Linux runners, centered on first
    // launch; macOS restores the user's frame on later launches.
    self.setContentSize(NSSize(width: 1280, height: 720))
    self.center()
    self.setFrameAutosaveName("NeirohaMainWindow")

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
