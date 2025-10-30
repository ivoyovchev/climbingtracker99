import Foundation

struct MoonBoardProblem: Decodable {
    let id: String
    let name: String
    let grade: String
    let board: String?
}

struct MoonBoardLogEntryDTO: Decodable {
    let date: String
    let problem: MoonBoardProblem
    let attempts: Int
    let sent: Bool
}

enum MoonBoardClientError: Error {
    case invalidCredentials
    case networkError(Error)
    case decodingError
    case unsupported
}

final class MoonBoardClient {
    static let shared = MoonBoardClient()
    private init() {}
    
    // Configure endpoints if needed; placeholder base illustrates structure
    var baseURL: URL = URL(string: "https://www.moonboard.com")!
    var loginPath: String = "/api/login"
    var logbookPath: String = "/api/logbook"
    
    func login(username: String, password: String) async throws -> String {
        let url = baseURL.appending(path: loginPath)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["username": username, "password": password]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw MoonBoardClientError.decodingError }
            guard (200..<300).contains(http.statusCode) else {
                if http.statusCode == 401 { throw MoonBoardClientError.invalidCredentials }
                throw MoonBoardClientError.unsupported
            }
            // Expecting { accessToken: "..." }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let token = json["accessToken"] as? String {
                return token
            }
            throw MoonBoardClientError.decodingError
        } catch {
            throw MoonBoardClientError.networkError(error)
        }
    }
    
    func fetchLogbook(accessToken: String, since: Date?) async throws -> [MoonBoardLogEntryDTO] {
        let url = baseURL.appending(path: logbookPath)
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        if let since = since {
            comps.queryItems = [URLQueryItem(name: "since", value: ISO8601DateFormatter().string(from: since))]
        }
        guard let finalURL = comps.url else { throw MoonBoardClientError.unsupported }
        var req = URLRequest(url: finalURL)
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw MoonBoardClientError.unsupported
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            // Accept either an array or an envelope
            if let entries = try? decoder.decode([MoonBoardLogEntryDTO].self, from: data) {
                return entries
            }
            // If wrapped: { items: [...] }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let itemsData = try? JSONSerialization.data(withJSONObject: json["items"] ?? []) {
                return (try? decoder.decode([MoonBoardLogEntryDTO].self, from: itemsData)) ?? []
            }
            throw MoonBoardClientError.decodingError
        } catch {
            throw MoonBoardClientError.networkError(error)
        }
    }
}


