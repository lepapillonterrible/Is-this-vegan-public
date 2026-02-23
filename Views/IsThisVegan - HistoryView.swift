// HistoryView.swift
// IsThisVegan
//
// Displays a list of all past scan results, with a modern card-based layout.
// Includes summary statistics and search functionality.

import SwiftUI
import SwiftData

struct HistoryView: View {

    // MARK: - Dependencies

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var viewModel: ScannerViewModel

    // MARK: - Data

    @Query(sort: \ScanResult.timestamp, order: .reverse)
    private var scanResults: [ScanResult]

    @State private var searchText = ""

    // MARK: - Computed

    private var filteredResults: [ScanResult] {
        if searchText.isEmpty {
            return scanResults
        }
        return scanResults.filter { result in
            result.productName.localizedCaseInsensitiveContains(searchText) ||
            result.explanation.localizedCaseInsensitiveContains(searchText) ||
            result.flaggedIngredients.contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private var veganCount: Int { scanResults.filter { $0.verdict == .vegan }.count }
    private var notVeganCount: Int { scanResults.filter { $0.verdict == .notVegan }.count }
    private var uncertainCount: Int { scanResults.filter { $0.verdict == .uncertain }.count }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    
                    // MARK: Header & Stats
                    VStack(spacing: 16) {
                        HStack {
                            Text("History")
                                .font(.system(size: 34, weight: .bold))
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        
                        // Summary Cards
                        HStack(spacing: 12) {
                            SummaryCard(title: "Vegan", count: veganCount, color: .green)
                            SummaryCard(title: "Not Vegan", count: notVeganCount, color: .red)
                            SummaryCard(title: "Uncertain", count: uncertainCount, color: .orange)
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 20)
                    .background(Color(.systemGroupedBackground)) // Ensure it covers content when scrolling if we wanted sticky, but here just spacing
                    
                    // MARK: Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search history...", text: $searchText)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                    // MARK: Content
                    if scanResults.isEmpty {
                        emptyStateView
                            .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(filteredResults) { result in
                                    NavigationLink {
                                        ResultView(result: result, showScanAgainButton: false)
                                            .environmentObject(viewModel)
                                    } label: {
                                        HistoryCard(result: result)
                                    }
                                    .buttonStyle(.plain) // Remove default list button styling
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)
            
            Text("No Scans Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            Text("Your scan history will appear here.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Helper Components

struct SummaryCard: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(count)")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(color)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct HistoryCard: View {
    let result: ScanResult
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(result.verdict.color.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Text(result.verdict.emoji)
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(result.productName)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text(result.timestamp, format: .dateTime.month(.abbreviated).day())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Text(result.verdict == .vegan ? "Safe to eat" : (result.verdict == .notVegan ? "Avoid this" : "Check details"))
                    .font(.subheadline)
                    .foregroundStyle(result.verdict.color)
                    .fontWeight(.medium)
                
                if !result.explanation.isEmpty {
                    Text(result.explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}



#Preview {
    HistoryView()
        .environmentObject(ScannerViewModel())
        .modelContainer(for: ScanResult.self, inMemory: true)
}
