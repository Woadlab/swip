import Foundation

public struct ShellResult {
    public let status: Int32
    public let stdout: String
    public let stderr: String

    public var succeeded: Bool { status == 0 }
    public var isSuccess: Bool { status == 0 }
}

final class PipeBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var stdout = Data()
    private var stderr = Data()

    func set(stdout data: Data) { lock.withLock { stdout = data } }
    func set(stderr data: Data) { lock.withLock { stderr = data } }

    func result(status: Int32) -> ShellResult {
        lock.withLock {
            ShellResult(
                status: status,
                stdout: String(decoding: stdout, as: UTF8.self),
                stderr: String(decoding: stderr, as: UTF8.self)
            )
        }
    }
}

final class ProcessBox: @unchecked Sendable {
    let process = Process()
    func terminate() {
        if process.isRunning { process.terminate() }
    }
}

public enum Shell {
    public static func run(_ executable: String, _ arguments: [String], currentDirectory: URL? = nil) async throws -> ShellResult {
        let box = ProcessBox()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let process = box.process
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                if let currentDirectory = currentDirectory { process.currentDirectoryURL = currentDirectory }
                var env = ProcessInfo.processInfo.environment
                let path = env["PATH"] ?? ""
                if !path.contains("/opt/homebrew/bin") {
                    env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + path
                }
                process.environment = env

                process.standardInput = FileHandle.nullDevice
                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe
                let output = PipeBuffer()
                let group = DispatchGroup()
                group.enter()
                DispatchQueue.global().async {
                    output.set(stdout: drain(outPipe.fileHandleForReading))
                    group.leave()
                }
                group.enter()
                DispatchQueue.global().async {
                    output.set(stderr: drain(errPipe.fileHandleForReading))
                    group.leave()
                }
                process.terminationHandler = { proc in
                    group.wait()
                    continuation.resume(returning: output.result(status: proc.terminationStatus))
                }
                do {
                    try process.run()
                    try? outPipe.fileHandleForWriting.close()
                    try? errPipe.fileHandleForWriting.close()
                } catch {
                    try? outPipe.fileHandleForWriting.close()
                    try? errPipe.fileHandleForWriting.close()
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            box.terminate()
        }
    }

    private static func drain(_ handle: FileHandle) -> Data {
        var result = Data()
        while let chunk = try? handle.read(upToCount: 65536), !chunk.isEmpty {
            if result.count < 2_000_000 { result.append(chunk.prefix(2_000_000 - result.count)) }
        }
        return result
    }

    public static func which(_ name: String, extra: [String] = []) -> String? {
        let fm = FileManager.default
        var candidates = extra
        candidates += [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/opt/local/bin/\(name)",
            "\(fm.homeDirectoryForCurrentUser.path)/.local/bin/\(name)",
            "/usr/bin/\(name)",
            "/bin/\(name)",
        ]
        if let bundled = Bundle.main.url(forAuxiliaryExecutable: name)?.path {
            candidates.insert(bundled, at: 0)
        }
        if let resource = Bundle.main.resourceURL?.appendingPathComponent(name).path {
            candidates.insert(resource, at: 1)
        }
        return candidates.first { fm.isExecutableFile(atPath: $0) }
    }
}
