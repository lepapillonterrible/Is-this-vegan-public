// ConsentView.swift
// IsThisVegan
//
// Shown once on first launch to explain that photos are sent to
// Google Gemini API for analysis. Consent is stored in UserDefaults;
// the view never appears again once accepted.

import SwiftUI

struct ConsentView: View {

    /// Called when the user taps "I Agree" — parent dismisses this view.
    let onAccept: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {

                    // MARK: - Header
                    VStack(spacing: 16) {
                        Image(systemName: "leaf.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(.green)
                            .padding(.top, 56)

                        Text("Welcome to\nIs This Vegan?")
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)

                        Text("Before you start scanning, please read how your photos are used.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.bottom, 36)

                    // MARK: - How it works cards
                    VStack(spacing: 12) {
                        ConsentRow(
                            icon: "iphone",
                            color: .green,
                            title: "On-Device First",
                            description: "Text is extracted from your photo using Apple Vision, entirely on your device."
                        )
                        ConsentRow(
                            icon: "arrow.up.circle",
                            color: .orange,
                            title: "Photo Sent to Google",
                            description: "When the on-device check is inconclusive, your photo (or the extracted text) is sent to Google Gemini API for ingredient analysis over an encrypted HTTPS connection."
                        )
                        ConsentRow(
                            icon: "trash",
                            color: .blue,
                            title: "Not Stored by Google",
                            description: "Google does not retain submitted data or use it to train their models. See Google's AI Terms of Service for details."
                        )
                        ConsentRow(
                            icon: "lock.shield",
                            color: .purple,
                            title: "Your History Stays Private",
                            description: "Your scan history is saved locally on your device only. No account required. We never see your data."
                        )
                    }
                    .padding(.horizontal, 20)

                    // MARK: - Privacy Policy link
                    Link(destination: URL(string: "https://papillonmakes.tech/isthisvegan#privacy-policy")!) {
                        Label("Read our full Privacy Policy", systemImage: "arrow.up.right")
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }
                    .padding(.top, 24)

                    // MARK: - Accept button
                    Button(action: onAccept) {
                        Text("I Understand — Let's Scan!")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.green, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                    .padding(.bottom, 48)
                }
            }
        }
    }
}

// MARK: - Supporting row view

private struct ConsentRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Preview

#Preview {
    ConsentView(onAccept: {})
}
