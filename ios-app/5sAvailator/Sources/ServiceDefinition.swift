// ServiceDefinition.swift
// Defines a single service entry shown in the launcher.

import Foundation

/// Modes available for a service.
enum ServiceMode: String, Codable {
    /// Open the URL inside a local WKWebView (simple/compatible sites).
    case localWeb
    /// Open the URL in a remote browser session on the server.
    case remoteBrowser
}

/// A configured service displayed in the launcher.
struct ServiceDefinition: Codable {
    let id: String
    let name: String
    let url: String
    let mode: ServiceMode
    let iconSystemName: String

    init(id: String = UUID().uuidString,
         name: String,
         url: String,
         mode: ServiceMode,
         iconSystemName: String = "globe") {
        self.id = id
        self.name = name
        self.url = url
        self.mode = mode
        self.iconSystemName = iconSystemName
    }
}

/// Default set of services shown on first launch.
extension ServiceDefinition {
    static let defaults: [ServiceDefinition] = [
        ServiceDefinition(
            name: "Example (Local)",
            url: "https://example.com",
            mode: .localWeb,
            iconSystemName: "doc.text"
        ),
        ServiceDefinition(
            name: "Google (Remote)",
            url: "https://www.google.com",
            mode: .remoteBrowser,
            iconSystemName: "magnifyingglass"
        ),
    ]
}
