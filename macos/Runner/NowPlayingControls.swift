import MediaPlayer
import AppKit
import AVFoundation
import ImageIO

/// 将播放器的歌曲快照发布到控制中心，系统操作仍由 Flutter 播放器执行。
final class NowPlayingControls {
  private let center = MPNowPlayingInfoCenter.default()
  private let commands = MPRemoteCommandCenter.shared()
  private let send: (String, Any?) -> Void
  private var targets: [(MPRemoteCommand, Any)] = []
  private var sequence = 0
  private var artworkTrack: String?
  private var artworkSource: String?
  private var artwork: MPMediaItemArtwork?
  private var artworkTask: Task<Void, Never>?

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
    updateArtwork(track)
    if let artwork = artwork { info[MPMediaItemPropertyArtwork] = artwork }
    commands.changePlaybackPositionCommand.isEnabled = duration > 0
    center.nowPlayingInfo = info
    center.playbackState = playing ? .playing : .paused
  }

  func clear() {
    resetArtwork()
    guard !targets.isEmpty else { return }
    for (command, target) in targets {
      command.removeTarget(target)
      command.isEnabled = false
    }
    targets.removeAll()
    center.playbackState = .stopped
    center.nowPlayingInfo = nil
  }

  private func resetArtwork() {
    artworkTask?.cancel()
    artworkTask = nil
    artworkTrack = nil
    artworkSource = nil
    artwork = nil
  }

  private func updateArtwork(_ track: [String: Any]) {
    let id = track["songId"] as? String ?? ""
    if artworkTrack != id {
      resetArtwork()
      artworkTrack = id
    }
    guard artwork == nil else { return }
    let source = track["artUrl"] as? String ?? ""
    let audioPath = (track["fallbackFilePath"] as? String)
      ?? (source.hasPrefix("local://") ? String(source.dropFirst("local://".count)) : "")
    guard !source.isEmpty || !audioPath.isEmpty else { return }
    if artworkTask != nil {
      // 本地缓存路径到达时优先采用；后续进度更新不能用网络请求挤掉它。
      guard source != artworkSource, source.hasPrefix("file://") else { return }
      artworkTask?.cancel()
    }
    artworkSource = source
    artworkTask = Task.detached(priority: .utility) { [weak self] in
      var data: Data?
      if let url = source.hasPrefix("/") ? URL(fileURLWithPath: source) : URL(string: source) {
        if url.isFileURL {
          data = try? Data(contentsOf: url)
        } else if url.scheme == "https" || url.scheme == "http" {
          var address = URLComponents(url: url, resolvingAgainstBaseURL: false)
          if address?.scheme == "http", address?.host?.lowercased().hasSuffix(".kugou.com") == true {
            address?.scheme = "https"
          }
          if let (bytes, response) = try? await URLSession.shared.data(from: address?.url ?? url),
             let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
            data = bytes
          }
        }
      }
      if data == nil && !audioPath.isEmpty && !Task.isCancelled {
        let url = audioPath.hasPrefix("/") ? URL(fileURLWithPath: audioPath) : URL(string: audioPath)
        if let url = url, url.isFileURL {
          let items = AVURLAsset(url: url).commonMetadata
          data = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: .commonIdentifierArtwork).first?.dataValue
        }
      }
      let image = data.flatMap { bytes -> CGImage? in
        guard let source = CGImageSourceCreateWithData(bytes as CFData, nil) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceCreateThumbnailWithTransform: true,
          kCGImageSourceThumbnailMaxPixelSize: 640,
        ] as CFDictionary)
      }
      await MainActor.run { [weak self] in
        guard let self = self, !Task.isCancelled, self.artworkTrack == id,
              self.artworkSource == source else { return }
        self.artworkTask = nil
        guard let image = image, var info = self.center.nowPlayingInfo else { return }
        let cover = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        let item = MPMediaItemArtwork(boundsSize: cover.size) { _ in cover }
        self.artwork = item
        info[MPMediaItemPropertyArtwork] = item
        self.center.nowPlayingInfo = info
      }
    }
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
