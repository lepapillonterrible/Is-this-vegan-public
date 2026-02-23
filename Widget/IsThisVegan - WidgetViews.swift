// WidgetViews.swift
// IsThisVeganWidget
//
// UI views for both widgets:
// 1. QuickScanWidgetView - Big green "Scan" button
// 2. LastScanWidgetView - Shows last scan verdict with details
//
// These views are designed to look great at all supported widget sizes.

import SwiftUI
import WidgetKit
import AppIntents

// MARK: - ═══════════════════════════════════════════
// MARK:   1. QUICK SCAN WIDGET VIEW
// MARK: - ═══════════════════════════════════════════

/// The UI for the Quick Scan widget.
/// Shows a big leaf icon and "Scan" label. Tapping opens the app to scan.
struct QuickScanWidgetView: View {
    var entry: QuickScanEntry
    
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        ZStack {
            // New "Mint" card background
            Color("SplashBackground") // We should probably use a system color if this isn't available in widget bundle
            // Fallback to system background or a nice gradient
            LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.72, blue: 0.34), // Brand Green
                    Color(red: 0.18, green: 0.60, blue: 0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            switch widgetFamily {
            case .systemSmall:
                smallView
            case .systemMedium:
                if #available(iOSApplicationExtension 17.0, *) {
                    mediumView
                } else {
                    smallView // fallback on iOS 16
                }
            default:
                smallView
            }
        }
        .widgetURL(URL(string: "isthisvegan://scan"))
    }
    
    // MARK: Small Widget
    
    private var smallView: some View {
        VStack(spacing: 8) {
            Image("BrockReady") // Ensure this asset is added to the Widget target!
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
            
            Text("Scan")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
    }
    
    // MARK: Medium Widget — interactive buttons (iOS 17+)

    @available(iOSApplicationExtension 17.0, *)
    private var mediumView: some View {
        HStack(spacing: 0) {
            // Left: Brock mascot
            Image("BrockReady")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .padding(.leading, 16)

            Spacer()

            // Right: title + two buttons
            VStack(alignment: .leading, spacing: 8) {
                Text("Is This Vegan?")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                // Camera button
                Button(intent: ScanWithCameraIntent()) {
                    Label("Camera", systemImage: "camera.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.25))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Library button
                Button(intent: ScanFromLibraryIntent()) {
                    Label("Library", systemImage: "photo.on.rectangle")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.15))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - ═══════════════════════════════════════════
// MARK:   2. LAST SCAN WIDGET VIEW
// MARK: - ═══════════════════════════════════════════

/// The UI for the Last Scan widget.
/// Shows the most recent scan result with verdict, product name, and details.
/// The UI for the Last Scan widget.
/// Shows the most recent scan result with verdict, product name, and details.
struct LastScanWidgetView: View {
    var entry: LastScanEntry
    
    @Environment(\.widgetFamily) var widgetFamily
    
    var body: some View {
        if entry.hasData {
            // Has scan data - show the result
            contentView
        } else {
            // No data yet - show empty state
            emptyStateView
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var contentView: some View {
        ZStack {
            // Background based on verdict color (faint)
            (entry.verdict?.color ?? .gray).opacity(0.1)
            
            switch widgetFamily {
            case .systemSmall:
                smallResultView
            case .systemMedium:
                mediumResultView
            case .systemLarge:
                largeResultView
            default:
                smallResultView
            }
        }
        .widgetURL(URL(string: "isthisvegan://scan"))
    }
    
    // MARK: - Assets Helper
    
    private var mascotImageName: String {
        switch entry.verdict {
        case .vegan: return "BrockVegan"
        case .notVegan: return "BrockNotVegan"
        case .uncertain, .error, .none: return "BrockUncertain"
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image("BrockReady")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
            
            Text("No Scans Yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Tap to scan your first item")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "isthisvegan://scan"))
    }
    
    // MARK: - Small Widget
    
    private var smallResultView: some View {
        VStack(spacing: 6) {
            // Mascot
            Image(mascotImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
            
            // Verdict label
            Text(entry.verdict?.shortTitle ?? "Unknown")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(entry.verdict?.color ?? .primary)
            
            // Product name
            Text(entry.productName ?? "")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(4)
    }
    
    // MARK: - Medium Widget
    
    private var mediumResultView: some View {
        HStack(spacing: 0) {
            // Left: Mascot
            ZStack {
                (entry.verdict?.color ?? .gray).opacity(0.2)
                
                Image(mascotImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            }
            .frame(width: 110)
            
            // Right: Product details
            VStack(alignment: .leading, spacing: 4) {
                // Verdict Badge
                Text(entry.verdict?.shortTitle.uppercased() ?? "UNKNOWN")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((entry.verdict?.color ?? .gray).opacity(0.2))
                    .foregroundStyle(entry.verdict?.color ?? .gray)
                    .clipShape(Capsule())
                
                Text(entry.productName ?? "Unknown Product")
                    .font(.headline)
                    .lineLimit(2)
                
                Text(entry.explanation ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                if let scanDate = entry.scanDate {
                    Spacer()
                    Text(scanDate, format: .relative(presentation: .named))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Large Widget
    
    private var largeResultView: some View {
        VStack(spacing: 0) {
            // Header with Mascot
            HStack(spacing: 16) {
                 Image(mascotImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 70, height: 70)
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.verdict?.title ?? "Unknown")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(entry.verdict?.color ?? .primary)
                    
                    Text(entry.productName ?? "Unknown Product")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background((entry.verdict?.color ?? .gray).opacity(0.1))
            
            // Content
            VStack(alignment: .leading, spacing: 12) {
                
                // Explanation
                Text(entry.explanation ?? "")
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(4)
                
                // Flagged ingredients
                if !entry.flaggedIngredients.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Flagged Ingredients")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                        
                        FlowLayout(spacing: 6) {
                            ForEach(entry.flaggedIngredients.prefix(6), id: \.self) { ingredient in
                                Text(ingredient)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.red.opacity(0.1))
                                    .foregroundStyle(.red)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Bottom
                HStack {
                    if let scanDate = entry.scanDate {
                        Text(scanDate, format: .relative(presentation: .named))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Text("Top to open")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }
}

// MARK: - Flow Layout (for ingredient chips in large widget)

/// A simple horizontal flow layout that wraps items to the next line
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }
    
    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }
        
        return (positions, CGSize(width: maxX, height: currentY + lineHeight))
    }
}

// MARK: - Previews

#Preview("Quick Scan - Small", as: .systemSmall) {
    IsThisVeganQuickScanWidget()
} timeline: {
    QuickScanEntry(date: Date())
}

#Preview("Last Scan - Medium (Vegan)", as: .systemMedium) {
    IsThisVeganLastScanWidget()
} timeline: {
    LastScanEntry(
        date: Date(),
        productName: "Oat Milk Latte",
        verdict: .vegan,
        explanation: "All ingredients are plant-based including oat milk, water, and natural flavors.",
        flaggedIngredients: [],
        scanDate: Date().addingTimeInterval(-3600)
    )
}

#Preview("Last Scan - Large (Not Vegan)", as: .systemLarge) {
    IsThisVeganLastScanWidget()
} timeline: {
    LastScanEntry(
        date: Date(),
        productName: "Chocolate Chip Cookie",
        verdict: .notVegan,
        explanation: "This product contains butter (dairy), eggs, and whey protein — all animal-derived ingredients.",
        flaggedIngredients: ["Butter", "Eggs", "Whey Protein", "Milk Chocolate"],
        scanDate: Date().addingTimeInterval(-7200)
    )
}
