import Foundation
import Supabase

enum ApiError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case httpError(Int, String)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:              return "Invalid URL"
        case .networkError(let e):     return e.localizedDescription
        case .httpError(let c, let m): return "HTTP \(c): \(m)"
        case .decodingError(let e):    return e.localizedDescription
        }
    }
}

final class ApiClient {
    static let shared = ApiClient()

    private static let productionURL = "https://elos.onrender.com"

    /// Debug builds default to production too, so an install from Xcode always
    /// has a live backend. Point at a local server explicitly with the
    /// "-use-local-api" launch argument (Scheme → Run → Arguments) or by setting
    /// the "api_base_url" UserDefault to any URL.
    private var baseURL: String {
        #if DEBUG
        if let override = UserDefaults.standard.string(forKey: "api_base_url"),
           !override.isEmpty {
            return override
        }
        if ProcessInfo.processInfo.arguments.contains("-use-local-api") {
            return "http://localhost:3000"
        }
        #endif
        return Self.productionURL
    }

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 30
        cfg.timeoutIntervalForResource = 60
        return URLSession(configuration: cfg)
    }()

    private func makeRequest(method: String, path: String, body: (any Encodable)? = nil) async throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else { throw ApiError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = try? await SupabaseManager.shared.client.auth.session.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        return request
    }

    func post<B: Encodable, R: Decodable>(_ path: String, body: B) async throws -> R {
        try await send(method: "POST", path: path, body: body)
    }

    func get<R: Decodable>(_ path: String) async throws -> R {
        try await send(method: "GET", path: path, body: nil)
    }

    func patch<B: Encodable, R: Decodable>(_ path: String, body: B) async throws -> R {
        try await send(method: "PATCH", path: path, body: body)
    }

    func put<B: Encodable, R: Decodable>(_ path: String, body: B) async throws -> R {
        try await send(method: "PUT", path: path, body: body)
    }

    func delete<R: Decodable>(_ path: String) async throws -> R {
        try await send(method: "DELETE", path: path, body: nil)
    }

    /// Build → perform, and on a 401 force a session refresh and retry once
    /// (covers a request that races a just-expired access token). GETs also
    /// retry transient transport failures with backoff — the production host
    /// cold-starts after idle, so the first request of a session can time out
    /// while later ones succeed in milliseconds.
    private func send<R: Decodable>(method: String, path: String, body: (any Encodable)?) async throws -> R {
        let transientRetries = method == "GET" ? 2 : 0
        var attempt = 0
        while true {
            do {
                let request = try await makeRequest(method: method, path: path, body: body)
                return try await perform(request)
            } catch ApiError.httpError(401, _) {
                _ = try? await SupabaseManager.shared.client.auth.refreshSession()
                let retry = try await makeRequest(method: method, path: path, body: body)
                return try await perform(retry)
            } catch let error as ApiError where attempt < transientRetries && isTransient(error) {
                attempt += 1
                try? await Task.sleep(nanoseconds: UInt64(attempt) * 2_000_000_000)
            }
        }
    }

    /// Errors worth retrying: the request likely never reached the server.
    private func isTransient(_ error: ApiError) -> Bool {
        guard case .networkError(let underlying) = error,
              let urlError = underlying as? URLError else { return false }
        switch urlError.code {
        case .timedOut, .cannotConnectToHost, .networkConnectionLost, .cannotFindHost:
            return true
        default:
            return false
        }
    }

    /// Fire-and-forget ping so the server is awake (Render cold-starts after
    /// idle) before login-time data loads pile onto it.
    func warmup() async {
        _ = try? await get("/health") as [String: String]
    }

    func deleteNoContent(_ path: String) async throws {
        func attempt() async throws -> Int {
            let request = try await makeRequest(method: "DELETE", path: path)
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode ?? 0
        }
        // Mirror send()'s 401 refresh-and-retry-once so a just-expired token doesn't fail the delete.
        var status = try await attempt()
        if status == 401 {
            _ = try? await SupabaseManager.shared.client.auth.refreshSession()
            status = try await attempt()
        }
        guard status == 204 else {
            throw ApiError.httpError(status, "Expected 204 No Content")
        }
    }

    private func perform<R: Decodable>(_ request: URLRequest) async throws -> R {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw ApiError.networkError(URLError(.badServerResponse))
            }
            guard (200..<300).contains(http.statusCode) else {
                let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw ApiError.httpError(http.statusCode, msg)
            }
            return try JSONDecoder().decode(R.self, from: data)
        } catch let e as ApiError {
            throw e
        } catch let e as DecodingError {
            throw ApiError.decodingError(e)
        } catch {
            throw ApiError.networkError(error)
        }
    }
}
