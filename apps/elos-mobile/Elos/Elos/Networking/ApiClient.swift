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
    private let baseURL = "https://api.elos.app"
    #endif

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
        let request = try await makeRequest(method: "POST", path: path, body: body)
        return try await perform(request)
    }

    func get<R: Decodable>(_ path: String) async throws -> R {
        let request = try await makeRequest(method: "GET", path: path)
        return try await perform(request)
    }

    func patch<B: Encodable, R: Decodable>(_ path: String, body: B) async throws -> R {
        let request = try await makeRequest(method: "PATCH", path: path, body: body)
        return try await perform(request)
    }

    func delete<R: Decodable>(_ path: String) async throws -> R {
        let request = try await makeRequest(method: "DELETE", path: path)
        return try await perform(request)
    }

    func deleteNoContent(_ path: String) async throws {
        let request = try await makeRequest(method: "DELETE", path: path)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 204 else {
            throw ApiError.httpError(
                (response as? HTTPURLResponse)?.statusCode ?? 0,
                "Expected 204 No Content"
            )
        }
    }

    private func perform<R: Decodable>(_ request: URLRequest) async throws -> R {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
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
