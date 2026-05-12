import SwiftUI
import UIKit

@MainActor
final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let rootView = ExternalDisplayRootView()
            .environmentObject(PresentationStore.shared)
            .preferredColorScheme(.dark)

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: rootView)
        window.overrideUserInterfaceStyle = .dark
        self.window = window
        window.makeKeyAndVisible()

        PresentationStore.shared.externalDisplayActive = true
        PresentationStore.shared.updateExternalDisplayPixelSize(from: windowScene)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        PresentationStore.shared.externalDisplayActive = false
        PresentationStore.shared.updateExternalDisplayStatus()
    }
}
