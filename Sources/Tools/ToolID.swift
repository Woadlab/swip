import Foundation

public enum ToolArity {
    case single
    case multiple
    case any
}

public enum ToolID: String, CaseIterable, Identifiable, Hashable {
    case compress
    case editMetadata
    case editImage
    case frameImage
    case cropImage
    case redactImage
    case resizeImage
    case rotateImage
    case createPDF
    case createCollage
    case trimVideo
    case cropVideo
    case changeVideoSpeed
    case joinVideos
    case videoSnapshots
    case splitVideo
    case redactVideo
    case normalizeAudio
    case audioToVideo
    case trimAudio
    case audioChannels
    case redactAudio
    case mergePDF
    case organizePDF
    case splitPDF
    case extractArchive

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .compress: return "Compress"
        case .editMetadata: return "Edit Metadata"
        case .editImage: return "Edit Photo"
        case .frameImage: return "Add Background"
        case .cropImage: return "Crop Image"
        case .redactImage: return "Redact Photo"
        case .resizeImage: return "Resize Images"
        case .rotateImage: return "Rotate & Flip"
        case .createPDF: return "Create PDF"
        case .createCollage: return "Create Collage"
        case .trimVideo: return "Trim Video"
        case .cropVideo: return "Crop Video"
        case .changeVideoSpeed: return "Change Video Speed"
        case .joinVideos: return "Join Videos"
        case .videoSnapshots: return "Save Video Frames"
        case .splitVideo: return "Split Video"
        case .redactVideo: return "Redact Video"
        case .normalizeAudio: return "Normalize Volume"
        case .audioToVideo: return "Audio Visualizer"
        case .trimAudio: return "Trim Audio"
        case .audioChannels: return "Audio Channels"
        case .redactAudio: return "Bleep Audio"
        case .mergePDF: return "Merge PDFs"
        case .organizePDF: return "Organize PDF Pages"
        case .splitPDF: return "Split PDF"
        case .extractArchive: return "Extract Archive"
        }
    }

    public var progressTitle: String {
        switch self {
        case .compress: return "Compressing"
        case .editMetadata: return "Editing metadata"
        case .editImage: return "Editing photo"
        case .frameImage: return "Adding background"
        case .cropImage, .cropVideo: return "Cropping"
        case .redactImage, .redactVideo: return "Redacting"
        case .resizeImage: return "Resizing"
        case .rotateImage: return "Rotating"
        case .createPDF: return "Creating PDF"
        case .createCollage: return "Creating collage"
        case .trimVideo, .trimAudio: return "Trimming"
        case .changeVideoSpeed: return "Changing speed"
        case .joinVideos: return "Joining"
        case .videoSnapshots: return "Saving frames"
        case .splitVideo, .splitPDF: return "Splitting"
        case .normalizeAudio: return "Normalizing"
        case .audioToVideo: return "Creating visualizer"
        case .audioChannels: return "Converting channels"
        case .redactAudio: return "Bleeping"
        case .mergePDF: return "Merging"
        case .organizePDF: return "Organizing"
        case .extractArchive: return "Extracting"
        }
    }

    public var radialLabel: String {
        switch self {
        case .compress: return "COMPRESS"
        case .editMetadata: return "METADATA"
        case .editImage: return "EDIT"
        case .frameImage: return "ADD BG"
        case .cropImage, .cropVideo: return "CROP"
        case .redactImage, .redactVideo: return "REDACT"
        case .resizeImage: return "RESIZE"
        case .rotateImage: return "ROTATE"
        case .createPDF: return "PDF"
        case .createCollage: return "COLLAGE"
        case .trimVideo, .trimAudio: return "TRIM"
        case .changeVideoSpeed: return "SPEED"
        case .joinVideos: return "JOIN"
        case .videoSnapshots: return "FRAMES"
        case .splitVideo, .splitPDF: return "SPLIT"
        case .normalizeAudio: return "NORMALIZE"
        case .audioToVideo: return "VISUALIZE"
        case .audioChannels: return "CHANNELS"
        case .redactAudio: return "BLEEP"
        case .mergePDF: return "MERGE"
        case .organizePDF: return "ORGANIZE"
        case .extractArchive: return "EXTRACT"
        }
    }

    public var symbol: String {
        switch self {
        case .compress: return "arrow.down.right.and.arrow.up.left"
        case .editMetadata: return "tag"
        case .editImage: return "slider.horizontal.3"
        case .frameImage: return "photo.artframe"
        case .cropImage, .cropVideo: return "crop"
        case .redactImage: return "eye.slash"
        case .redactVideo: return "video.slash"
        case .resizeImage: return "arrow.up.left.and.arrow.down.right"
        case .rotateImage: return "rotate.right"
        case .createPDF: return "doc.richtext"
        case .createCollage: return "square.grid.2x2"
        case .trimVideo, .trimAudio: return "scissors"
        case .changeVideoSpeed: return "gauge.with.dots.needle.67percent"
        case .joinVideos: return "link"
        case .videoSnapshots: return "camera.viewfinder"
        case .splitVideo: return "rectangle.split.2x1"
        case .splitPDF: return "doc.on.doc"
        case .normalizeAudio: return "waveform"
        case .audioToVideo: return "waveform.and.magnifyingglass"
        case .audioChannels: return "headphones"
        case .redactAudio: return "speaker.slash"
        case .mergePDF: return "doc.on.doc.fill"
        case .organizePDF: return "rectangle.stack"
        case .extractArchive: return "archivebox"
        }
    }

    public var categories: Set<FormatCategory> {
        switch self {
        case .compress, .editMetadata:
            return [.image, .video, .audio, .document, .archive]
        case .editImage, .frameImage, .cropImage, .redactImage, .resizeImage, .rotateImage, .createPDF, .createCollage:
            return [.image]
        case .trimVideo, .cropVideo, .changeVideoSpeed, .joinVideos, .videoSnapshots, .splitVideo, .redactVideo:
            return [.video]
        case .normalizeAudio, .audioToVideo, .trimAudio, .audioChannels, .redactAudio:
            return [.audio]
        case .mergePDF, .organizePDF, .splitPDF:
            return [.document]
        case .extractArchive:
            return [.archive]
        }
    }

    public var arity: ToolArity {
        switch self {
        case .compress, .editMetadata, .resizeImage, .rotateImage, .createPDF: return .any
        case .createCollage, .joinVideos, .mergePDF: return .multiple
        default: return .single
        }
    }

    public func applies(to formats: [FileFormat]) -> Bool {
        guard !formats.isEmpty else { return false }
        let cats = Set(formats.map(\.category))
        guard cats.count == 1, let cat = cats.first, self.categories.contains(cat) else { return false }
        if cat == .document {
            switch self {
            case .mergePDF, .organizePDF, .splitPDF, .editMetadata, .compress:
                guard formats.allSatisfy({ $0 == .pdf }) else { return false }
            default:
                return false
            }
        }
        if cat == .video, formats.contains(.gif), self != .compress, self != .editMetadata { return false }
        switch arity {
        case .single: return formats.count == 1
        case .multiple: return formats.count >= 2
        case .any: return true
        }
    }

    public static func available(for formats: [FileFormat]) -> [ToolID] {
        allCases.filter { $0.applies(to: formats) }
    }

    public static var total: Int { allCases.count }
}
