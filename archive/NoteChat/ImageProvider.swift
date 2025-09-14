// Providers/ImageProvider.swift
import Foundation

protocol ImageProvider {
    var id: String { get }
    var displayName: String { get }
    func listModels() async throws -> [String]
    func generateImage(prompt: String, model: String) async throws -> Data
}
