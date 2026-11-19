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
controls.update(song)
precondition(center.nowPlayingInfo?[MPMediaItemPropertyTitle] as? String == "测试曲目")
precondition(center.nowPlayingInfo?[MPMediaItemPropertyPlaybackDuration] as? Double == 180)
precondition(center.nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Double == 1.25)
precondition(commands.changePlaybackPositionCommand.isEnabled)
song["isPlaying"] = false
controls.update(song)
precondition(center.playbackState == .paused)
controls.clear()
precondition(center.nowPlayingInfo == nil && !commands.playCommand.isEnabled)
