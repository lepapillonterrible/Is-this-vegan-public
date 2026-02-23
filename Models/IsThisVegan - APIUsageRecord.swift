// APIUsageRecord.swift
// IsThisVegan
//
// A single API usage record, stored in SwiftData.
// Tracks tokens and cost for cost-control logic.

import Foundation
import SwiftData

@Model
final class APIUsageRecord {
    var id: UUID
    var timestamp: Date
    var model: String
    var promptTokens: Int
    var completionTokens: Int
    var totalTokens: Int
    var estimatedCostUSD: Double
    var wasOfflineResolved: Bool
    var inputType: String

    init(
        timestamp: Date = Date(),
        model: String,
        promptTokens: Int,
        completionTokens: Int,
        estimatedCostUSD: Double = 0,
        wasOfflineResolved: Bool = false,
        inputType: String = "unknown"
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.model = model
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = promptTokens + completionTokens
        self.estimatedCostUSD = estimatedCostUSD
        self.wasOfflineResolved = wasOfflineResolved
        self.inputType = inputType
    }
}
