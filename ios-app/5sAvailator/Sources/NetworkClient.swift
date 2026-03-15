// NetworkClient.swift
// Handles all HTTP communication with the 5sAvailator server.
// Uses URLSession with explicit request/response models.

import Foundation

// MARK: - Request / Response models

struct CreateSessionResponse: Decodable {
    let sessionId: String
    let token: String
    let viewportWidth: Int
    let viewportHeight: Int
}

struct SessionStateResponse: Decodable {
    let id: String
    let url: String?
    let title: String?
    let createdAt: TimeInterval
    let lastActivityAt: TimeInterval
    let viewportWidth: Int
    let viewportHeight: Int
}

struct OKResponse: Decodable {
    let ok: Bool
}

struct ServerError: Decodable, LocalizedError {
    let error: String
    let code: String
    var errorDescription: String? { "\(code): \(error)" }
}

// MARK: - NetworkClient

/// Thin HTTP client for the 5sAvailator server REST API.
/// All methods execute on a background queue and call the completion handler on the main queue.
final class NetworkClient {

    let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - Sessions

    /// POST /sessions
    func createSession(
        viewportWidth: Int = 320,
        viewportHeight: Int = 568,
        url: String? = nil,
        completion: @escaping (Result<CreateSessionResponse, Error>) -> Void
    ) {
        var body: [String: Any] = [
            "viewportWidth": viewportWidth,
            "viewportHeight": viewportHeight,
        ]
        if let url = url { body["url"] = url }
        performJSON(method: "POST", path: "/sessions", token: nil, body: body, completion: completion)
    }

    /// POST /sessions/:id/navigate
    func navigate(
        sessionId: String,
        token: String,
        url: String,
        completion: @escaping (Result<OKResponse, Error>) -> Void
    ) {
        let body: [String: Any] = ["url": url]
        performJSON(method: "POST", path: "/sessions/\(sessionId)/navigate", token: token, body: body, completion: completion)
    }

    /// GET /sessions/:id/frame  → JPEG data
    func getFrame(
        sessionId: String,
        token: String,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        let url = baseURL.appendingPathComponent("/sessions/\(sessionId)/frame")
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        execute(request: req) { result in
            switch result {
            case .success(let (data, response)):
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    completion(.failure(Self.parseServerError(data: data, statusCode: http.statusCode)))
                } else {
                    completion(.success(data))
                }
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }

    /// POST /sessions/:id/input/tap
    func tap(
        sessionId: String,
        token: String,
        x: Double,
        y: Double,
        completion: @escaping (Result<OKResponse, Error>) -> Void
    ) {
        let body: [String: Any] = ["x": x, "y": y]
        performJSON(method: "POST", path: "/sessions/\(sessionId)/input/tap", token: token, body: body, completion: completion)
    }

    /// POST /sessions/:id/input/scroll
    func scroll(
        sessionId: String,
        token: String,
        x: Double,
        y: Double,
        deltaX: Double,
        deltaY: Double,
        completion: @escaping (Result<OKResponse, Error>) -> Void
    ) {
        let body: [String: Any] = ["x": x, "y": y, "deltaX": deltaX, "deltaY": deltaY]
        performJSON(method: "POST", path: "/sessions/\(sessionId)/input/scroll", token: token, body: body, completion: completion)
    }

    /// POST /sessions/:id/input/text
    func typeText(
        sessionId: String,
        token: String,
        text: String,
        completion: @escaping (Result<OKResponse, Error>) -> Void
    ) {
        let body: [String: Any] = ["text": text]
        performJSON(method: "POST", path: "/sessions/\(sessionId)/input/text", token: token, body: body, completion: completion)
    }

    /// GET /sessions/:id/state
    func getState(
        sessionId: String,
        token: String,
        completion: @escaping (Result<SessionStateResponse, Error>) -> Void
    ) {
        performJSON(method: "GET", path: "/sessions/\(sessionId)/state", token: token, body: nil, completion: completion)
    }

    /// DELETE /sessions/:id
    func deleteSession(
        sessionId: String,
        token: String,
        completion: @escaping (Result<OKResponse, Error>) -> Void
    ) {
        performJSON(method: "DELETE", path: "/sessions/\(sessionId)", token: token, body: nil, completion: completion)
    }

    // MARK: - Private helpers

    private func performJSON<T: Decodable>(
        method: String,
        path: String,
        token: String?,
        body: [String: Any]?,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        let url = baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = body {
            do {
                req.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
        }

        execute(request: req) { result in
            switch result {
            case .success(let (data, response)):
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 200
                if !(200..<300).contains(statusCode) {
                    let err = Self.parseServerError(data: data, statusCode: statusCode)
                    completion(.failure(err))
                    return
                }
                do {
                    let decoded = try JSONDecoder().decode(T.self, from: data)
                    completion(.success(decoded))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }

    private func execute(
        request: URLRequest,
        completion: @escaping (Result<(Data, URLResponse), Error>) -> Void
    ) {
        let task = session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let data = data, let response = response else {
                    completion(.failure(NetworkError.emptyResponse))
                    return
                }
                completion(.success((data, response)))
            }
        }
        task.resume()
    }

    private static func parseServerError(data: Data, statusCode: Int) -> Error {
        if let serverErr = try? JSONDecoder().decode(ServerError.self, from: data) {
            return serverErr
        }
        return NetworkError.httpError(statusCode: statusCode)
    }
}

// MARK: - NetworkError

enum NetworkError: LocalizedError {
    case emptyResponse
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .emptyResponse: return "Server returned an empty response."
        case .httpError(let code): return "HTTP error \(code)."
        }
    }
}
