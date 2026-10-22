import AppKit
import Foundation

@main
@MainActor
public enum SwipMain {
    public static func main() {
        let args = CommandLine.arguments
        
        if args.contains("--smoke-test") {
            SmokeTestRunner.run()
            exit(0)
        }

        if args.contains("--export-assets") {
            let targetDir = URL(fileURLWithPath: "video/public/assets")
            VideoAssetExporter.exportAll(to: targetDir)
            exit(0)
        }
        
        if args.contains("--version") || args.contains("-v") {
            print("Swip 1.0.1 (Apple Silicon, 100% Local macOS File Utility)")
            exit(0)
        }
        
        if args.contains("--help") || args.contains("-h") {
            print("""
            Swip — Zero-Click Drag & Drop Swiss Army Knife for macOS (100% Local)
            
            Usage:
              Swip                 Launch Swip background menu bar agent & studio
              Swip --smoke-test    Run automated offline engine & tool smoke tests
              Swip --version       Print version
              Swip --help          Print this help message
            
            Key Gestures (Hold while dragging any file or selection):
              Shift (⇧)   Radial Conversion Wheel (275+ offline conversions)
              Command (⌘) Radial File Tools (26 offline interactive & fast tools)
              Control (⌃) Radial File Actions (AirDrop, Floating Shelf, Copy, Move, Hash...)
            """)
            exit(0)
        }
        
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    }
}
