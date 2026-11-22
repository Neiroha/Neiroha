import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var mediaSession: MacMediaSession?
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Blend the title bar into the app: Flutter draws under it and the
    // traffic lights float over the sidebar (the sidebar leaves the top 28 pt
    // free; page headers move the window). The background matches AppTheme.sidebarBg so no white
    // strip shows while the first frame renders.
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    self.titlebarSeparatorStyle = .none
    self.backgroundColor = NSColor(
      srgbRed: 0x12 / 255.0, green: 0x12 / 255.0, blue: 0x1A / 255.0, alpha: 1)
    // Set before sizing: changing the style mask after the autosaved frame
    // is restored keeps the old content size and shrinks the window by the
    // title bar height on every launch.
    // Same default size as the Windows / Linux runners, centered on first
    // launch; macOS restores the user's frame on later launches.
    self.setContentSize(NSSize(width: 1280, height: 720))
    self.center()
    self.setFrameAutosaveName("NeirohaMainWindow")

    RegisterGeneratedPlugins(registry: flutterViewController)
    mediaSession = MacMediaSession(messenger: flutterViewController.engine.binaryMessenger)
    self.isReleasedWhenClosed = false
    (NSApp.delegate as? AppDelegate)?.mainWindow = self

    super.awakeFromNib()
  }
}
