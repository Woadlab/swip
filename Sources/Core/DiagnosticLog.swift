import Foundation

public enum DiagnosticLog {
    private static let logURL: URL = {
        let dir = FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("swip-debug.log")
    }()

    private static let queue = DispatchQueue(label: "org.woadlab.swip.diagnosticlog", qos: .utility)

    public static func start() {
        log("=== Swip session started at \(Date()) ===")
    }

    public static func log(_ message: @autoclosure () -> String) {
        let text = message()
        #if DEBUG
        print("[Swip] \(text)")
        #endif
        queue.async {
            let line = "\(ISO8601DateFormatter().string(from: Date())) [Swip] \(text)\n"
            if let data = line.data(using: .utf8) {
                if let handle = try? FileHandle(forWritingTo: logURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                } else {
                    try? data.write(to: logURL, options: .atomic)
                }
            }
        }
    }

    public static var currentLogPath: String {
        logURL.path
    }
}
