import Foundation
import PDFKit
import SwiftUI
import UIKit

enum NexlideAction: String, CaseIterable, Identifiable {
    case none
    case nextPage
    case previousPage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return "割り当てなし"
        case .nextPage:
            return "次ページ"
        case .previousPage:
            return "前ページ"
        }
    }
}

enum ExternalDisplayMode: String, CaseIterable, Identifiable {
    case slideOnly
    case presenterMode

    var id: String { rawValue }

    var title: String {
        switch self {
        case .slideOnly:
            return "現在スライドのみ"
        case .presenterMode:
            return "プレゼンモード"
        }
    }
}

enum PencilInputKind: String {
    case doubleTap
    case squeeze
}

enum NoteDisplayMode: String, CaseIterable, Identifiable, Codable {
    case off
    case markdown
    case plainText

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off:
            return "OFF"
        case .markdown:
            return "Markdown"
        case .plainText:
            return "TXT"
        }
    }
}

struct LapRecord: Identifiable, Equatable, Codable {
    let id: UUID
    let seconds: Int
    let pageIndex: Int

    init(id: UUID = UUID(), seconds: Int, pageIndex: Int) {
        self.id = id
        self.seconds = seconds
        self.pageIndex = pageIndex
    }

    var pageNumber: Int {
        pageIndex + 1
    }
}

struct NexlideProjectManifest: Codable {
    var formatVersion: Int
    var title: String
    var pdfFileName: String
    var createdAt: Date
    var updatedAt: Date
    var currentPageIndex: Int
    var notesByPage: [Int: String]
    var lapRecords: [LapRecord]
    var noteDisplayMode: NoteDisplayMode
    var noteFontSize: Double
}

@MainActor
final class PresentationStore: ObservableObject {
    static let shared = PresentationStore()

    @Published var pdfDocument: PDFDocument?
    @Published var pdfURL: URL?
    @Published var projectPackageURL: URL?
    @Published var projectTitle = ""
    @Published var currentPageIndex = 0
    @Published var notesByPage: [Int: String] = [:]
    @Published var externalDisplayActive = false
    @Published var isTimerRunning = false
    @Published var elapsedSeconds = 0
    @Published var lapRecords: [LapRecord] = []
    @Published var lastDetectedPencilDescription = "未検出"
    @Published var noteDisplayMode: NoteDisplayMode {
        didSet {
            defaults.set(noteDisplayMode.rawValue, forKey: Keys.noteDisplayMode)
            if noteDisplayMode != .off {
                defaults.set(noteDisplayMode.rawValue, forKey: Keys.lastVisibleNoteDisplayMode)
            }
            saveProjectPackage()
        }
    }
    @Published var noteFontSize: Double {
        didSet {
            defaults.set(noteFontSize, forKey: Keys.noteFontSize)
            saveProjectPackage()
        }
    }

    @Published var doubleTapAction: NexlideAction {
        didSet { defaults.set(doubleTapAction.rawValue, forKey: Keys.doubleTapAction) }
    }

    @Published var squeezeAction: NexlideAction {
        didSet { defaults.set(squeezeAction.rawValue, forKey: Keys.squeezeAction) }
    }

    @Published var externalDisplayMode: ExternalDisplayMode {
        didSet { defaults.set(externalDisplayMode.rawValue, forKey: Keys.externalDisplayMode) }
    }

    private enum Keys {
        static let doubleTapAction = "pencil.doubleTapAction"
        static let squeezeAction = "pencil.squeezeAction"
        static let externalDisplayMode = "externalDisplay.mode"
        static let noteDisplayMode = "notes.displayMode"
        static let lastVisibleNoteDisplayMode = "notes.lastVisibleDisplayMode"
        static let noteFontSize = "notes.fontSize"
        static let notesPrefix = "notes."
        static let lapsPrefix = "laps."
    }

    private let defaults = UserDefaults.standard
    private var timer: Timer?
    private let projectPDFFileName = "presentation.pdf"
    private let projectManifestFileName = "manifest.json"

    var pageCount: Int {
        pdfDocument?.pageCount ?? 0
    }

    var canGoPrevious: Bool {
        currentPageIndex > 0
    }

    var canGoNext: Bool {
        currentPageIndex + 1 < pageCount
    }

    var currentPage: PDFPage? {
        pdfDocument?.page(at: currentPageIndex)
    }

    var nextPage: PDFPage? {
        guard currentPageIndex + 1 < pageCount else { return nil }
        return pdfDocument?.page(at: currentPageIndex + 1)
    }

    var currentNote: String {
        notesByPage[currentPageIndex, default: ""]
    }

    var latestLap: LapRecord? {
        lapRecords.last
    }

    var canExportProject: Bool {
        projectPackageURL != nil
    }

    private init() {
        let savedDoubleTap = defaults.string(forKey: Keys.doubleTapAction)
        let savedSqueeze = defaults.string(forKey: Keys.squeezeAction)
        let savedExternalMode = defaults.string(forKey: Keys.externalDisplayMode)
        let savedNoteDisplayMode = defaults.string(forKey: Keys.noteDisplayMode)
        let savedNoteFontSize = defaults.double(forKey: Keys.noteFontSize)

        doubleTapAction = NexlideAction(rawValue: savedDoubleTap ?? "") ?? .nextPage
        squeezeAction = NexlideAction(rawValue: savedSqueeze ?? "") ?? .nextPage
        externalDisplayMode = ExternalDisplayMode(rawValue: savedExternalMode ?? "") ?? .slideOnly
        noteDisplayMode = NoteDisplayMode(rawValue: savedNoteDisplayMode ?? "") ?? .markdown
        noteFontSize = savedNoteFontSize == 0 ? 28 : savedNoteFontSize
    }

    func toggleNoteDisplayVisibility() {
        if noteDisplayMode == .off {
            let savedMode = defaults.string(forKey: Keys.lastVisibleNoteDisplayMode)
            noteDisplayMode = NoteDisplayMode(rawValue: savedMode ?? "") ?? .markdown
        } else {
            defaults.set(noteDisplayMode.rawValue, forKey: Keys.lastVisibleNoteDisplayMode)
            noteDisplayMode = .off
        }
    }

    func openPDF(from url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let document = PDFDocument(url: url) else { return }

        let packageURL = makeProjectPackage(from: url)
        let storedPDFURL = packageURL?.appendingPathComponent(projectPDFFileName) ?? url

        pdfURL = storedPDFURL
        projectPackageURL = packageURL
        projectTitle = packageURL?.deletingPathExtension().lastPathComponent ?? url.deletingPathExtension().lastPathComponent
        pdfDocument = document
        currentPageIndex = 0
        notesByPage = [:]
        lapRecords = []
        resetElapsedSeconds()
        saveProjectPackage()
    }

    func openProject(from url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let importedPackageURL = copyProjectIntoAppStorage(from: url) else { return }
        loadProjectPackage(from: importedPackageURL)
    }

    func closePDF() {
        pdfDocument = nil
        pdfURL = nil
        projectPackageURL = nil
        projectTitle = ""
        currentPageIndex = 0
        notesByPage = [:]
        lapRecords = []
        resetTimer()
    }

    func goToPage(_ index: Int) {
        guard pageCount > 0 else { return }
        currentPageIndex = min(max(index, 0), pageCount - 1)
        saveProjectPackage()
    }

    func goNext() {
        guard canGoNext else { return }
        currentPageIndex += 1
        saveProjectPackage()
    }

    func goPrevious() {
        guard canGoPrevious else { return }
        currentPageIndex -= 1
        saveProjectPackage()
    }

    func performPencilAction(_ inputKind: PencilInputKind) {
        let action: NexlideAction
        switch inputKind {
        case .doubleTap:
            lastDetectedPencilDescription = "ダブルタップ対応Pencilを検出"
            action = doubleTapAction
        case .squeeze:
            lastDetectedPencilDescription = "スクイーズ対応Pencilを検出"
            action = squeezeAction
        }

        switch action {
        case .none:
            break
        case .nextPage:
            goNext()
        case .previousPage:
            goPrevious()
        }
    }

    func setCurrentNote(_ note: String) {
        setNote(note, for: currentPageIndex)
    }

    func appendToCurrentNote(_ text: String) {
        let current = note(for: currentPageIndex)
        let separator = current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "\n"
        setNote(current + separator + text, for: currentPageIndex)
    }

    func clearCurrentNote() {
        setNote("", for: currentPageIndex)
    }

    func setNote(_ note: String, for pageIndex: Int) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            notesByPage.removeValue(forKey: pageIndex)
        } else {
            notesByPage[pageIndex] = note
        }
        saveNotes()
    }

    func note(for pageIndex: Int) -> String {
        notesByPage[pageIndex, default: ""]
    }

    func hasNote(for pageIndex: Int) -> Bool {
        !note(for: pageIndex).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func importNotes(from url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        let blocks = Self.splitNotes(text)
        guard !blocks.isEmpty else { return }

        var imported: [Int: String] = notesByPage
        for (index, block) in blocks.enumerated() where index < pageCount {
            imported[index] = block.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        notesByPage = imported
        saveNotes()
        saveProjectPackage()
    }

    static func splitNotes(_ text: String) -> [String] {
        var blocks: [String] = []
        var currentLines: [String] = []

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "---" || trimmed == "ーー" {
                blocks.append(currentLines.joined(separator: "\n"))
                currentLines = []
            } else {
                currentLines.append(line)
            }
        }

        blocks.append(currentLines.joined(separator: "\n"))
        return blocks
    }

    static func markdownToPlainText(_ markdown: String) -> String {
        markdown
            .components(separatedBy: .newlines)
            .map(markdownLineToPlainText)
            .joined(separator: "\n")
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
    }

    private static func markdownLineToPlainText(_ line: String) -> String {
        var plain = line

        plain = plain.replacingOccurrences(of: #"^\s{0,3}#{1,6}\s+"#, with: "", options: .regularExpression)
        plain = plain.replacingOccurrences(of: #"^\s{0,3}>\s?"#, with: "", options: .regularExpression)
        plain = plain.replacingOccurrences(of: #"^\s*[-*+]\s+"#, with: "", options: .regularExpression)
        plain = plain.replacingOccurrences(of: #"^\s*\d+[.)]\s+"#, with: "", options: .regularExpression)
        plain = plain.replacingOccurrences(of: #"!\[([^\]]*)\]\([^)]+\)"#, with: "$1", options: .regularExpression)
        plain = plain.replacingOccurrences(of: #"\[([^\]]+)\]\([^)]+\)"#, with: "$1", options: .regularExpression)
        plain = plain.replacingOccurrences(of: #"`([^`]+)`"#, with: "$1", options: .regularExpression)
        plain = plain.replacingOccurrences(of: #"(\*\*|__)(.*?)\1"#, with: "$2", options: .regularExpression)
        plain = plain.replacingOccurrences(of: #"(\*|_)(.*?)\1"#, with: "$2", options: .regularExpression)
        plain = plain.replacingOccurrences(of: #"~~(.*?)~~"#, with: "$1", options: .regularExpression)
        plain = plain.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)

        return plain.trimmingCharacters(in: .whitespaces)
    }

    func toggleTimer() {
        isTimerRunning ? pauseTimer() : startTimer()
    }

    func startTimer() {
        guard timer == nil else { return }
        isTimerRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.elapsedSeconds += 1
            }
        }
    }

    func pauseTimer() {
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
    }

    func resetTimer() {
        pauseTimer()
        resetElapsedSeconds()
        clearLapRecords()
    }

    func resetElapsedSeconds() {
        elapsedSeconds = 0
    }

    func recordLap() {
        lapRecords.append(LapRecord(seconds: elapsedSeconds, pageIndex: currentPageIndex))
        saveLapRecords()
    }

    func clearLapRecords() {
        lapRecords = []
        saveLapRecords()
    }

    func updateExternalDisplayStatus() {
        externalDisplayActive = UIApplication.shared.connectedScenes.contains {
            $0.session.role == .windowExternalDisplayNonInteractive
        }
    }

    private func loadNotes() {
        guard let key = notesKey else {
            notesByPage = [:]
            return
        }

        guard
            let data = defaults.data(forKey: key),
            let saved = try? JSONDecoder().decode([Int: String].self, from: data)
        else {
            notesByPage = [:]
            return
        }

        notesByPage = saved
    }

    private func saveNotes() {
        guard let key = notesKey else { return }
        guard let data = try? JSONEncoder().encode(notesByPage) else { return }
        defaults.set(data, forKey: key)
        saveProjectPackage()
    }

    private func loadLapRecords() {
        guard let key = lapRecordsKey else {
            lapRecords = []
            return
        }

        guard
            let data = defaults.data(forKey: key),
            let saved = try? JSONDecoder().decode([LapRecord].self, from: data)
        else {
            lapRecords = []
            return
        }

        lapRecords = saved
    }

    private func saveLapRecords() {
        guard let key = lapRecordsKey else { return }
        guard let data = try? JSONEncoder().encode(lapRecords) else { return }
        defaults.set(data, forKey: key)
        saveProjectPackage()
    }

    func saveProjectPackage() {
        guard let projectPackageURL, pdfURL != nil else { return }

        let manifest = NexlideProjectManifest(
            formatVersion: 1,
            title: projectTitle.isEmpty ? projectPackageURL.deletingPathExtension().lastPathComponent : projectTitle,
            pdfFileName: projectPDFFileName,
            createdAt: projectCreatedDate(for: projectPackageURL),
            updatedAt: Date(),
            currentPageIndex: currentPageIndex,
            notesByPage: notesByPage,
            lapRecords: lapRecords,
            noteDisplayMode: noteDisplayMode,
            noteFontSize: noteFontSize
        )

        guard let data = try? JSONEncoder.projectEncoder.encode(manifest) else { return }
        try? data.write(to: projectPackageURL.appendingPathComponent(projectManifestFileName), options: [.atomic])
    }

    private func loadProjectPackage(from packageURL: URL) {
        let manifestURL = packageURL.appendingPathComponent(projectManifestFileName)
        guard
            let manifestData = try? Data(contentsOf: manifestURL),
            let manifest = try? JSONDecoder.projectDecoder.decode(NexlideProjectManifest.self, from: manifestData)
        else { return }

        let storedPDFURL = packageURL.appendingPathComponent(manifest.pdfFileName)
        guard let document = PDFDocument(url: storedPDFURL) else { return }

        projectPackageURL = packageURL
        projectTitle = manifest.title
        pdfURL = storedPDFURL
        pdfDocument = document
        notesByPage = manifest.notesByPage
        lapRecords = manifest.lapRecords
        noteDisplayMode = manifest.noteDisplayMode
        noteFontSize = manifest.noteFontSize
        currentPageIndex = min(max(manifest.currentPageIndex, 0), max(document.pageCount - 1, 0))
        resetElapsedSeconds()
        saveNotes()
        saveLapRecords()
        saveProjectPackage()
    }

    private func makeProjectPackage(from pdfURL: URL) -> URL? {
        let title = pdfURL.deletingPathExtension().lastPathComponent
        guard let packageURL = uniqueProjectPackageURL(named: title) else { return nil }

        do {
            try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: pdfURL, to: packageURL.appendingPathComponent(projectPDFFileName))
            return packageURL
        } catch {
            try? FileManager.default.removeItem(at: packageURL)
            return nil
        }
    }

    private func copyProjectIntoAppStorage(from sourceURL: URL) -> URL? {
        let title = sourceURL.deletingPathExtension().lastPathComponent
        guard let destinationURL = uniqueProjectPackageURL(named: title) else { return nil }

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            try? FileManager.default.removeItem(at: destinationURL)
            return nil
        }
    }

    private func uniqueProjectPackageURL(named name: String) -> URL? {
        guard let directory = projectsDirectoryURL() else { return nil }
        let baseName = sanitizedProjectName(name.isEmpty ? "Untitled" : name)
        var candidate = directory.appendingPathComponent(baseName).appendingPathExtension("nexlide")
        var suffix = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(baseName)-\(suffix)").appendingPathExtension("nexlide")
            suffix += 1
        }

        return candidate
    }

    private func projectsDirectoryURL() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let directory = appSupport.appendingPathComponent("Nexlide Projects", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func sanitizedProjectName(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = name
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Untitled" : cleaned
    }

    private func projectCreatedDate(for packageURL: URL) -> Date {
        guard
            let data = try? Data(contentsOf: packageURL.appendingPathComponent(projectManifestFileName)),
            let manifest = try? JSONDecoder.projectDecoder.decode(NexlideProjectManifest.self, from: data)
        else {
            return Date()
        }
        return manifest.createdAt
    }

    private var notesKey: String? {
        storageKey(prefix: Keys.notesPrefix)
    }

    private var lapRecordsKey: String? {
        storageKey(prefix: Keys.lapsPrefix)
    }

    private func storageKey(prefix: String) -> String? {
        guard let pdfURL else { return nil }
        let data = Data(pdfURL.absoluteString.utf8)
        let encoded = data.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        return prefix + encoded
    }
}

extension Int {
    var stopwatchText: String {
        let hours = self / 3600
        let minutes = (self % 3600) / 60
        let seconds = self % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private extension JSONEncoder {
    static var projectEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var projectDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
