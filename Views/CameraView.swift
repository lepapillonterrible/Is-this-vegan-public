// CameraView.swift
// IsThisVegan
//
// A dedicated quick-capture view that opens the camera immediately.
// Used as a standalone tab or shortcut for fast scanning.
//
// Flow: Camera → capture → viewModel.processImage() → result
//
// On devices without a camera (simulator), shows a fallback
// message directing users to the Scan tab.

import SwiftUI
import AVFoundation

struct CameraView: View {

    // MARK: - Dependencies

    /// Shared view model for processing captured images.
    @EnvironmentObject private var viewModel: ScannerViewModel

    /// SwiftData context — injected into viewModel on appear.
    @Environment(\.modelContext) private var modelContext

    // MARK: - Local State

    /// The image captured by the camera picker.
    @State private var capturedImage: UIImage?

    /// Whether the camera picker is currently showing.
    @State private var showCamera = false

    /// Whether to show the result sheet after processing.
    @State private var showResult = false

    /// Guard to auto-open the camera only on first appear.
    @State private var hasAppeared = false

    /// Camera permission status, checked before presenting the picker.
    @State private var cameraPermission: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if !ImageSource.isCameraAvailable {
                    cameraUnavailableView
                } else if cameraPermission == .denied || cameraPermission == .restricted {
                    cameraPermissionDeniedView
                } else {
                    cameraAvailableView
                }
            }
            .navigationTitle("Quick Scan")
            .navigationBarTitleDisplayMode(.inline)

            // Camera picker (full screen)
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker(image: $capturedImage)
                    .ignoresSafeArea()
            }

            // Result sheet
            .sheet(isPresented: $showResult) {
                if let result = viewModel.latestResult {
                    ResultView(result: result)
                        .environmentObject(viewModel)
                }
            }

            // Forward captured image to viewModel
            .onChange(of: capturedImage) { _, newImage in
                if let newImage {
                    viewModel.processImage(newImage)
                    capturedImage = nil
                }
            }

            // Show result when analysis completes
            .onChange(of: viewModel.latestResult) { _, newResult in
                if newResult != nil {
                    showResult = true
                }
            }

            // Reset result sheet when scanning again
            .onChange(of: viewModel.selectedImage) { _, newImage in
                if newImage == nil {
                    showResult = false
                }
            }

            // Inject context on appear and auto-open camera on first visit
            .onAppear {
                viewModel.modelContext = modelContext
                cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)
                if !hasAppeared {
                    hasAppeared = true
                    requestCameraPermissionAndOpen()
                }
            }
        }
    }

    // MARK: - Camera Available

    /// View shown when the device has a camera.
    /// Shows a preview of the captured image or a prompt to take a photo.
    private var cameraAvailableView: some View {
        VStack(spacing: 24) {
            Spacer()

            if let image = viewModel.selectedImage {
                // Show the captured image with processing overlay
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                    .overlay {
                        if viewModel.isProcessing {
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

                // Error message
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 24)
                }
            } else {
                // Prompt to take a photo
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 64))
                    .foregroundStyle(.green.opacity(0.6))

                Text("Point your camera at a\nproduct label or menu")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Take Photo button
            Button {
                showCamera = true
            } label: {
                Label(
                    viewModel.selectedImage == nil ? "Open Camera" : "Retake Photo",
                    systemImage: "camera.fill"
                )
                .frame(maxWidth: .infinity)
                .padding()
                .background(.green)
                .foregroundStyle(.white)
                .fontWeight(.semibold)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(viewModel.isProcessing)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Camera Unavailable (Simulator)

    /// Fallback view shown on devices without a camera (e.g. simulator).
    private var cameraUnavailableView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "camera.slash")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Camera Not Available")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Use the **Scan** tab to choose\na photo from your library instead.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Camera Permission Denied

    /// Shown when the user has denied camera access.
    /// Provides a clear message and a button to open Settings.
    private var cameraPermissionDeniedView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "camera.badge.ellipsis")
                .font(.system(size: 64))
                .foregroundStyle(.orange)

            Text("Camera Access Required")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Is This Vegan needs camera access to scan\nproduct labels and menus.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            } label: {
                Label("Open Settings", systemImage: "gear")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green)
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)

            Text("You can also use the **Scan** tab to\npick a photo from your library.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Spacer()
        }
    }

    // MARK: - Permission Helpers

    /// Request camera permission on first launch, then open the camera if granted.
    private func requestCameraPermissionAndOpen() {
        switch cameraPermission {
        case .authorized:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showCamera = true
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraPermission = granted ? .authorized : .denied
                    if granted {
                        showCamera = true
                    }
                }
            }
        case .denied, .restricted:
            break // UI handles this state
        @unknown default:
            break
        }
    }
}

// MARK: - Preview

#Preview {
    CameraView()
        .environmentObject(ScannerViewModel())
        .modelContainer(for: ScanResult.self, inMemory: true)
}
