import SwiftUI

struct PresenterConsoleView: View {
    @EnvironmentObject private var store: PresentationStore
    @State private var showsThumbnailStrip = false
    @State private var showsLapHistory = false
    @State private var showsNotePinEditor = false
    let showPDFPicker: () -> Void
    let showProjectPicker: () -> Void
    let showProjectExporter: () -> Void
    let showNotesPicker: () -> Void
    let showSettings: () -> Void
    let showPencilSettings: () -> Void

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    if showsPageSidebar {
                        ThumbnailStripView()
                            .frame(width: min(280, geometry.size.width * 0.26))
                    }

                    if showsNotePinEditor {
                        NotePinEditorPanel()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if showsMainSlidesOnly {
                        HStack(spacing: 12) {
                            SlidePreviewPanel(title: "Now", pageIndex: store.currentPageIndex)
                            SlidePreviewPanel(title: "Next", pageIndex: store.currentPageIndex + 1)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        HStack(spacing: 10) {
                            slidePreviewColumn(width: geometry.size.width * (showsPageSidebar ? 0.36 : 0.48))

                            activeSidePanel
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }

                if showsNotePinEditor {
                    NoteEditorControlsBar(
                        showsNotePinEditor: $showsNotePinEditor,
                        showNotesPicker: showNotesPicker,
                        showSettings: showSettings
                    )
                    .frame(height: 74)
                } else {
                    BottomControlsBar(
                        showsThumbnailStrip: $showsThumbnailStrip,
                        showsLapHistory: $showsLapHistory,
                        showsNotePinEditor: $showsNotePinEditor,
                        showPDFPicker: showPDFPicker,
                        showProjectPicker: showProjectPicker,
                        showProjectExporter: showProjectExporter,
                        showNotesPicker: showNotesPicker,
                        showSettings: showSettings,
                        showPencilSettings: showPencilSettings
                    )
                    .frame(height: 74)
                }
            }
            .padding(12)
        }
        .background(.black)
        .overlay {
            PencilInteractionOverlay()
            KeyboardShortcutOverlay()
        }
    }

    private var showsMainSlidesOnly: Bool {
        store.noteDisplayMode == .off && !showsLapHistory && !showsNotePinEditor
    }

    private var showsPageSidebar: Bool {
        showsThumbnailStrip || showsNotePinEditor
    }

    private func slidePreviewColumn(width: CGFloat) -> some View {
        VStack(spacing: 10) {
            SlidePreviewPanel(title: "Now", pageIndex: store.currentPageIndex)

            SlidePreviewPanel(title: "Next", pageIndex: store.currentPageIndex + 1)
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var activeSidePanel: some View {
        if showsLapHistory {
            LapHistoryPanel()
        } else {
            MarkdownNotesPanel()
        }
    }
}

struct ExternalDisplayRootView: View {
    @EnvironmentObject private var store: PresentationStore

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch store.externalDisplayMode {
            case .slideOnly:
                if let document = store.pdfDocument {
                    PDFDocumentView(document: document, pageIndex: store.currentPageIndex, interactionEnabled: false)
                        .ignoresSafeArea()
                } else {
                    Text("Nexlide")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                }
            case .presenterMode:
                PresenterConsoleView(
                    showPDFPicker: {},
                    showProjectPicker: {},
                    showProjectExporter: {},
                    showNotesPicker: {},
                    showSettings: {},
                    showPencilSettings: {}
                )
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct ThumbnailStripView: View {
    @EnvironmentObject private var store: PresentationStore

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(0..<store.pageCount, id: \.self) { index in
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(.sRGB, white: 0.12, opacity: 1))

                                if let document = store.pdfDocument {
                                    PDFDocumentView(document: document, pageIndex: index, interactionEnabled: false)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }

                                if store.hasNote(for: index) {
                                    VStack {
                                        HStack {
                                            Spacer()
                                            Image(systemName: "pin.fill")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                                .padding(6)
                                                .background(Color.blue, in: Circle())
                                        }
                                        Spacer()
                                    }
                                    .padding(12)
                                }
                            }
                            .aspectRatio(16.0 / 9.0, contentMode: .fit)
                            .padding(8)
                            .background(selectionBackground(for: index), in: RoundedRectangle(cornerRadius: 4))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                store.goToPage(index)
                            }

                            Text("\(index + 1)")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        .id(index)
                    }
                }
                .padding(.vertical, 18)
                .padding(.horizontal, 12)
            }
            .background(Color(.sRGB, white: 0.14, opacity: 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onAppear {
                proxy.scrollTo(store.currentPageIndex, anchor: .center)
            }
            .onChange(of: store.currentPageIndex) { _, newValue in
                withAnimation(.snappy(duration: 0.2)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    private func selectionBackground(for index: Int) -> Color {
        index == store.currentPageIndex ? Color.blue.opacity(0.82) : Color.clear
    }
}

private struct SlidePreviewPanel: View {
    @EnvironmentObject private var store: PresentationStore
    let title: String
    let pageIndex: Int

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let document = store.pdfDocument, pageIndex >= 0, pageIndex < store.pageCount {
                    PDFDocumentView(document: document, pageIndex: pageIndex, interactionEnabled: false)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    Text("次のスライドはありません")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                VStack {
                    HStack {
                        Text(title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.62), in: Capsule())
                        Spacer()
                    }
                    Spacer()
                }
                .padding(6)
            }
        }
        .background(.black)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct TimePill: View {
    @EnvironmentObject private var store: PresentationStore

    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(store.elapsedSeconds.stopwatchText)
                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
            Text(timeDetailText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.68))
        }
        .padding(.horizontal, 22)
        .frame(minWidth: 220, maxWidth: 280, minHeight: 54)
        .background(.black, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.82), lineWidth: 2))
    }

    private var timeDetailText: String {
        let pageText = "p.\(store.currentPageIndex + 1)/\(max(store.pageCount, 1))"
        guard let latestLap = store.latestLap else { return pageText }
        return "\(pageText)  Lap \(latestLap.seconds.stopwatchText) p.\(latestLap.pageNumber)"
    }
}

private struct CircleToolbarButton: View {
    let systemName: String
    let accessibilityLabel: String
    var tint: Color = .black
    var stroke: Color = .white.opacity(0.82)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.headline)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(tint, in: Circle())
        .overlay(Circle().stroke(stroke, lineWidth: 2))
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct MenuToolbarButton<Content: View>: View {
    let systemName: String
    let accessibilityLabel: String
    @ViewBuilder let menuItems: () -> Content

    var body: some View {
        Menu {
            menuItems()
        } label: {
            Image(systemName: systemName)
                .font(.title2)
                .frame(width: 54, height: 54)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(.black, in: Circle())
        .overlay(Circle().stroke(.white.opacity(0.82), lineWidth: 2))
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct MarkdownNotesPanel: View {
    @EnvironmentObject private var store: PresentationStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("原稿")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)

            ZStack(alignment: .topLeading) {
                if store.currentNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView(
                        "このページに原稿ピンはありません",
                        systemImage: "pin.slash",
                        description: Text("区切り編集でページに原稿を刺すと、Nowのページに合わせてここへ表示されます。")
                    )
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        if store.noteDisplayMode == .markdown {
                            Text(markdownText)
                                .font(.system(size: store.noteFontSize))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(18)
                        } else {
                            Text(plainText)
                                .font(.system(size: store.noteFontSize))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(18)
                        }
                    }
                }
            }
            .background(.black)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(0)
    }

    private var markdownText: AttributedString {
        (try? AttributedString(markdown: store.currentNote)) ?? AttributedString(store.currentNote)
    }

    private var plainText: String {
        PresentationStore.markdownToPlainText(store.currentNote)
    }
}

private struct NotePinEditorPanel: View {
    @EnvironmentObject private var store: PresentationStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("区切り編集", systemImage: "pin.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                Text(store.hasNote(for: store.currentPageIndex) ? "ピンあり" : "未設定")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(store.hasNote(for: store.currentPageIndex) ? Color.blue.opacity(0.78) : Color.white.opacity(0.16), in: Capsule())

                Text("p.\(store.currentPageIndex + 1)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.78))
            }

            TextEditor(text: Binding(
                get: { store.note(for: store.currentPageIndex) },
                set: { store.setNote($0, for: store.currentPageIndex) }
            ))
            .font(.system(size: 22, weight: .regular, design: .monospaced))
            .scrollContentBackground(.hidden)
            .background(.black)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text("左のページ一覧でページを選び、ここにMarkdown原稿を書くと、そのページにピン留めされます。文字を消して空にすると、そのページのピンは削除されます。")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.62))
        }
        .padding(0)
    }
}

private struct LapHistoryPanel: View {
    @EnvironmentObject private var store: PresentationStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Lap History")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                Button(role: .destructive, action: store.clearLapRecords) {
                    Label("消去", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(store.lapRecords.isEmpty)
            }

            ScrollView {
                LazyVStack(spacing: 10) {
                    if store.lapRecords.isEmpty {
                        ContentUnavailableView(
                            "ラップ履歴なし",
                            systemImage: "flag",
                            description: Text("ラップボタンを押すと、時刻とページ番号がここに残ります。")
                        )
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.top, 48)
                    } else {
                        ForEach(Array(store.lapRecords.enumerated()).reversed(), id: \.element.id) { index, lap in
                            LapHistoryRow(number: index + 1, lap: lap)
                        }
                    }
                }
                .padding(12)
            }
            .background(.black)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.78), lineWidth: 2)
            )
        }
    }
}

private struct LapHistoryRow: View {
    let number: Int
    let lap: LapRecord

    var body: some View {
        HStack(spacing: 14) {
            Text("#\(number)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 54, alignment: .leading)

            Text(lap.seconds.stopwatchText)
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white)

            Spacer()

            Text("p.\(lap.pageNumber)")
                .font(.title3.monospacedDigit().weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.76), in: Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.sRGB, white: 0.08, opacity: 1), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct NoteEditorControlsBar: View {
    @EnvironmentObject private var store: PresentationStore
    @Binding var showsNotePinEditor: Bool
    let showNotesPicker: () -> Void
    let showSettings: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            CircleToolbarButton(
                systemName: "chevron.left",
                accessibilityLabel: "前のページ",
                action: store.goPrevious
            )
            .disabled(!store.canGoPrevious)

            CircleToolbarButton(
                systemName: "chevron.right",
                accessibilityLabel: "次のページ",
                action: store.goNext
            )
            .disabled(!store.canGoNext)

            Spacer(minLength: 12)

            CircleToolbarButton(
                systemName: "trash",
                accessibilityLabel: "このページの原稿ピンを削除",
                action: store.clearCurrentNote
            )
            .disabled(!store.hasNote(for: store.currentPageIndex))

            MenuToolbarButton(systemName: "text.badge.plus", accessibilityLabel: "Markdownテンプレート") {
                Button("見出しを追加", systemImage: "textformat.size") {
                    store.appendToCurrentNote("## ")
                }
                Button("箇条書きを追加", systemImage: "list.bullet") {
                    store.appendToCurrentNote("- ")
                }
                Button("メモ枠を追加", systemImage: "quote.bubble") {
                    store.appendToCurrentNote("> ")
                }
            }

            CircleToolbarButton(
                systemName: "text.page",
                accessibilityLabel: "原稿ファイルを取り込む",
                action: showNotesPicker
            )

            Spacer(minLength: 12)

            Text("p.\(store.currentPageIndex + 1)/\(max(store.pageCount, 1))")
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
                .padding(.horizontal, 16)
                .frame(minHeight: 46)
                .background(.black, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.82), lineWidth: 2))

            Spacer(minLength: 12)

            CircleToolbarButton(
                systemName: "gearshape.fill",
                accessibilityLabel: "設定",
                action: showSettings
            )

            CircleToolbarButton(
                systemName: "pencil",
                accessibilityLabel: "編集を完了",
                tint: .green,
                stroke: .green.opacity(0.95),
                action: {
                    withAnimation(.snappy(duration: 0.22)) {
                        showsNotePinEditor = false
                    }
                }
            )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.black, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.blue, lineWidth: 4)
        )
    }
}

private struct BottomControlsBar: View {
    @EnvironmentObject private var store: PresentationStore
    @Binding var showsThumbnailStrip: Bool
    @Binding var showsLapHistory: Bool
    @Binding var showsNotePinEditor: Bool
    let showPDFPicker: () -> Void
    let showProjectPicker: () -> Void
    let showProjectExporter: () -> Void
    let showNotesPicker: () -> Void
    let showSettings: () -> Void
    let showPencilSettings: () -> Void

    var body: some View {
        let sidebarVisible = showsThumbnailStrip || showsNotePinEditor

        HStack(alignment: .center, spacing: 16) {
            CircleToolbarButton(
                systemName: sidebarVisible ? "rectangle.stack.fill" : "sidebar.left",
                accessibilityLabel: sidebarVisible ? "ページ一覧を表示中" : "ページ一覧を開く"
            ) {
                withAnimation(.snappy(duration: 0.22)) {
                    if !showsNotePinEditor {
                        showsThumbnailStrip.toggle()
                    }
                }
            }

            CircleToolbarButton(
                systemName: "pencil",
                accessibilityLabel: showsNotePinEditor ? "区切り編集を閉じる" : "区切り編集を開く",
                tint: showsNotePinEditor ? .green : .black,
                stroke: showsNotePinEditor ? .green.opacity(0.95) : .white.opacity(0.82)
            ) {
                withAnimation(.snappy(duration: 0.22)) {
                    showsNotePinEditor.toggle()
                    if showsNotePinEditor {
                        showsThumbnailStrip = true
                        showsLapHistory = false
                    }
                }
            }

            CircleToolbarButton(
                systemName: "chevron.left",
                accessibilityLabel: "前のスライド",
                action: store.goPrevious
            )
            .disabled(!store.canGoPrevious)

            CircleToolbarButton(
                systemName: "chevron.right",
                accessibilityLabel: "次のスライド",
                action: store.goNext
            )
            .disabled(!store.canGoNext)

            Spacer(minLength: 18)

            CircleToolbarButton(
                systemName: "checkmark",
                accessibilityLabel: "ラップタイムを記録",
                action: store.recordLap
            )

            CircleToolbarButton(
                systemName: showsLapHistory ? "text.alignleft" : "list.bullet.rectangle",
                accessibilityLabel: showsLapHistory ? "原稿を表示" : "ラップ履歴を表示"
            ) {
                withAnimation(.snappy(duration: 0.2)) {
                    showsLapHistory.toggle()
                    if showsLapHistory {
                        showsNotePinEditor = false
                    }
                }
            }

            TimePill()

            CircleToolbarButton(
                systemName: store.isTimerRunning ? "pause.fill" : "play.fill",
                accessibilityLabel: store.isTimerRunning ? "タイマーを停止" : "タイマーを開始",
                action: store.toggleTimer
            )

            CircleToolbarButton(
                systemName: "arrow.counterclockwise",
                accessibilityLabel: "秒数をリセット",
                action: store.resetElapsedSeconds
            )

            Spacer(minLength: 18)

            CircleToolbarButton(
                systemName: store.noteDisplayMode == .off ? "eye.slash" : "eye",
                accessibilityLabel: store.noteDisplayMode == .off ? "原稿を表示" : "原稿を隠す",
                tint: store.noteDisplayMode == .off ? .black : .blue.opacity(0.84),
                stroke: store.noteDisplayMode == .off ? .white.opacity(0.82) : .blue.opacity(0.96)
            ) {
                withAnimation(.snappy(duration: 0.22)) {
                    store.toggleNoteDisplayVisibility()
                    showsLapHistory = false
                    showsNotePinEditor = false
                }
            }

            MenuToolbarButton(systemName: "gearshape.fill", accessibilityLabel: "設定とファイル") {
                Button("PDFを選び直す", systemImage: "doc") {
                    showPDFPicker()
                }
                Button("プロジェクトを開く", systemImage: "folder") {
                    showProjectPicker()
                }
                Button("プロジェクトを書き出す", systemImage: "square.and.arrow.up") {
                    showProjectExporter()
                }
                .disabled(!store.canExportProject)
                Button("原稿を取り込む", systemImage: "text.page") {
                    showNotesPicker()
                }
                Button("Apple Pencil設定", systemImage: "pencil.tip") {
                    showPencilSettings()
                }
                Button("設定", systemImage: "gearshape") {
                    showSettings()
                }
                Button("タイマーをリセット", systemImage: "arrow.counterclockwise") {
                    store.resetTimer()
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.black, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.blue, lineWidth: 4)
        )
    }
}
