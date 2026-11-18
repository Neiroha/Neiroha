import Cocoa
import FlutterMacOS
import MediaPlayer

/// Only transports system media controls; Dart's shared player owns playback.
final class MacMediaSession {
  private let channel: FlutterMethodChannel
  private var targets: [(MPRemoteCommand, Any)] = []
  private var active = false

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "neiroha/macos_media_session", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "startOrUpdateNovelSession":
        self.update(call.arguments as? [String: Any] ?? [:])
        result(nil)
      case "stopNovelSession":
        self.stop()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    let commands = MPRemoteCommandCenter.shared()
    bind(commands.playCommand, "play")
    bind(commands.pauseCommand, "pause")
    bind(commands.togglePlayPauseCommand, "toggle")
    bind(commands.previousTrackCommand, "previous")
    bind(commands.nextTrackCommand, "next")
    bind(commands.stopCommand, "stop")
    setEnabled(false)
  }

  private func bind(_ command: MPRemoteCommand, _ action: String) {
    let target = command.addTarget { [weak self] _ in
      guard let self = self, self.active else { return .noSuchContent }
      DispatchQueue.main.async { [weak self] in
        self?.channel.invokeMethod("control", arguments: action)
      }
      return .success
    }
    targets.append((command, target))
  }

  private func setEnabled(_ value: Bool) {
    for (command, _) in targets { command.isEnabled = value }
  }

  private func update(_ args: [String: Any]) {
    active = true
    setEnabled(true)
    let playing = args["isPlaying"] as? Bool ?? false
    var info: [String: Any] = [
      MPMediaItemPropertyTitle: args["title"] as? String ?? "Neiroha",
      MPMediaItemPropertyArtist: args["subtitle"] as? String ?? "",
      MPNowPlayingInfoPropertyElapsedPlaybackTime: (args["positionMs"] as? NSNumber)?.doubleValue ?? 0,
      MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0,
      MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
    ]
    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] =
      ((args["positionMs"] as? NSNumber)?.doubleValue ?? 0) / 1000
    let duration = ((args["durationMs"] as? NSNumber)?.doubleValue ?? 0) / 1000
    if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    MPNowPlayingInfoCenter.default().playbackState = playing ? .playing : .paused
  }

  func stop() {
    active = false
    setEnabled(false)
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    MPNowPlayingInfoCenter.default().playbackState = .stopped
  }

  deinit {
    for (command, target) in targets { command.removeTarget(target) }
    channel.setMethodCallHandler(nil)
  }
}
