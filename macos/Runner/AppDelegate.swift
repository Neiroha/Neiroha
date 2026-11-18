import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  var mainWindow: MainFlutterWindow?
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // Closing the window keeps narration and the local API alive. Quit remains
    // an explicit application action; the Dock can reopen the same window.
    return false
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      mainWindow?.makeKeyAndOrderFront(nil)
      sender.activate(ignoringOtherApps: true)
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
