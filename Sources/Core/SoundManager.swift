import AppKit
import AudioToolbox

public final class SoundManager {
    public static let shared = SoundManager()

    private var highlightSoundID: SystemSoundID = 1104 // Subtle keyboard click/tick
    private var dropSoundID: SystemSoundID = 1105 // Pop
    private var completeSoundID: SystemSoundID = 1001 // Chime

    private init() {}

    public func playHighlight() {
        guard AppSettings.shared.soundEnabled else { return }
        AudioServicesPlaySystemSound(highlightSoundID)
    }

    public func playDrop() {
        guard AppSettings.shared.soundEnabled else { return }
        AudioServicesPlaySystemSound(dropSoundID)
    }

    public func playSuccess() {
        guard AppSettings.shared.soundEnabled else { return }
        AudioServicesPlaySystemSound(completeSoundID)
    }

    public func triggerHaptic() {
        guard AppSettings.shared.hapticsEnabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
    }
}
