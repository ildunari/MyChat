// Services/ModelCapabilities.swift
import Foundation

// Lightweight, codable model capability snapshot used for UI defaults and validation
struct ProviderModelInfo: Codable, Equatable {
    let id: String
    var displayName: String?
    var inputTokenLimit: Int?
    var outputTokenLimit: Int?
    var maxTemperature: Double?
    var supportsPromptCaching: Bool?

    // Preferred request-time defaults (user overrides live here; provider defaults may populate some)
    var preferredTemperature: Double?
    var preferredTopP: Double?
    var preferredTopK: Int?
    var preferredMaxOutputTokens: Int?
    var preferredReasoningEffort: String?   // e.g., minimal|low|medium|high
    var preferredVerbosity: String?         // e.g., low|medium|high
    var disableSafetyFilters: Bool?         // Google safety off
    var preferredPresencePenalty: Double?
    var preferredFrequencyPenalty: Double?
    var stopSequences: [String]?
    // Anthropic-specific
    var anthropicThinkingEnabled: Bool?
    var anthropicThinkingBudget: Int?
    var enablePromptCaching: Bool?

    // Convenience defaults
    static func fallback(id: String) -> ProviderModelInfo {
        ProviderModelInfo(id: id,
                          displayName: nil,
                          inputTokenLimit: nil,
                          outputTokenLimit: nil,
                          maxTemperature: 2.0,
                          supportsPromptCaching: false,
                          preferredTemperature: nil,
                          preferredTopP: nil,
                          preferredTopK: nil,
                          preferredMaxOutputTokens: nil,
                          preferredReasoningEffort: nil,
                          preferredVerbosity: nil,
                          disableSafetyFilters: nil,
                          preferredPresencePenalty: nil,
                          preferredFrequencyPenalty: nil,
                          stopSequences: nil,
                          anthropicThinkingEnabled: nil,
                          anthropicThinkingBudget: nil,
                          enablePromptCaching: nil)
    }
}

// Entry that keeps both remote‑derived defaults and user overrides.
private struct ModelCapsEntry: Codable, Equatable {
    var `default`: ProviderModelInfo
    var user: ProviderModelInfo?
}

// Persistent cache in UserDefaults keyed by provider → model, storing defaults+overrides.
enum ModelCapabilitiesStore {
    private static let keyV2 = "ModelCaps.v2"
    private static let keyV1 = "ModelCaps.v1" // migration from older single-layer store

    // v2 payload
    private static func loadAllV2() -> [String: [String: ModelCapsEntry]]? {
        guard let data = UserDefaults.standard.data(forKey: keyV2) else { return nil }
        return try? JSONDecoder().decode([String: [String: ModelCapsEntry]].self, from: data)
    }

    private static func saveAllV2(_ map: [String: [String: ModelCapsEntry]]) {
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: keyV2)
        }
    }

    // Migration from v1 → v2 (defaults only)
    private static func migrateIfNeeded() -> [String: [String: ModelCapsEntry]] {
        if let v2 = loadAllV2() { return v2 }
        guard let data = UserDefaults.standard.data(forKey: keyV1),
              let old = try? JSONDecoder().decode([String: [String: ProviderModelInfo]].self, from: data) else {
            return [:]
        }
        var map: [String: [String: ModelCapsEntry]] = [:]
        for (provider, items) in old {
            var per: [String: ModelCapsEntry] = [:]
            for (model, info) in items { per[model] = ModelCapsEntry(default: info, user: nil) }
            map[provider] = per
        }
        saveAllV2(map)
        return map
    }

    // Public API
    static func get(provider: String, model: String) -> ProviderModelInfo? {
        let all = migrateIfNeeded()
        guard let entry = all[provider]?[model] else { return nil }
        return entry.user ?? entry.default
    }

    static func getPair(provider: String, model: String) -> (defaults: ProviderModelInfo?, user: ProviderModelInfo?) {
        let all = migrateIfNeeded()
        guard let entry = all[provider]?[model] else { return (nil, nil) }
        return (entry.default, entry.user)
    }

    static func putDefault(provider: String, infos: [ProviderModelInfo]) {
        var all = migrateIfNeeded()
        var per = all[provider] ?? [:]
        for info in infos {
            if let existing = per[info.id] {
                per[info.id] = ModelCapsEntry(default: info, user: existing.user) // keep user override
            } else {
                per[info.id] = ModelCapsEntry(default: info, user: nil)
            }
        }
        all[provider] = per
        saveAllV2(all)
    }

    static func putUser(provider: String, model: String, info: ProviderModelInfo?) {
        var all = migrateIfNeeded()
        var per = all[provider] ?? [:]
        if var entry = per[model] {
            entry.user = info
            per[model] = entry
        } else {
            // no defaults yet; store user override independently
            per[model] = ModelCapsEntry(default: ProviderModelInfo.fallback(id: model), user: info)
        }
        all[provider] = per
        saveAllV2(all)
    }

    static func clearUser(provider: String, model: String) {
        var all = migrateIfNeeded()
        guard var entry = all[provider]?[model] else { return }
        entry.user = nil
        all[provider]?[model] = entry
        saveAllV2(all)
    }
}
