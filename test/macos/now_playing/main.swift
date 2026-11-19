import AppKit
import MediaPlayer

// 构建机上核对应用写入的系统媒体会话；控制中心的按钮点击由真机验收。
_ = NSApplication.shared
let controls = NowPlayingControls { _, _ in }
let center = MPNowPlayingInfoCenter.default()
let commands = MPRemoteCommandCenter.shared()
var song: [String: Any] = [
  "title": "测试曲目", "artist": "测试歌手", "isPlaying": true,
  "position": 12500, "duration": 180000, "playbackRate": 1.25,
]
let coverURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 4,
  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
  bytesPerRow: 0, bitsPerPixel: 0)!
try bitmap.representation(using: .png, properties: [:])!.write(to: coverURL)
defer { try? FileManager.default.removeItem(at: coverURL) }
song["songId"] = "fixture-a"
song["artUrl"] = coverURL.absoluteString
controls.update(song)
let deadline = Date().addingTimeInterval(5)
while center.nowPlayingInfo?[MPMediaItemPropertyArtwork] == nil && Date() < deadline {
  RunLoop.main.run(until: Date().addingTimeInterval(0.02))
}
precondition(center.nowPlayingInfo?[MPMediaItemPropertyArtwork] is MPMediaItemArtwork)
precondition(center.nowPlayingInfo?[MPMediaItemPropertyTitle] as? String == "测试曲目")
precondition(center.nowPlayingInfo?[MPMediaItemPropertyPlaybackDuration] as? Double == 180)
precondition(center.nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Double == 1.25)
precondition(commands.changePlaybackPositionCommand.isEnabled)
song["isPlaying"] = false
controls.update(song)
precondition(center.playbackState == .paused)
precondition(center.nowPlayingInfo?[MPMediaItemPropertyArtwork] is MPMediaItemArtwork)
song["songId"] = "fixture-b"
song.removeValue(forKey: "artUrl")
controls.update(song)
precondition(center.nowPlayingInfo?[MPMediaItemPropertyArtwork] == nil)
controls.clear()
precondition(center.nowPlayingInfo == nil && !commands.playCommand.isEnabled)
