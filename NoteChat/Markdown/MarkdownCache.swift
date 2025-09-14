// Markdown/MarkdownCache.swift
import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

// Thread-safe LRU cache for AttributedString results
actor MarkdownCacheActor {
    private var dict: [String: AttributedString] = [:]
    private var order: [String] = []
    private let maxEntries: Int

    init(maxEntries: Int = 64) { self.maxEntries = maxEntries }

    func get(_ key: String) -> AttributedString? { dict[key] }

    func put(_ key: String, _ value: AttributedString) {
        if dict[key] == nil { order.append(key) }
        dict[key] = value
        if order.count > maxEntries, let drop = order.first {
            dict.removeValue(forKey: drop)
            order.removeFirst()
        }
    }
}

// Helpers
enum MarkdownKey {
    static func make(_ text: String, mode: String, tintLinks: Bool) -> String {
        let tag = tintLinks ? "link" : "nolink"
        return sha256(mode + "|" + tag + "|" + text)
    }

    static func sha256(_ s: String) -> String { sha256(Data(s.utf8)) }

    static func sha256(_ data: Data) -> String {
        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
        #else
        return String(data.hashValue)
        #endif
    }
}
