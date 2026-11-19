import MediaPlayer

/// 将播放器的歌曲快照发布到控制中心，系统操作仍由 Flutter 播放器执行。
final class NowPlayingControls {
  private let center = MPNowPlayingInfoCenter.default()
  private let commands = MPRemoteCommandCenter.shared()
  private let send: (String, Any?) -> Void
  private var targets: [(MPRemoteCommand, Any)] = []
  private var sequence = 0

  init(send: @escaping (String, Any?) -> Void) {
    self.send = send
  }

  func update(_ track: [String: Any]) {
    guard let title = track["title"] as? String,
          let playing = track["isPlaying"] as? Bool else { return }
    // 冷启动仅恢复队列时，等到真正播放后再向系统注册。
    if targets.isEmpty {
      guard playing else { return }
      registerCommands()
    }
    let duration = (track["duration"] as? NSNumber)?.doubleValue ?? 0
    let position = (track["position"] as? NSNumber)?.doubleValue ?? 0
    var info: [String: Any] = [
      MPMediaItemPropertyTitle: title,
      MPMediaItemPropertyArtist: track["artist"] as? String ?? "",
      MPMediaItemPropertyAlbumTitle: track["album"] as? String ?? "",
      MPNowPlayingInfoPropertyElapsedPlaybackTime: max(0, position) / 1000,
      MPNowPlayingInfoPropertyPlaybackRate: playing ? (track["playbackRate"] as? Double ?? 1) : 0,
      MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
    ]
    if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration / 1000 }
    commands.changePlaybackPositionCommand.isEnabled = duration > 0
    center.nowPlayingInfo = info
    center.playbackState = playing ? .playing : .paused
  }

  func clear() {
    guard !targets.isEmpty else { return }
    for (command, target) in targets {
      command.removeTarget(target)
      command.isEnabled = false
    }
    targets.removeAll()
    center.playbackState = .stopped
    center.nowPlayingInfo = nil
  }

  private func registerCommands() {
    let actions: [(MPRemoteCommand, String)] = [
      (commands.playCommand, "play"), (commands.pauseCommand, "pause"),
      (commands.togglePlayPauseCommand, "togglePlayPause"),
      (commands.nextTrackCommand, "next"), (commands.previousTrackCommand, "previous"),
      (commands.changePlaybackPositionCommand, "seekTo"),
    ]
    for (command, method) in actions {
      command.isEnabled = true
      let target = command.addTarget { [weak self] event in
        guard let self = self else { return .commandFailed }
        let seek = (event as? MPChangePlaybackPositionCommandEvent)?.positionTime
        if method == "seekTo" && seek == nil { return .commandFailed }
        DispatchQueue.main.async {
          guard !self.targets.isEmpty else { return }
          if let seek = seek {
            self.send(method, Int((seek * 1000).rounded()))
          } else {
            self.sequence += 1
            self.send(method, ["commandId": self.sequence])
          }
        }
        return .success
      }
      targets.append((command, target))
    }
  }

  deinit { clear() }
}
