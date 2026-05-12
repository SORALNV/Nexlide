import SwiftUI
import UIKit

struct PencilInteractionOverlay: UIViewRepresentable {
    @EnvironmentObject private var store: PresentationStore

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    func makeUIView(context: Context) -> UIView {
        let view = PassthroughPencilView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        let interaction = UIPencilInteraction()
        interaction.delegate = context.coordinator
        view.addInteraction(interaction)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.store = store
    }

    final class Coordinator: NSObject, UIPencilInteractionDelegate {
        weak var store: PresentationStore?
        private var lastEventTime: TimeInterval = 0
        private var squeezeRepeatTask: Task<Void, Never>?

        init(store: PresentationStore) {
            self.store = store
        }

        // Apple does not expose a public API for reliably reading the exact Apple Pencil model.
        // Nexlide therefore reacts to capabilities that the OS reports: double tap and squeeze.
        func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
            handle(.doubleTap)
        }

        func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveTap tap: UIPencilInteraction.Tap) {
            handle(.doubleTap)
        }

        // The squeeze API is available on Apple Pencil Pro and only on supported iPadOS/devices.
        func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
            switch squeeze.phase {
            case .began:
                handle(.squeeze)
                beginSqueezeRepeatIfNeeded()
            case .changed:
                break
            case .ended, .cancelled:
                stopSqueezeRepeat()
            @unknown default:
                stopSqueezeRepeat()
            }
        }

        private func handle(_ inputKind: PencilInputKind) {
            let now = CACurrentMediaTime()
            guard now - lastEventTime > 0.16 else { return }
            lastEventTime = now

            Task { @MainActor in
                self.store?.performPencilAction(inputKind)
            }
        }

        private func beginSqueezeRepeatIfNeeded() {
            guard store?.squeezeHoldRepeatEnabled == true else { return }

            stopSqueezeRepeat()
            squeezeRepeatTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(520))

                while !Task.isCancelled {
                    await MainActor.run {
                        self?.store?.performPencilAction(.squeeze)
                    }
                    try? await Task.sleep(for: .milliseconds(260))
                }
            }
        }

        private func stopSqueezeRepeat() {
            squeezeRepeatTask?.cancel()
            squeezeRepeatTask = nil
        }
    }

    final class PassthroughPencilView: UIView {
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            false
        }
    }
}
