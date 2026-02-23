// UsageTracker.swift
// IsThisVegan
//
// Tracks API usage and enforces daily/monthly limits.
// Uses SwiftData to persist usage records so they survive app restarts.
//
// This is the cost-control layer — prevents runaway API charges by:
// - Counting calls per day and per month
// - Tracking token usage and estimated costs
// - Providing usage statistics for the Settings screen

import Foundation
import SwiftData
import os


// MARK: - Usage Stats

/// Snapshot of usage statistics for display in the UI.
struct UsageStats {
    let todayAPICalls: Int
    let monthAPICalls: Int
    let monthTokens: Int
    let monthCostUSD: Double
    let offlineScansThisMonth: Int

    static let empty = UsageStats(
        todayAPICalls: 0, monthAPICalls: 0,
        monthTokens: 0, monthCostUSD: 0,
        offlineScansThisMonth: 0
    )
}

// MARK: - Usage Tracker

@MainActor
final class UsageTracker {
    static let shared = UsageTracker()
    var modelContext: ModelContext?

    /// Structured logger for usage tracking events.
    private let logger = Logger(subsystem: "com.IsThisVegan", category: "UsageTracker")

    /// Whether the tracker has been configured with a ModelContext.
    /// Views can check this before attempting to display usage data.
    var isConfigured: Bool { modelContext != nil }

    // MARK: - Limit Checks

    /// Check if the user has exceeded any usage limits.
    /// Returns a human-readable message if a limit is hit, or nil if all clear.
    func checkLimits() -> String? {
        guard let context = modelContext else { return nil }

        let now = Date()

        // Daily limit check
        if Config.dailyAPICallLimit > 0 {
            let startOfDay = Calendar.current.startOfDay(for: now)
            let dailyCount = countRecords(in: context, since: startOfDay, onlyAPICalls: true)
            if dailyCount >= Config.dailyAPICallLimit {
                return "Daily limit reached (\(Config.dailyAPICallLimit) scans). Resets at midnight."
            }
        }

        // Monthly limit check
        if Config.monthlyAPICallLimit > 0,
           let startOfMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: now)) {
            let monthlyCount = countRecords(in: context, since: startOfMonth, onlyAPICalls: true)
            if monthlyCount >= Config.monthlyAPICallLimit {
                return "Monthly limit reached (\(Config.monthlyAPICallLimit) scans). Resets next month."
            }
        }

        return nil // All clear
    }

    // MARK: - Statistics

    /// Get usage statistics for display in the app.
    func getStats() -> UsageStats {
        guard let context = modelContext else {
            return UsageStats.empty
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        guard let startOfMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: now)) else {
            return UsageStats.empty
        }

        let todayCount = countRecords(in: context, since: startOfDay, onlyAPICalls: true)
        let monthCount = countRecords(in: context, since: startOfMonth, onlyAPICalls: true)
        let monthTokens = totalTokens(in: context, since: startOfMonth)
        let monthCost = totalCost(in: context, since: startOfMonth)
        let offlineCount = countRecords(in: context, since: startOfMonth, onlyOffline: true)

        return UsageStats(
            todayAPICalls: todayCount,
            monthAPICalls: monthCount,
            monthTokens: monthTokens,
            monthCostUSD: monthCost,
            offlineScansThisMonth: offlineCount
        )
    }

    // MARK: - Recording

    /// Record a usage event (API call or offline resolution).
    func recordUsage(
        model: String,
        promptTokens: Int,
        completionTokens: Int,
        estimatedCostUSD: Double = 0,
        wasOfflineResolved: Bool = false,
        inputType: String = "unknown"
    ) {
        guard let context = modelContext else {
            logger.warning("modelContext not set, skipping usage recording")
            return
        }

        let record = APIUsageRecord(
            model: model,
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            estimatedCostUSD: estimatedCostUSD,
            wasOfflineResolved: wasOfflineResolved,
            inputType: inputType
        )

        context.insert(record)

        do {
            try context.save()
        } catch {
            logger.error("Failed to save usage record: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    /// Count records matching criteria since a given date.
    private func countRecords(
        in context: ModelContext,
        since date: Date,
        onlyAPICalls: Bool = false,
        onlyOffline: Bool = false
    ) -> Int {
        var descriptor = FetchDescriptor<APIUsageRecord>(
            predicate: #Predicate { record in
                record.timestamp >= date
            }
        )
        descriptor.fetchLimit = nil

        do {
            let records = try context.fetch(descriptor)
            if onlyAPICalls {
                return records.filter { !$0.wasOfflineResolved }.count
            }
            if onlyOffline {
                return records.filter { $0.wasOfflineResolved }.count
            }
            return records.count
        } catch {
            logger.error("Failed to count records: \(error.localizedDescription)")
            return 0
        }
    }

    /// Total tokens used since a given date.
    private func totalTokens(in context: ModelContext, since date: Date) -> Int {
        var descriptor = FetchDescriptor<APIUsageRecord>(
            predicate: #Predicate { record in
                record.timestamp >= date
            }
        )
        descriptor.fetchLimit = nil

        do {
            let records = try context.fetch(descriptor)
            return records.reduce(0) { $0 + $1.promptTokens + $1.completionTokens }
        } catch {
            return 0
        }
    }

    /// Total estimated cost since a given date.
    private func totalCost(in context: ModelContext, since date: Date) -> Double {
        var descriptor = FetchDescriptor<APIUsageRecord>(
            predicate: #Predicate { record in
                record.timestamp >= date
            }
        )
        descriptor.fetchLimit = nil

        do {
            let records = try context.fetch(descriptor)
            return records.reduce(0) { $0 + $1.estimatedCostUSD }
        } catch {
            return 0
        }
    }
}
