import Foundation
import AppKit

@MainActor
final class LogFilterViewModel: ObservableObject {

    // File
    @Published private(set) var fileURL: URL?
    @Published private(set) var fileText: String = ""

    // Filtering
    @Published private(set) var filteredLines: [FilteredLine] = []
    @Published var visibleLines: [FilteredLine] = []

    // UI state
    @Published var prompt: String = ""
    @Published var regexPattern: String?
    @Published var displayMode: DisplayMode = .filteredOnly
    @Published var isApplying = false
    @Published var isWatching = true

    // Errors
    @Published var showError = false
    @Published var lastError: String?

    // API
    @Published var apiKey: String = ""
    @Published var showApiKeySheet = true

    private let openAI = OpenAIClient()
    private var watcher: FileWatcher?
    private var lastGoodRegex: NSRegularExpression?

    // MARK: File Handling

    func newFile() {
        let panel = NSSavePanel()
        panel.begin { resp in
            guard resp == .OK, let url = panel.url else { return }
            try? "".write(to: url, atomically: true, encoding: .utf8)
            self.load(url: url)
        }
    }

    func openFile() {
        let panel = NSOpenPanel()
        panel.begin { resp in
            guard resp == .OK, let url = panel.url else { return }
            self.load(url: url)
        }
    }

    func save() {
        guard let url = fileURL else { saveAs(); return }
        try? fileText.write(to: url, atomically: true, encoding: .utf8)
    }

    func saveAs() {
        let panel = NSSavePanel()
        panel.begin { resp in
            guard resp == .OK, let url = panel.url else { return }
            self.fileURL = url
            self.save()
            self.updateWatcher()
        }
    }

    private func load(url: URL) {
        do {
            fileURL = url
            fileText = try String(contentsOf: url)
            recomputeFilter(using: lastGoodRegex)
            updateVisibleLines()
            updateWatcher()
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func reloadFromDisk() {
        guard let url = fileURL else { return }
        fileText = (try? String(contentsOf: url)) ?? fileText
        recomputeFilter(using: lastGoodRegex)
        updateVisibleLines()
    }

    // MARK: Filtering

    func applyFilter() {
        guard !apiKey.isEmpty else {
            showApiKeySheet = true
            return
        }

        isApplying = true

        Task {
            defer { isApplying = false }

            do {
                let sample = makeSample()
                let regex = try await openAI.generateRegex(
                    apiKey: apiKey,
                    userPrompt: prompt,
                    logSample: sample
                )

                let compiled = try compileSafeRegex(regex)
                regexPattern = regex
                lastGoodRegex = compiled

                recomputeFilter(using: compiled)
                updateVisibleLines()

            } catch {
                fail(error.localizedDescription)
            }
        }
    }

    private func recomputeFilter(using regex: NSRegularExpression?) {
        let lines = fileText.components(separatedBy: .newlines)

        filteredLines = lines.map { line in
            guard let regex else {
                return FilteredLine(text: line, isMatch: false)
            }
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            let match = regex.firstMatch(in: line, range: range) != nil
            return FilteredLine(text: line, isMatch: match)
        }
    }

    func updateVisibleLines() {
        switch displayMode {
        case .filteredOnly:
            visibleLines = filteredLines.filter { $0.isMatch }
        case .excludedOnly:
            visibleLines = filteredLines.filter { !$0.isMatch }
        case .highlighted:
            visibleLines = filteredLines
        }
    }

    // MARK: Regex Safety

    private func compileSafeRegex(_ pattern: String) throws -> NSRegularExpression {
        if pattern.count > 512 {
            throw AppError("Regex too long")
        }
        return try NSRegularExpression(pattern: pattern)
    }

    // MARK: File Watching

    func updateWatcher() {
        watcher?.stop()
        watcher = nil

        guard isWatching, let url = fileURL else { return }

        watcher = FileWatcher(url: url) { [weak self] in
            Task { @MainActor in self?.reloadFromDisk() }
        }
        watcher?.start()
    }

    // MARK: Helpers

    private func makeSample() -> String {
        let lines = fileText.components(separatedBy: .newlines)
        return lines.prefix(100).joined(separator: "\n")
    }

    private func fail(_ msg: String) {
        lastError = msg
        showError = true
    }
}

struct AppError: LocalizedError {
    let message: String
    init(_ m: String) { message = m }
    var errorDescription: String? { message }
}
