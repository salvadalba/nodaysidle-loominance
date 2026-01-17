//
//  OnboardingView.swift
//  Loominance
//
//  First-time user onboarding experience
//

import SwiftUI
import Combine

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var currentStep = 0

    private let backgroundColor = Color(red: 0.08, green: 0.08, blue: 0.09)
    private let accentColor = Color.red

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Content - simulated tab switching
                currentStepView
                    .frame(maxHeight: .infinity)

                // Navigation
                HStack {
                    // Back button
                    Button {
                        withAnimation {
                            currentStep = max(0, currentStep - 1)
                        }
                    } label: {
                        Text("Back")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                    .opacity(currentStep > 0 ? 1 : 0)

                    Spacer()

                    // Page indicator
                    HStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { index in
                            Circle()
                                .fill(index == currentStep ? accentColor : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }

                    Spacer()

                    // Next/Get Started button
                    Button {
                        if currentStep < 3 {
                            withAnimation {
                                currentStep += 1
                            }
                        } else {
                            hasCompletedOnboarding = true
                            dismiss()
                        }
                    } label: {
                        Text(currentStep < 3 ? "Next" : "Get Started")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(accentColor)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 40)
            }
        }
        .frame(width: 600, height: 450)
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case 0:
            WelcomeStep()
        case 1:
            PermissionStep()
        case 2:
            FeaturesStep()
        case 3:
            ReadyStep()
        default:
            WelcomeStep()
        }
    }
}

// MARK: - Welcome Step

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "record.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.red)

            Text("Welcome to Loominance")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("The intelligent screen recorder with\ncinematic zoom effects")
                .font(.title3)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

// MARK: - Permission Step

struct PermissionStep: View {
    @ObservedObject private var permissionManager = PermissionManager.shared
    @State private var isRequesting = false
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 80, height: 80)
                
                Image(systemName: iconName)
                    .font(.system(size: 40))
                    .foregroundStyle(iconColor)
            }

            Text("Screen Recording Permission")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(descriptionText)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Action button
            actionButton
        }
        .padding(40)
    }
    
    // MARK: - Dynamic Content
    
    private var iconName: String {
        switch permissionManager.screenRecordingPermission {
        case .granted:
            return "checkmark.shield.fill"
        case .denied:
            return "exclamationmark.shield.fill"
        default:
            return "lock.shield.fill"
        }
    }
    
    private var iconColor: Color {
        switch permissionManager.screenRecordingPermission {
        case .granted:
            return .green
        case .denied:
            return .orange
        default:
            return .blue
        }
    }
    
    private var iconBackgroundColor: Color {
        switch permissionManager.screenRecordingPermission {
        case .granted:
            return Color.green.opacity(0.2)
        case .denied:
            return Color.orange.opacity(0.2)
        default:
            return Color.blue.opacity(0.2)
        }
    }
    
    private var descriptionText: String {
        switch permissionManager.screenRecordingPermission {
        case .granted:
            return "Permission granted! You're all set to start recording."
        case .denied:
            return "Permission was denied. Please open System Settings to enable screen recording for Loominance."
        default:
            return "Loominance needs permission to record your screen.\nYou'll be prompted to grant access."
        }
    }
    
    @ViewBuilder
    private var actionButton: some View {
        switch permissionManager.screenRecordingPermission {
        case .granted:
            Label("Permission Granted", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.body)
        case .denied:
            VStack(spacing: 12) {
                Button {
                    permissionManager.openSystemSettingsScreenRecording()
                } label: {
                    Label("Open System Settings", systemImage: "gearshape")
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.orange)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Button {
                    permissionManager.recheckPermission()
                } label: {
                    Text("I've enabled it - check again")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        default:
            Button {
                requestPermission()
            } label: {
                HStack {
                    if isRequesting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    }
                    Text(isRequesting ? "Requesting..." : "Grant Permission")
                        .font(.body)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.blue)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(isRequesting)
        }
    }
    
    private func requestPermission() {
        isRequesting = true
        
        permissionManager.requestScreenRecordingPermission()
            .sink { state in
                isRequesting = false
                AppLogger.app.info("Permission request completed: \(state)")
            }
            .store(in: &cancellables)
    }
}

// MARK: - Features Step

struct FeaturesStep: View {
    var body: some View {
        VStack(spacing: 32) {
            Text("Key Features")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(
                    icon: "video.fill",
                    title: "60 FPS Recording",
                    description: "Smooth, high-quality screen capture"
                )

                FeatureRow(
                    icon: "camera.metering.center.weighted",
                    title: "Auto Zoom",
                    description: "Intelligent cursor-following zoom effects"
                )

                FeatureRow(
                    icon: "square.and.arrow.up",
                    title: "Export Presets",
                    description: "One-click export for social platforms"
                )

                FeatureRow(
                    icon: "folder.fill",
                    title: "Library",
                    description: "All recordings organized in one place"
                )
            }
        }
        .padding(40)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.red)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
    }
}

// MARK: - Ready Step

struct ReadyStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("You're All Set!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(
                "Press ⌘R or click Record to start capturing.\nYour recordings will appear in the Library."
            )
            .font(.body)
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)

            HStack(spacing: 24) {
                VStack {
                    Text("⌘R")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Start/Stop")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                VStack {
                    Text("⌘,")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Settings")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.top, 16)
        }
        .padding(40)
    }
}
