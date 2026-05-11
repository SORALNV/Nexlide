import SwiftUI
import UIKit

struct KeyboardShortcutOverlay: UIViewRepresentable {
    @EnvironmentObject private var store: PresentationStore

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    func makeUIView(context: Context) -> KeyCommandView {
        let view = KeyCommandView()
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: KeyCommandView, context: Context) {
        context.coordinator.store = store
        uiView.coordinator = context.coordinator
        uiView.becomeFirstResponder()
    }

    final class Coordinator {
        weak var store: PresentationStore?

        init(store: PresentationStore) {
            self.store = store
        }

        @MainActor
        func next() {
            store?.goNext()
        }

        @MainActor
        func previous() {
            store?.goPrevious()
        }
    }

    final class KeyCommandView: UIView {
        weak var coordinator: Coordinator?

        override var canBecomeFirstResponder: Bool {
            true
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            becomeFirstResponder()
        }

        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            false
        }

        override var keyCommands: [UIKeyCommand]? {
            [
                UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [], action: #selector(nextPage)),
                UIKeyCommand(input: " ", modifierFlags: [], action: #selector(nextPage)),
                UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], action: #selector(previousPage))
            ]
        }

        @objc private func nextPage() {
            Task { @MainActor in
                coordinator?.next()
            }
        }

        @objc private func previousPage() {
            Task { @MainActor in
                coordinator?.previous()
            }
        }
    }
}
