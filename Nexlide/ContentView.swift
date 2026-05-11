import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: PresentationStore
    @State private var showingPDFPicker = false
    @State private var showingProjectPicker = false
    @State private var showingProjectExporter = false
    @State private var showingNotesPicker = false
    @State private var showingSettings = false
    @State private var showingPencilSettings = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if store.pdfDocument == nil {
                WelcomeView(
                    selectPDF: { showingPDFPicker = true },
                    openProject: { showingProjectPicker = true }
                )
            } else {
                PresenterConsoleView(
                    showPDFPicker: { showingPDFPicker = true },
                    showProjectPicker: { showingProjectPicker = true },
                    showProjectExporter: {
                        store.saveProjectPackage()
                        showingProjectExporter = true
                    },
                    showNotesPicker: { showingNotesPicker = true },
                    showSettings: { showingSettings = true },
                    showPencilSettings: { showingPencilSettings = true }
                )
            }
        }
        .sheet(isPresented: $showingPDFPicker) {
            PDFDocumentPicker { url in
                store.openPDF(from: url)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showingProjectPicker) {
            ProjectDocumentPicker { url in
                store.openProject(from: url)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showingProjectExporter) {
            if let url = store.projectPackageURL {
                ProjectDocumentExporter(url: url)
                    .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showingNotesPicker) {
            NotesDocumentPicker { url in
                store.importNotes(from: url)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showingPencilSettings) {
            ApplePencilSettingsView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
        .onAppear {
            store.updateExternalDisplayStatus()
        }
    }
}

private struct WelcomeView: View {
    let selectPDF: () -> Void
    let openProject: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 10) {
                Text("Nexlide")
                    .font(.system(size: 48, weight: .bold))
                Text("Apple PencilでPDFプレゼンを進めるiPadアプリ")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Button(action: selectPDF) {
                Label("PDFを選択", systemImage: "doc.badge.plus")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)

            Button(action: openProject) {
                Label("Nexlideプロジェクトを開く", systemImage: "folder")
                    .font(.headline.weight(.semibold))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
        }
        .foregroundStyle(.white)
        .padding(40)
    }
}

private struct SlidePresentationView: View {
    @EnvironmentObject private var store: PresentationStore
    let showPDFPicker: () -> Void
    let showNotesPicker: () -> Void
    let showSettings: () -> Void

    var body: some View {
        ZStack {
            if let document = store.pdfDocument {
                PDFDocumentView(document: document, pageIndex: store.currentPageIndex, interactionEnabled: false)
                    .ignoresSafeArea()
            }

            PageInputOverlay()

            VStack {
                HStack {
                    Button(action: store.closePDF) {
                        Label("戻る", systemImage: "chevron.left")
                    }

                    Button(action: showPDFPicker) {
                        Label("PDF選択", systemImage: "doc")
                    }

                    Button(action: showNotesPicker) {
                        Label("原稿", systemImage: "text.page")
                    }

                    Button(action: showSettings) {
                        Label("設定", systemImage: "gearshape")
                    }

                    Spacer()

                    PageCounterView()
                }
                .font(.footnote.weight(.semibold))
                .buttonStyle(.bordered)
                .tint(.white)
                .padding(14)
                .background(.black.opacity(0.46))

                Spacer()
            }
        }
        .background(.black)
        .overlay {
            PencilInteractionOverlay()
            KeyboardShortcutOverlay()
        }
    }
}

private struct PageInputOverlay: View {
    @EnvironmentObject private var store: PresentationStore

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        store.goPrevious()
                    }

                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        store.goNext()
                    }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .gesture(
            DragGesture(minimumDistance: 36)
                .onEnded { value in
                    if value.translation.width < -40 {
                        store.goNext()
                    } else if value.translation.width > 40 {
                        store.goPrevious()
                    }
                }
        )
    }
}

struct PageCounterView: View {
    @EnvironmentObject private var store: PresentationStore

    var body: some View {
        Text("\(store.currentPageIndex + 1) / \(max(store.pageCount, 1))")
            .font(.footnote.monospacedDigit().weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.black.opacity(0.58), in: Capsule())
            .foregroundStyle(.white)
            .accessibilityLabel("現在ページ \(store.currentPageIndex + 1)、総ページ数 \(store.pageCount)")
    }
}
