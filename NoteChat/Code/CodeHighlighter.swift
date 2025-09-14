// Code/CodeHighlighter.swift
import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

#if canImport(UIKit)
import UIKit
#endif

#if canImport(Highlightr)
import Highlightr
#endif

#if canImport(Highlighter)
import Highlighter
#endif

#if canImport(HighlighterSwift)
import HighlighterSwift
#endif

// Actor that provides lazy, cached code highlighting
actor CodeHighlighter {
    static let shared = CodeHighlighter()

    private let cache = NSCache<NSString, NSAttributedString>()
    #if canImport(Highlightr)
    private var highlightrByTheme: [String: Highlightr] = [:]
    #endif

    init() {
        cache.countLimit = 128
        cache.totalCostLimit = 8 * 1024 * 1024 // ~8MB
    }

    func highlight(_ code: String, lang: String?, theme: String) async -> NSAttributedString {
        let key = NSString(string: theme + "|" + (lang ?? "") + "|" + hashString(code))
        if let v = cache.object(forKey: key) { return v }

        // Try Highlightr → Highlighter → HighlighterSwift in that order; then fallback
        #if canImport(Highlightr)
        if let hl = highlightrByTheme[theme] ?? Highlightr() {
            _ = hl.setTheme(to: theme)
            highlightrByTheme[theme] = hl
            if let out = hl.highlight(code, as: lang) {
                cache.setObject(out, forKey: key, cost: out.length)
                return out
            }
        }
        #endif

        #if canImport(Highlighter)
        if let hl = Highlighter() {
            if let out = hl.highlight(code, as: lang ?? "") {
                cache.setObject(out, forKey: key, cost: out.length)
                return out
            }
        }
        #endif

        #if canImport(HighlighterSwift)
        if let hl = HighlighterSwift() {
            if let out = hl.highlight(code: code, as: lang ?? "") {
                cache.setObject(out, forKey: key, cost: out.length)
                return out
            }
        }
        #endif

        // Fallback plain monospaced attributed string
        #if canImport(UIKit)
        let font = UIFont.monospacedSystemFont(ofSize: UIFont.systemFontSize, weight: .regular)
        let out = NSAttributedString(string: code, attributes: [.font: font])
        #else
        let out = NSAttributedString(string: code)
        #endif
        cache.setObject(out, forKey: key, cost: out.length)
        return out
    }

    private func hashString(_ s: String) -> String {
        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: Data(s.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
        #else
        return String(s.hashValue)
        #endif
    }
}
