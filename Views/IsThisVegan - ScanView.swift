// ScanView.swift
// IsThisVegan
//
// The main scanning screen where users can:
// 1. Choose input type (product label or restaurant menu)
// 2. Take a photo with the camera
// 3. Select a photo from their library
// 4. See the analysis in progress
// 5. View the result
//
// This view is intentionally thin — all analysis logic lives in
// ScannerViewModel. The view just binds to published properties
// and calls public methods on the view model.

import SwiftUI
import SwiftData
import AVFoundation

struct ScanView: View {

    // MARK: - Dependencies

    /// The shared view model that owns all scan state and logic.
    @EnvironmentObject private var viewModel: ScannerViewModel

    /// SwiftData context — passed to the viewModel on appear.
    @Environment(\.modelContext) private var modelContext

    /// Action to trigger on appear, injected by ContentView from a widget intent.
    /// "camera" | "library" | nil
    @Binding var pendingWidgetAction: String?

    // MARK: - Initialiser

    /// Convenience init so existing call-sites that don't pass a binding still compile.
    init(pendingWidgetAction: Binding<String?> = .constant(nil)) {
        self._pendingWidgetAction = pendingWidgetAction
    }

    // MARK: - Local UI State (presentation only, not business logic)

    /// Controls the camera picker sheet.
    @State private var showCameraPicker = false

    /// Controls the photo library picker sheet.
    @State private var showPhotoPicker = false

    /// Controls the result sheet.
    @State private var showResult = false

    /// Local binding for CameraPicker — forwarded to viewModel on change.
    @State private var pickedCameraImage: UIImage?

    /// Local binding for PhotoLibraryPicker — forwarded to viewModel on change.
    @State private var pickedLibraryImage: UIImage?

    /// Whether to show the camera-denied alert.
    @State private var showCameraDeniedAlert = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color.green.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        Spacer(minLength: 20)
                        
                        // MARK: Title
                        Text("Is This Vegan?")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .padding(.horizontal, 24)

                        Spacer(minLength: 20)

                        // MARK: Main Content Area
                        if viewModel.isProcessing {
                            // MARK: - Loading State
                            VStack(spacing: 20) {
                                Image("BrockLoading")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 150, height: 150)
                                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                                
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .tint(.green)
                                
                                Text("Analyzing...")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 300)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .padding(.horizontal)
                        } else {
                            // MARK: - Ready State (Always shown when not processing)
                            VStack(spacing: 24) {
                                Image("BrockReady")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 200, height: 200)
                                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                                
                                Text("Ready to Scan!")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)

                                Text("Scan ingredients on food, cosmetics,\nor household products")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }

                        // MARK: Error Message
                        if let errorMessage = viewModel.errorMessage {
                            errorBanner(errorMessage)
                        }

                        Spacer(minLength: 40)

                        // MARK: Action Buttons
                        actionButtons
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)

            // --- Sheets ---

            // Camera picker (full screen for immersive capture)
            .fullScreenCover(isPresented: $showCameraPicker) {
                CameraPicker(image: $pickedCameraImage)
                    .ignoresSafeArea()
            }

            // Photo library picker
            .sheet(isPresented: $showPhotoPicker) {
                PhotoLibraryPicker(image: $pickedLibraryImage)
            }

            // Result sheet — shown when the viewModel produces a result
            .sheet(isPresented: $showResult) {
                if let result = viewModel.latestResult {
                    ResultView(result: result)
                        .environmentObject(viewModel)
                }
            }

            // --- Reactive Bindings ---

            // Forward camera image to viewModel
            .onChange(of: pickedCameraImage) { _, newImage in
                if let newImage {
                    viewModel.processImage(newImage)
                    pickedCameraImage = nil // reset for next pick
                }
            }

            // Forward library image to viewModel
            .onChange(of: pickedLibraryImage) { _, newImage in
                if let newImage {
                    viewModel.processImage(newImage)
                    pickedLibraryImage = nil // reset for next pick
                }
            }

            // Show result sheet when analysis completes
            .onChange(of: viewModel.latestResult) { _, newResult in
                if newResult != nil {
                    showResult = true
                }
            }

            // Hide result sheet when scanAgain() is called (selectedImage becomes nil)
            .onChange(of: viewModel.selectedImage) { _, newImage in
                if newImage == nil {
                    showResult = false
                }
            }

            // Inject the SwiftData context into the viewModel on appear
            .onAppear {
                viewModel.modelContext = modelContext
                viewModel.refreshUsageStats()
                viewModel.requestLocationPermission()
            }
            // Trigger camera or library picker when launched from a widget intent
            .onChange(of: pendingWidgetAction) { _, action in
                guard let action else { return }
                pendingWidgetAction = nil   // consume immediately
                switch action {
                case "camera":  requestCameraPermission()
                case "library": showPhotoPicker = true
                default: break
                }
            }
        }
    }

    // MARK: - Subviews

    /// The image preview with an optional loading overlay
    @ViewBuilder
    private func imagePreview(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 200)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            .overlay {
                if viewModel.isProcessing {
                    // Frosted glass overlay with spinner
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                Text("Analyzing…")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                }
            }
            .padding(.horizontal, 24)
    }

    /// Error banner that clears on tap
    @ViewBuilder
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
            Spacer()
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.08))
        )
        .padding(.horizontal, 24)
        .onTapGesture {
            viewModel.clearError()
        }
    }

    /// Camera and photo library buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Camera button (hidden on simulator where camera is unavailable)
            if ImageSource.isCameraAvailable {
                Button {
                    requestCameraPermission()
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green)
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(viewModel.isProcessing)
                .alert("Camera Access Required", isPresented: $showCameraDeniedAlert) {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Please enable camera access in Settings to scan product labels.")
                }
            }

            // Photo library button
            Button {
                showPhotoPicker = true
            } label: {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green.opacity(0.15))
                    .foregroundStyle(.green)
                    .fontWeight(.semibold)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(viewModel.isProcessing)

            // Usage stats footer — uses todayAPICalls (the actual UsageStats property)
            if viewModel.usageStats.todayAPICalls > 0 {
                Text("\(viewModel.usageStats.todayAPICalls) scans today")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Permission Helpers

    /// Check camera permission before opening the picker.
    private func requestCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCameraPicker = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showCameraPicker = true
                    } else {
                        showCameraDeniedAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showCameraDeniedAlert = true
        @unknown default:
            showCameraPicker = true
        }
    }
}

// MARK: - Helpers

struct InfoCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.green)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: 140, height: 120, alignment: .topLeading)
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

#Preview {
    ScanView()
        .environmentObject(ScannerViewModel())
        .modelContainer(for: ScanResult.self, inMemory: true)
}
