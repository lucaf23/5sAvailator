// SessionStore.swift
// Manages the lifecycle of remote browser sessions.

import Foundation

/// Live state for an active remote session.
struct RemoteSession {
    let id: String
    let token: String
    let service: ServiceDefinition
    let viewportWidth: Int
    let viewportHeight: Int
}

/// Errors produced by SessionStore.
enum SessionStoreError: LocalizedError {
    case noActiveSession
    case serverURL

    var errorDescription: String? {
        switch self {
        case .noActiveSession: return "No active remote session."
        case .serverURL: return "Server URL is not configured."
        }
    }
}

/// Manages creation and cleanup of remote browser sessions.
final class SessionStore {

    private(set) var activeSession: RemoteSession?
    private let client: NetworkClient

    init(client: NetworkClient) {
        self.client = client
    }

    // MARK: - Session lifecycle

    /// Create a new remote session for a service.
    func createSession(
        for service: ServiceDefinition,
        completion: @escaping (Result<RemoteSession, Error>) -> Void
    ) {
        // If there is already an active session, close it first.
        if let existing = activeSession {
            closeSession(sessionId: existing.id, token: existing.token) { _ in }
        }

        client.createSession(
            viewportWidth: 320,
            viewportHeight: 568,
            url: service.url
        ) { [weak self] result in
            switch result {
            case .success(let response):
                let session = RemoteSession(
                    id: response.sessionId,
                    token: response.token,
                    service: service,
                    viewportWidth: response.viewportWidth,
                    viewportHeight: response.viewportHeight
                )
                self?.activeSession = session
                completion(.success(session))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Close a specific session (does not require it to be the active one).
    func closeSession(
        sessionId: String,
        token: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        if activeSession?.id == sessionId {
            activeSession = nil
        }
        client.deleteSession(sessionId: sessionId, token: token) { result in
            switch result {
            case .success: completion(.success(()))
            case .failure(let err): completion(.failure(err))
            }
        }
    }

    /// Close the active session, if any.
    func closeActiveSession(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let session = activeSession else {
            completion(.success(()))
            return
        }
        closeSession(sessionId: session.id, token: session.token, completion: completion)
    }
}
