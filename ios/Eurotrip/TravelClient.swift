import Foundation
import Security

enum TravelKeychain {
    static func read(_ name: String) -> String {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "EurotripNative", kSecAttrAccount as String: name, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?; guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return "" }; return String(data: data, encoding: .utf8) ?? ""
    }
    static func save(_ value: String, name: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "EurotripNative", kSecAttrAccount as String: name]
        if value.isEmpty { SecItemDelete(query as CFDictionary); return }
        let values: [String: Any] = [kSecValueData as String: Data(value.utf8), kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if status == errSecItemNotFound { var addition = query; values.forEach { addition[$0.key] = $0.value }; guard SecItemAdd(addition as CFDictionary, nil) == errSecSuccess else { throw TripError.invalid("Could not save the access code securely.") } }
        else if status != errSecSuccess { throw TripError.invalid("Could not update the secure access code.") }
    }
}
final class TravelRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
struct TravelClient {
    var endpoint = "https://eurotrip-planner.onrender.com"
    var accessCode = ""
    var configuration = URLSessionConfiguration.ephemeral
    func request(_ path: String, query: [String: String] = [:], body: [String: JSONValue]? = nil) async throws -> JSONValue {
        guard let base = URL(string: endpoint), base.scheme == "https", base.host != nil, base.user == nil, base.password == nil,
              ["health","status","rates","geocode","reverse","nearby","weather","safety","crime","rail","search","fx"].contains(path) else { throw TripError.invalid("Choose a valid HTTPS Eurotrip backend.") }
        var components = URLComponents(url: base.appendingPathComponent("api").appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        var request = URLRequest(url: components.url!); request.timeoutInterval = 45; request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if !accessCode.isEmpty { request.setValue(accessCode, forHTTPHeaderField: "X-Access-Token") }
        if let body { request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.httpBody = try JSONEncoder().encode(body) }
        let session = URLSession(configuration: configuration, delegate: TravelRedirects(), delegateQueue: nil); defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, data.count <= 5_000_000 else { throw TripError.invalid("Invalid or oversized server response.") }
        let result = try JSONDecoder().decode(JSONValue.self, from: data)
        guard response.statusCode == 200 else {
            if response.statusCode == 401 { throw TripError.invalid("Access code needed. Save your existing Eurotrip server access code in More → Connection.") }
            if response.statusCode == 429 { throw TripError.invalid("Request limit reached. Wait before refreshing.") }
            throw TripError.invalid(result.object.text("error").isEmpty ? "The live provider is unavailable. Your saved trip remains available offline." : result.object.text("error"))
        }
        return result
    }
    static func current() -> TravelClient {
        let endpoint = UserDefaults.standard.string(forKey: "eurotrip.endpoint") ?? "https://eurotrip-planner.onrender.com"
        return TravelClient(endpoint: endpoint, accessCode: TravelKeychain.read("access:" + endpoint))
    }
}
