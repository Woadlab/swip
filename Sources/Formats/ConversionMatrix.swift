import Foundation

public enum ConversionMatrix {
    public static func targets(for source: FileFormat) -> [FileFormat] {
        switch source.category {
        case .image:
            return orderedImageTargets(for: source)
        case .video:
            return orderedVideoTargets(for: source)
        case .audio:
            return orderedAudioTargets(for: source)
        case .document:
            return orderedDocumentTargets(for: source)
        case .spreadsheet:
            let list: [FileFormat] = [.csv, .tsv, .pdf, .xlsx]
            return list.filter { $0 != source }
        case .subtitle:
            let list: [FileFormat] = [.srt, .vtt, .txt]
            return list.filter { $0 != source }
        case .archive:
            let list: [FileFormat] = [.zip, .tar, .gz]
            return list.filter { $0 != source }
        }
    }

    /// Consistent 8-petal cardinal anchoring for image conversions:
    /// - North     (0° / ↑):   WEBP (Modern Web)
    /// - NorthEast (45° / ↗):  PNG  (Lossless Transparent)
    /// - East      (90° / →):  JPG  (Standard Photo)
    /// - SouthEast (135° / ↘): PDF  (Document / Sharing)
    /// - South     (180° / ↓): AVIF (Next-Gen High Efficiency)
    /// - SouthWest (225° / ↙): TIFF (Pro High-Depth)
    /// - West      (270° / ←): HEIC (Apple Photo)
    /// - NorthWest (315° / ↖): DOCX (Word Document)
    private static func orderedImageTargets(for source: FileFormat) -> [FileFormat] {
        var slots: [FileFormat] = [.webp, .png, .jpg, .pdf, .avif, .tiff, .heic, .docx]
        switch source {
        case .webp:
            // Swap North with secondary web format AVIF; replace South with BMP
            slots[0] = .avif
            slots[4] = .bmp
        case .avif:
            slots[4] = .bmp
        case .png:
            // Swap NorthEast with secondary lossless TIFF; replace SouthWest with BMP
            slots[1] = .tiff
            slots[5] = .bmp
        case .tiff:
            slots[5] = .bmp
        case .jpg:
            // Swap East with secondary photo HEIC; replace West with BMP
            slots[2] = .heic
            slots[6] = .bmp
        case .heic:
            slots[6] = .bmp
        case .svg:
            // Vector source converts cleanly to standard raster formats
            slots = [.png, .webp, .jpg, .pdf, .avif, .tiff, .bmp, .docx]
        case .bmp:
            break
        default:
            if let idx = slots.firstIndex(of: source) {
                slots[idx] = .bmp
            }
        }
        return slots
    }

    /// Consistent 8-petal cardinal anchoring for video conversions:
    /// - North     (0° / ↑):   MP4  (Universal H.264)
    /// - NorthEast (45° / ↗):  MOV  (QuickTime / ProRes)
    /// - East      (90° / →):  WEBM (Web Streaming)
    /// - SouthEast (135° / ↘): GIF  (Animated Loop)
    /// - South     (180° / ↓): MP3  (Extract Audio Track)
    /// - SouthWest (225° / ↙): MKV  (Master Container)
    /// - West      (270° / ←): AVI  (Legacy Media)
    /// - NorthWest (315° / ↖): WMV  (Windows Media)
    private static func orderedVideoTargets(for source: FileFormat) -> [FileFormat] {
        var slots: [FileFormat] = [.mp4, .mov, .webm, .gif, .mp3, .mkv, .avi, .wmv]
        switch source {
        case .mp4:
            // Swap North with MOV; fill NorthEast with MKV
            slots[0] = .mov
            slots[1] = .mkv
        case .mov:
            // Swap NorthEast with MP4; fill North with MKV
            slots[1] = .mp4
            slots[0] = .mkv
        case .webm:
            slots[2] = .mkv
        case .gif:
            // GIF input: prioritize video containers
            slots = [.mp4, .mov, .webm, .mkv, .avi, .wmv]
            return slots
        case .mkv:
            slots[5] = .mp4
        case .avi:
            slots[6] = .mp4
        case .wmv:
            slots[7] = .mp4
        default:
            if let idx = slots.firstIndex(of: source) {
                slots[idx] = .mkv
            }
        }
        return slots
    }

    /// Consistent 8-petal cardinal anchoring for audio conversions:
    /// - North     (0° / ↑):   MP3  (Universal Audio)
    /// - NorthEast (45° / ↗):  M4A  (Apple Native AAC/ALAC)
    /// - East      (90° / →):  WAV  (Uncompressed Studio PCM)
    /// - SouthEast (135° / ↘): FLAC (Lossless Hi-Fi)
    /// - South     (180° / ↓): OGG  (Open Vorbis)
    /// - SouthWest (225° / ↙): OPUS (Next-Gen VoIP / Stream)
    /// - West      (270° / ←): AIFF (Apple Uncompressed)
    /// - NorthWest (315° / ↖): WMA  (Windows Audio)
    private static func orderedAudioTargets(for source: FileFormat) -> [FileFormat] {
        var slots: [FileFormat] = [.mp3, .m4a, .wav, .flac, .ogg, .opus, .aiff, .wma]
        switch source {
        case .mp3:
            // Swap North with Apple M4A; fill NorthEast with AIFF
            slots[0] = .m4a
            slots[1] = .aiff
        case .m4a:
            slots[1] = .mp3
            slots[0] = .aiff
        case .wav:
            slots[2] = .aiff
        case .flac:
            slots[3] = .aiff
        case .ogg:
            slots[4] = .aiff
        case .opus:
            slots[5] = .aiff
        case .aiff:
            slots[6] = .wav
        case .wma:
            slots[7] = .wav
        default:
            if let idx = slots.firstIndex(of: source) {
                slots[idx] = .aiff
            }
        }
        return slots
    }

    /// Consistent cardinal anchoring for document conversions:
    private static func orderedDocumentTargets(for source: FileFormat) -> [FileFormat] {
        switch source {
        case .pdf:
            return [.docx, .txt, .jpg, .png, .html, .rtf]
        case .docx:
            return [.pdf, .txt, .html, .rtf]
        case .txt:
            return [.pdf, .docx, .html, .rtf, .jpg, .png, .srt, .vtt]
        case .html:
            return [.pdf, .docx, .txt, .rtf]
        case .rtf:
            return [.pdf, .docx, .txt, .html]
        default:
            return [.pdf, .docx, .txt].filter { $0 != source }
        }
    }

    public static func targets(for sources: [FileFormat]) -> [FileFormat] {
        guard let first = sources.first else { return [] }
        var common = targets(for: first)
        for source in sources.dropFirst() {
            let next = Set(targets(for: source))
            common = common.filter { next.contains($0) }
        }
        return common
    }

    public static var totalConversions: Int {
        FileFormat.allCases.reduce(0) { $0 + targets(for: $1).count }
    }

    public static func outputURL(for source: URL, target: FileFormat, in directory: URL, existing: Set<String> = []) -> URL {
        let base = strippedBaseName(source.lastPathComponent)
        var candidate = "\(base).\(target.fileExtension)"
        var counter = 2
        let fm = FileManager.default
        while existing.contains(candidate) || fm.fileExists(atPath: directory.appendingPathComponent(candidate).path) {
            candidate = "\(base) \(counter).\(target.fileExtension)"
            counter += 1
        }
        return directory.appendingPathComponent(candidate)
    }

    public static func uniqueURL(directory: URL, baseName: String, suffix: String, ext: String) -> URL {
        let fm = FileManager.default
        var candidate = suffix.isEmpty ? "\(baseName).\(ext)" : "\(baseName) \(suffix).\(ext)"
        var counter = 2
        while fm.fileExists(atPath: directory.appendingPathComponent(candidate).path) {
            candidate = suffix.isEmpty ? "\(baseName) \(counter).\(ext)" : "\(baseName) \(suffix) \(counter).\(ext)"
            counter += 1
        }
        return directory.appendingPathComponent(candidate)
    }

    public static func uniqueDirectory(directory: URL, name: String) -> URL {
        let fm = FileManager.default
        var candidate = name
        var counter = 2
        while fm.fileExists(atPath: directory.appendingPathComponent(candidate).path) {
            candidate = "\(name) \(counter)"
            counter += 1
        }
        return directory.appendingPathComponent(candidate)
    }

    public static func strippedBaseName(_ fileName: String) -> String {
        let lower = fileName.lowercased()
        if lower.hasSuffix(".tar.gz") { return String(fileName.dropLast(7)) }
        if lower.hasSuffix(".tgz") { return String(fileName.dropLast(4)) }
        guard let dot = fileName.lastIndex(of: "."), dot != fileName.startIndex else { return fileName }
        return String(fileName[..<dot])
    }
}
