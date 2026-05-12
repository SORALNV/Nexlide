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
                        AdjustableSlidePreviewPair()
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

private struct AdjustableSlidePreviewPair: View {
    @EnvironmentObject private var store: PresentationStore

    var body: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 12
            let availableWidth = max(geometry.size.width - spacing, 0)
            let nowWidth = availableWidth * min(max(store.nowNextSplitRatio, 0.2), 0.8)

            HStack(spacing: spacing) {
                SlidePreviewPanel(title: "Now", pageIndex: store.currentPageIndex, prominentTitle: true)
                    .frame(width: nowWidth)

                SlidePreviewPanel(title: "Next", pageIndex: store.currentPageIndex + 1, prominentTitle: true)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                                    PDFPagePreviewImage(document: document, pageIndex: index, maxPixelDimension: 520)
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
    var prominentTitle = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let document = store.pdfDocument, pageIndex >= 0, pageIndex < store.pageCount {
                    PDFPagePreviewImage(document: document, pageIndex: pageIndex, maxPixelDimension: 1440)
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
                            .font(prominentTitle ? .system(size: 34, weight: .bold) : .caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, prominentTitle ? 18 : 8)
                            .padding(.vertical, prominentTitle ? 10 : 4)
                            .background(.black.opacity(0.62), in: Capsule())
                        Spacer()
                    }
                    Spacer()
                }
                .padding(prominentTitle ? 14 : 6)
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

private struct GearPopoverButton: View {
    @EnvironmentObject private var store: PresentationStore
    @Binding var showsLapHistory: Bool
    @Binding var showsNotePinEditor: Bool
    let showPDFPicker: () -> Void
    let showProjectPicker: () -> Void
    let showProjectExporter: () -> Void
    let showNotesPicker: () -> Void
    let showSettings: () -> Void
    let showPencilSettings: () -> Void
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.title2)
                .frame(width: 54, height: 54)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(.black, in: Circle())
        .overlay(Circle().stroke(.white.opacity(0.82), lineWidth: 2))
        .accessibilityLabel("設定とファイル")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Text("プレゼン")
                        .font(.headline)
                        .foregroundStyle(store.noteDisplayMode == .off ? .white : .white.opacity(0.52))

                    Toggle("", isOn: noteModeBinding)
                        .labelsHidden()
                        .tint(.blue)

                    Text("原稿")
                        .font(.headline)
                        .foregroundStyle(store.noteDisplayMode == .off ? .white.opacity(0.52) : .white)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.sRGB, white: 0.1, opacity: 1), in: RoundedRectangle(cornerRadius: 8))

                Divider()
                    .overlay(.white.opacity(0.2))

                SettingsPopoverAction(title: "PDFを選び直す", systemName: "doc") {
                    isPresented = false
                    showPDFPicker()
                }

                SettingsPopoverAction(title: "プロジェクトを開く", systemName: "folder") {
                    isPresented = false
                    showProjectPicker()
                }

                SettingsPopoverAction(title: "プロジェクトを書き出す", systemName: "square.and.arrow.up", disabled: !store.canExportProject) {
                    isPresented = false
                    showProjectExporter()
                }

                SettingsPopoverAction(title: "原稿を取り込む", systemName: "text.page") {
                    isPresented = false
                    showNotesPicker()
                }

                Divider()
                    .overlay(.white.opacity(0.2))

                SettingsPopoverAction(title: "Apple Pencil設定", systemName: "pencil.tip") {
                    isPresented = false
                    showPencilSettings()
                }

                SettingsPopoverAction(title: "設定", systemName: "gearshape") {
                    isPresented = false
                    showSettings()
                }

                SettingsPopoverAction(title: "タイマーをリセット", systemName: "arrow.counterclockwise") {
                    isPresented = false
                    store.resetTimer()
                }
            }
            .padding(16)
            .frame(width: 330)
            .background(Color(.sRGB, white: 0.05, opacity: 1))
            .preferredColorScheme(.dark)
        }
    }

    private var noteModeBinding: Binding<Bool> {
        Binding(
            get: { store.noteDisplayMode != .off },
            set: { isNoteMode in
                withAnimation(.snappy(duration: 0.22)) {
                    if isNoteMode != (store.noteDisplayMode != .off) {
                        store.toggleNoteDisplayVisibility()
                    }
                    showsLapHistory = false
                    showsNotePinEditor = false
                }
            }
        )
    }
}

private struct SettingsPopoverAction: View {
    let title: String
    let systemName: String
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(disabled ? .white.opacity(0.32) : .white)
        .disabled(disabled)
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

            if store.noteDisplayMode == .off && !showsLapHistory {
                NowNextRatioControl()
            }

            Spacer(minLength: 18)

            if store.isTimerRunning {
                CircleToolbarButton(
                    systemName: "checkmark",
                    accessibilityLabel: "ラップタイムを記録",
                    action: store.recordLap
                )
            }

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

            Spacer(minLength: 18)

            HStack(spacing: 10) {
                if store.externalDisplayActive {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("connecting")
                        Text(store.externalDisplayPixelSizeText ?? "detecting")
                    }
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Color.green.opacity(0.78))
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(.black, in: Capsule())
                    .overlay(Capsule().stroke(Color.green.opacity(0.42), lineWidth: 1.5))
                }

                GearPopoverButton(
                    showsLapHistory: $showsLapHistory,
                    showsNotePinEditor: $showsNotePinEditor,
                    showPDFPicker: showPDFPicker,
                    showProjectPicker: showProjectPicker,
                    showProjectExporter: showProjectExporter,
                    showNotesPicker: showNotesPicker,
                    showSettings: showSettings,
                    showPencilSettings: showPencilSettings
                )

            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.black, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct NowNextRatioControl: View {
    @EnvironmentObject private var store: PresentationStore

    var body: some View {
        HStack(spacing: 10) {
            Text("Now")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.78))

            Slider(
                value: Binding(
                    get: { store.nowNextSplitRatio },
                    set: { store.nowNextSplitRatio = min(max($0, 0.2), 0.8) }
                ),
                in: 0.2...0.8,
                step: 0.01
            )
            .frame(width: 220)
            .tint(.blue)

            Text("Next")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.78))
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(.black, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.82), lineWidth: 2))
        .accessibilityLabel("NowとNextの表示比率")
    }
}
