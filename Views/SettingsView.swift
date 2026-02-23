import SwiftUI

struct SettingsView: View {
    // Get app version from Bundle
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - About Section
                Section(header: Text("About")) {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(uiImage: UIImage(named: "AppIcon") ?? UIImage()) // Placeholder if asset fails
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .cornerRadius(16)
                                .accessibilityLabel("App Icon")
                            
                            Text("Is This Vegan?")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Version \(appVersion)")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    
                    Text("Is This Vegan? uses advanced AI to analyze ingredients lists and menus, helping you make informed food choices in seconds.")
                        .font(.body)
                        .padding(.vertical, 4)
                }
                
                // MARK: - Legal Section
                Section(header: Text("Legal")) {
                    NavigationLink(destination: PrivacyPolicyView()) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    
                    NavigationLink(destination: TermsView()) {
                        Label("Terms & Conditions", systemImage: "doc.text")
                    }
                }
                
                // MARK: - Footer
                Section {
                    HStack {
                        Spacer()
                        Text("Powered by Google Gemini")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
