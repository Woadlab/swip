import AVFoundation
import Foundation

public struct MediaInfo {
    public var duration: Double = 0
    public var naturalSize: CGSize = .zero
    public var frameRate: Double = 0
    public var hasAudio: Bool = false
    public var hasVideo: Bool = false
    public var estimatedBitrate: Double = 0
    public var channelCount: Int = 0
    public var sampleRate: Double = 0

    public static func load(_ url: URL) async -> MediaInfo {
        var info = MediaInfo()
        let asset = AVURLAsset(url: url)
        if let duration = try? await asset.load(.duration) {
            info.duration = CMTimeGetSeconds(duration)
        }
        if let tracks = try? await asset.load(.tracks) {
            for track in tracks {
                if track.mediaType == .video {
                    info.hasVideo = true
                    if let size = try? await track.load(.naturalSize),
                       let transform = try? await track.load(.preferredTransform) {
                        let rect = CGRect(origin: .zero, size: size).applying(transform)
                        info.naturalSize = CGSize(width: abs(rect.width), height: abs(rect.height))
                    }
                    if let fps = try? await track.load(.nominalFrameRate) { info.frameRate = Double(fps) }
                    if let rate = try? await track.load(.estimatedDataRate) { info.estimatedBitrate += Double(rate) }
                } else if track.mediaType == .audio {
                    info.hasAudio = true
                    if let rate = try? await track.load(.estimatedDataRate) { info.estimatedBitrate += Double(rate) }
                    if let descriptions = try? await track.load(.formatDescriptions),
                       let first = descriptions.first,
                       let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(first) {
                        info.channelCount = Int(asbd.pointee.mChannelsPerFrame)
                        info.sampleRate = asbd.pointee.mSampleRate
                    }
                }
            }
        }
        if info.duration == 0 || (!info.hasAudio && !info.hasVideo) {
            if let probed = await FFmpeg.probeDuration(url) { info.duration = probed }
        }
        return info
    }

    public static func isNativelyReadable(_ url: URL) async -> Bool {
        let asset = AVURLAsset(url: url)
        guard let readable = try? await asset.load(.isReadable), readable else { return false }
        let tracks = (try? await asset.load(.tracks)) ?? []
        return !tracks.isEmpty
    }
}

public enum FileSizeFormatter {
    public static func string(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    public static func size(of url: URL) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
    }
}

public enum TimeFormatter {
    public static func clock(_ seconds: Double, fractionDigits: Int = 2) -> String {
        let clamped = max(0, seconds)
        let minutes = Int(clamped) / 60
        let secs = clamped - Double(minutes * 60)
        return String(format: "%d:%0\(3 + fractionDigits).\(fractionDigits)f", minutes, secs)
    }

    public static func parseClock(_ text: String) -> Double? {
        let parts = text.split(separator: ":").map { String($0) }
        guard !parts.isEmpty, parts.count <= 3 else { return Double(text) }
        var total = 0.0
        for part in parts {
            guard let value = Double(part) else { return nil }
            total = total * 60 + value
        }
        return total
    }
}
