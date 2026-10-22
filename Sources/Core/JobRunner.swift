import AppKit
import Combine
import Foundation
import SwiftUI
import UserNotifications

public final class Job: ObservableObject, Identifiable {
    public let id = UUID()
    public let title: String
    public let detail: String
    public let symbol: String
    public let date: Date = Date()
    @Published public var progress: Double = 0
    @Published public var status: Status = .waiting
    public var outputs: [URL] = []
    public var sourceURLs: [URL] = []
    public var task: Task<Void, Never>?

    public enum Status: Equatable {
        case waiting
        case running
        case done
        case cancelled
        case failed(String)

        public var isFinished: Bool {
            switch self {
            case .done, .cancelled, .failed: return true
            case .waiting, .running: return false
            }
        }
    }

    public init(title: String, detail: String, symbol: String = "arrow.triangle.2.circlepath", sourceURLs: [URL] = []) {
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.sourceURLs = sourceURLs
    }
}

actor AsyncSemaphore {
    private var permits: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) { self.permits = limit }

    func wait() async {
        if permits > 0 {
            permits -= 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func signal() {
        if !waiters.isEmpty {
            let waiter = waiters.removeFirst()
            waiter.resume()
        } else {
            permits += 1
        }
    }
}

@MainActor
public final class JobRunner: ObservableObject {
    public static let shared = JobRunner()

    @Published public private(set) var jobs: [Job] = []
    @Published public private(set) var activeJob: Job?

    private let semaphore = AsyncSemaphore(limit: 2)
    private var reservedDestinations: [UUID: URL] = [:]
    private var subscriptions: [UUID: AnyCancellable] = [:]

    private init() {
        requestNotificationPermission()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    public func convert(_ urls: [URL], to target: FileFormat) {
        DiagnosticLog.log("JobRunner: convert \(urls.map(\.lastPathComponent)) to \(target.displayName)")
        for url in urls {
            let job = Job(
                title: "Converting to \(target.displayName)",
                detail: url.lastPathComponent,
                symbol: target.category.symbol,
                sourceURLs: [url]
            )
            guard let source = FileFormat.detect(url) else {
                enqueue(job) { _ in
                    throw SwipError.invalidInput("Unsupported file type: \(url.lastPathComponent)")
                }
                continue
            }
            let directory = AppSettings.shared.outputLocation.directory(for: url)
            let reserved = Set(reservedDestinations.values.filter {
                $0.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL
            }.map(\.lastPathComponent))
            let destination = ConversionMatrix.outputURL(for: url, target: target, in: directory, existing: reserved)
            reservedDestinations[job.id] = destination

            enqueue(job) { progress in
                let request = ConversionRequest(
                    source: url,
                    sourceFormat: source,
                    target: target,
                    destination: destination,
                    progress: progress
                )
                try await Engines.convert(request)
                return [destination]
            }
        }
    }

    public func run(title: String, detail: String, symbol: String = "wrench.and.screwdriver", sourceURLs: [URL] = [], work: @escaping (@escaping (Double) -> Void) async throws -> [URL]) {
        let job = Job(title: title, detail: detail, symbol: symbol, sourceURLs: sourceURLs)
        enqueue(job, work: work)
    }

    public func enqueue(_ job: Job, work: @escaping (@escaping (Double) -> Void) async throws -> [URL]) {
        jobs.insert(job, at: 0)
        subscriptions[job.id] = job.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }

        job.task = Task {
            defer {
                reservedDestinations[job.id] = nil
                Task { @MainActor in
                    if self.activeJob?.id == job.id {
                        self.activeJob = self.jobs.first { !$0.status.isFinished }
                    }
                }
            }
            await semaphore.wait()
            defer { Task { await semaphore.signal() } }

            guard !Task.isCancelled else {
                await MainActor.run { job.status = .cancelled }
                return
            }

            await MainActor.run {
                job.status = .running
                self.activeJob = job
            }

            do {
                let outputs = try await work { progress in
                    Task { @MainActor in job.progress = progress }
                }
                guard !Task.isCancelled else {
                    await MainActor.run { job.status = .cancelled }
                    return
                }
                await MainActor.run {
                    job.progress = 1
                    job.outputs = outputs
                    job.status = .done
                    SoundManager.shared.playSuccess()
                    self.postNotification(title: "Conversion Complete", body: "\(job.detail) converted successfully.")
                }
            } catch is CancellationError {
                await MainActor.run { job.status = .cancelled }
            } catch {
                await MainActor.run {
                    job.status = .failed(error.localizedDescription)
                    DiagnosticLog.log("Job failed: \(error)")
                }
            }
        }
    }

    public func cancel(job: Job) {
        job.task?.cancel()
        job.status = .cancelled
    }

    public func clearFinished() {
        jobs.removeAll { $0.status.isFinished }
    }

    private func postNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}

public struct JobOutputActions: View {
    @ObservedObject public var job: Job

    public init(job: Job) {
        self.job = job
    }

    public var body: some View {
        HStack(spacing: 12) {
            Button("Open", systemImage: "arrow.up.forward.square") {
                if let output = job.outputs.first {
                    NSWorkspace.shared.open(output)
                }
            }
            .help("Open the output file")

            Button("Show", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting(job.outputs)
            }
            .help("Show output in Finder")
        }
        .buttonStyle(.plain)
        .font(.system(size: 10, weight: .semibold))
    }
}
