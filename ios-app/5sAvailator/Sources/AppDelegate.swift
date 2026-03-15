// AppDelegate.swift
// App entry point. Configures the server URL and bootstraps the launcher.

import UIKit

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Server base URL — override via SERVER_URL environment variable or change here.
        let serverURLString = ProcessInfo.processInfo.environment["SERVER_URL"]
            ?? "http://localhost:3000"
        guard let serverURL = URL(string: serverURLString) else {
            fatalError("Invalid SERVER_URL: \(serverURLString)")
        }

        let client = NetworkClient(baseURL: serverURL)
        let sessionStore = SessionStore(client: client)

        // Load services from UserDefaults if persisted, or use defaults on first launch.
        let services = loadServices() ?? ServiceDefinition.defaults

        let launcher = LauncherViewController(
            services: services,
            client: client,
            sessionStore: sessionStore
        )
        let nav = UINavigationController(rootViewController: launcher)

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = nav
        window.makeKeyAndVisible()
        self.window = window

        return true
    }

    // MARK: - Service persistence

    private func loadServices() -> [ServiceDefinition]? {
        guard let data = UserDefaults.standard.data(forKey: "services") else { return nil }
        return try? JSONDecoder().decode([ServiceDefinition].self, from: data)
    }

    static func saveServices(_ services: [ServiceDefinition]) {
        guard let data = try? JSONEncoder().encode(services) else { return }
        UserDefaults.standard.set(data, forKey: "services")
    }
}
