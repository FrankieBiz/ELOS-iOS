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

    #if DEBUG
    private let baseURL = "http://localhost:3000"
    #else
    private let baseURL = "https://elos.onrender.com"
    #endif

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
    /// (covers a request that races a just-expired access token).
    private func send<R: Decodable>(method: String, path: String, body: (any Encodable)?) async throws -> R {
        let request = try await makeRequest(method: method, path: path, body: body)
        do {
            return try await perform(request)
        } catch ApiError.httpError(401, _) {
            _ = try? await SupabaseManager.shared.client.auth.refreshSession()
            let retry = try await makeRequest(method: method, path: path, body: body)
            return try await perform(retry)
        }
    }

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
