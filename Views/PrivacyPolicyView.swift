import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Privacy Policy")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Last Updated: February 2026")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                SectionView(title: "Data Processing", content: """
                When you scan a product or menu, the image is sent securely to Google's Gemini API for analysis. This is necessary to identify ingredients and determine if they are vegan-friendly.
                """)
                
                SectionView(title: "No Image Storage", content: """
                We do not store your images. Once the analysis is complete, the image is discarded. Your photos are not saved on our servers or used to train our models.
                """)
                
                SectionView(title: "No User Tracking", content: """
                We do not create user accounts, track your location, or collect personal information. The app is designed to be private by default.
                """)
                
                SectionView(title: "Third-Party Services", content: """
                We use Google Gemini for AI analysis. By using this app, you acknowledge that your image data is processed by Google in accordance with their privacy standards for API usage.
                """)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SectionView: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationView {
        PrivacyPolicyView()
    }
}
