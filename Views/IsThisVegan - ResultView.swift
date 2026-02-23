// ResultView.swift
// IsThisVegan
//
// Displays the analysis result for a scanned product or menu item.
// Redesigned with a modern, card-based UI.

import SwiftUI

struct ResultView: View {

    // MARK: - Dependencies

    let result: ScanResult
    @EnvironmentObject private var viewModel: ScannerViewModel
    @Environment(\.dismiss) private var dismiss
    
    /// Determine which mascot to show based on the verdict
    private var mascotImageName: String {
        if result.verdict == .vegan {
            return "BrockVegan"
        } else if !result.flaggedIngredients.isEmpty {
            return "BrockNotVegan"
        } else {
            return "BrockUncertain"
        }
    }

    /// Control "Scan Again" visibility (hidden when viewing history)
    var showScanAgainButton: Bool = true

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        
                        // MARK: - Mascot & Verdict
                        VStack(spacing: -10) { // Overlap slightly to connect mascot with card
                            
                            // 1. Mascot Image
                            Image(mascotImageName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 180)
                                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                                .zIndex(1) // Sit on top of the card
                                .background(Color.clear) // Ensure no background blocks it
                            
                            // 2. Verdict Card
                            VerdictHeroCard(result: result)
                        }
                        .padding(.top, 20)           
                        // MARK: Flagged Ingredients
                        if !result.flaggedIngredients.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Watch Out", systemImage: "exclamationmark.triangle.fill")
                                    .font(.headline)
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 4)
                                
                                FlowLayout(spacing: 8) {
                                    ForEach(result.flaggedIngredients, id: \.self) { ingredient in
                                        Text(ingredient)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Color.orange.opacity(0.1))
                                            .foregroundStyle(.orange)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(16)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                        }
                        
                        // MARK: Explanation Card
                        if !result.explanation.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Analysis", systemImage: "doc.text.magnifyingglass")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 4)
                                
                                Text(result.explanation)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(16)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                        }
                        
                        // MARK: Community Contribution
                        if showScanAgainButton {
                            CommunityContributionView(result: result)
                        }
                        
                        Spacer(minLength: 120) // Space for floating buttons
                    }
                    .padding(20)
                }
                
                // MARK: Floating Action Bar
                VStack {
                    Spacer()
                    
                    HStack(spacing: 16) {
                        // Share Button
                        ShareLink(
                            item: shareText,
                            subject: Text("Is This Vegan?"),
                            message: Text(shareText)
                        ) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.secondarySystemGroupedBackground))
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                        }
                        
                        // Scan Again Button
                        if showScanAgainButton {
                            Button {
                                viewModel.scanAgain()
                                dismiss()
                            } label: {
                                Label("Scan Again", systemImage: "camera.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.black)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Helpers

    private var shareText: String {
        var text = "\(result.verdict.emoji) \(result.productName) — \(result.verdict.label)"
        if !result.flaggedIngredients.isEmpty {
            text += "\n⚠️ Flagged: \(result.flaggedIngredients.joined(separator: ", "))"
        }
        text += "\n\nScanned with Is This Vegan?"
        return text
    }
}

// MARK: - Subcomponents

struct VerdictHeroCard: View {
    let result: ScanResult
    
    var body: some View {
        VStack(spacing: 16) {
            // Emoji & Title container
            if result.verdict != .uncertain {
                VStack(spacing: 8) {
                    Text(result.verdict.emoji)
                        .font(.system(size: 64))
                    
                    Text(result.verdict.label)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(result.verdict.color)
                }
            }
            
            if !result.productName.isEmpty {
                Text(result.productName)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            }
            
            // Timestamp
            Text(result.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: result.verdict.color.opacity(0.15), radius: 15, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(result.verdict.color.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Community Contribution
struct CommunityContributionView: View {
    let result: ScanResult
    @EnvironmentObject private var viewModel: ScannerViewModel
    
    @State private var hasVoted = false
    @State private var showCorrectionSheet = false
    @State private var correctionReason = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Community Verification", systemImage: "person.2.wave.2.fill")
                .font(.headline)
                .foregroundStyle(.blue)
                .padding(.horizontal, 4)
            
            if hasVoted {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Thank you for contributing!")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 12) {
                    
                    if result.verdict == .uncertain {
                        // Uncertain Case: Ask for specific verdict
                        Text("Help the community decide:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack(spacing: 12) {
                            Button {
                                submitVote(verdict: "vegan", reason: "User voted vegan")
                            } label: {
                                Text("Actually, it's Vegan")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.green.opacity(0.1))
                                    .foregroundStyle(.green)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            
                            Button {
                                submitVote(verdict: "not_vegan", reason: "User voted not vegan")
                            } label: {
                                Text("It's Not Vegan")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.red.opacity(0.1))
                                    .foregroundStyle(.red)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    } else {
                        // Decisive Case: Confirm or Deny
                        Text("Is this result accurate?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack(spacing: 12) {
                            Button {
                                submitVote(verdict: result.verdict.rawValue, reason: "Confirmed by user")
                            } label: {
                                Text("Correct")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundStyle(.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            
                            Button {
                                showCorrectionSheet = true
                            } label: {
                                Text("Incorrect")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.orange.opacity(0.1))
                                    .foregroundStyle(.orange)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
            }
        }
        .sheet(isPresented: $showCorrectionSheet) {
            NavigationStack {
                Form {
                    Section("What's wrong?") {
                        TextField("e.g., 'Contains hidden fish sauce'", text: $correctionReason)
                    }
                    
                    Section {
                        Button("Mark as Not Vegan") {
                            submitVote(verdict: "not_vegan", reason: correctionReason)
                            showCorrectionSheet = false
                        }
                        .foregroundStyle(.red)
                        
                        Button("Mark as Vegan") {
                            submitVote(verdict: "vegan", reason: correctionReason)
                            showCorrectionSheet = false
                        }
                        .foregroundStyle(.green)
                    }
                }
                .navigationTitle("Correct Analysis")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showCorrectionSheet = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    private func submitVote(verdict: String, reason: String) {
        viewModel.submitCommunityReport(for: result, verdict: verdict, reason: reason)
        withAnimation {
            hasVoted = true
        }
    }
}

// MARK: - Flow Layout (Reused)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return (
            CGSize(width: maxWidth, height: currentY + lineHeight),
            positions
        )
    }
}

#Preview {
    ResultView(result: .sampleNotVegan)
        .environmentObject(ScannerViewModel())
}
