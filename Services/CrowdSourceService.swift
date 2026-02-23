// CrowdSourceService.swift
// IsThisVegan
//
// Manages the community-driven database of dish reports using CloudKit.
// Allows users to submit reports (e.g. "Pad Thai here isn't vegan") and 
// fetches community wisdom for the current location.
//
// Uses the Public Database so all users share the same data.

import Foundation
import CloudKit
import CoreLocation

// MARK: - Models

/// A report submitted by the community about a specific dish/product.
struct CommunityDish: Identifiable {
    let id: CKRecord.ID
    let name: String
    let verdict: String // "vegan", "not_vegan", "risky"
    let reason: String
    let location: CLLocation
    let upvotes: Int
    let reportDate: Date
    
    /// Create a local model from a CloudKit record.
    init?(record: CKRecord) {
        guard let name = record["name"] as? String,
              let verdict = record["verdict"] as? String,
              let location = record["location"] as? CLLocation else {
            return nil
        }
        
        self.id = record.recordID
        self.name = name
        self.verdict = verdict
        self.reason = record["reason"] as? String ?? ""
        self.location = location
        self.upvotes = record["upvotes"] as? Int ?? 0
        self.reportDate = record.creationDate ?? Date()
    }
}

// MARK: - Service

/// Thread-safety: Uses internal serial queue for CloudKit operations if needed, 
/// but CloudKit callbacks are async. We use Swift concurrency.
final class CrowdSourceService: @unchecked Sendable {
    
    // MARK: - Dependencies
    
    private let container = CKContainer.default()
    private lazy var database = container.publicCloudDatabase
    
    // MARK: - Public API
    
    /// Submit a new report to the community database.
    func submitReport(
        dishName: String,
        verdict: String,
        reason: String,
        location: CLLocation
    ) async throws {
        let record = CKRecord(recordType: "CommunityDish")
        record["name"] = dishName
        record["verdict"] = verdict
        record["reason"] = reason
        record["location"] = location
        record["upvotes"] = 0
        
        try await database.save(record)
    }
    
    /// Fetch reports near a specific location (e.g. 500m radius).
    func fetchReports(near location: CLLocation, radiusInMeters: Double = 500) async throws -> [CommunityDish] {
        // Spatial query: correct usage for CloudKit
        // Note: 'distanceToLocation:fromLocation:' is the NSPredicate format for CLLocation
        let predicate = NSPredicate(format: "distanceToLocation:fromLocation:(location, %@) < %f", location, radiusInMeters)
        
        let query = CKQuery(recordType: "CommunityDish", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let (matchResults, _) = try await database.records(matching: query)
        
        // Unpack results
        let dishes: [CommunityDish] = matchResults.compactMap { _, result in
            switch result {
            case .success(let record):
                return CommunityDish(record: record)
            case .failure(let error):
                print("[CrowdSourceService] Failed to decode record: \(error)")
                return nil
            }
        }
        
        return dishes
    }
    
    /// Upvote a helpful report.
    func upvote(dish: CommunityDish) async throws {
        let recordID = dish.id
        
        // Fetch fresh record to avoid conflicts
        let record = try await database.record(for: recordID)
        
        // Increment
        let currentVotes = record["upvotes"] as? Int ?? 0
        record["upvotes"] = currentVotes + 1
        
        // Save
        try await database.save(record)
    }
}
