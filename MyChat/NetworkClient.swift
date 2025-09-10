// Networking/NetworkClient.swift
import Foundation
import Combine // TODO: Temporary import to unblock build; remove after Observation-based Settings migration finalizes if unused.

struct NetworkClient {
    let session: URLSession

    static let shared = NetworkClient(session: {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        return URLSession(configuration: config)
    }())

    func postJSON<T: Encodable>(url: URL, body: T, headers: [String: String]) async throws -> (Data, HTTPURLResponse) {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (k, v) in headers {
            req.setValue(v, forHTTPHeaderField: k)
        }
        req.httpBody = try JSONEncoder().encode(body)
        #if DEBUG
        Log.netReq("POST \(url.absoluteString)")
        #endif
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        #if DEBUG
        if !(200..<300).contains(http.statusCode) {
            let snippet = String(data: data.prefix(600), encoding: .utf8) ?? "<non-utf8>"
            Log.netErr("HTTP \(http.statusCode) for \(url.lastPathComponent): \(snippet)")
        }
        #endif
        return (data, http)
    }

    func get(url: URL, headers: [String: String] = [:]) async throws -> (Data, HTTPURLResponse) {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        for (k, v) in headers {
            req.setValue(v, forHTTPHeaderField: k)
        }
        #if DEBUG
        Log.netReq("GET \(url.absoluteString)")
        #endif
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        #if DEBUG
        if !(200..<300).contains(http.statusCode) {
            let snippet = String(data: data.prefix(600), encoding: .utf8) ?? "<non-utf8>"
            Log.netErr("HTTP \(http.statusCode) for \(url.lastPathComponent): \(snippet)")
        }
        #endif
        return (data, http)
    }
}
