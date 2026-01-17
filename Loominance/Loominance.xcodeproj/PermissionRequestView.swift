//
//  PermissionRequestView.swift
//  Loominance
//
//  Dedicated permission request UI with helpful guidance
//

import SwiftUI

struct PermissionRequestView: View {
    @ObservedObject var permissionManager = PermissionManager.shared
    @State private var isRequesting = false
    @State private var showingInstructions = false
    
    private let cardBackground = Color(red: 0.14, green: 0.14, blue: 0.15)
    private let borderColor = Color(red: 0.22, green: 0.22, blue: 0.24)
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 80, height: 80)
                
                Image(systemName: iconName)
                    .font(.system(size: 36))
                    .foregroundStyle(iconColor)
            }
            
            // Title & Description
            VStack(spacing: 12) {
                Text(titleText)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(descriptionText)
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 40)
            
            // Action button(s)
            VStack(spacing: 12) {
                actionButton
                
                if showSecondaryButton {
                    secondaryButton
                }
            }
            .padding(.horizontal, 40)
            
            // Help button
            if permissionManager.screenRecordingPermission == .denied {
                Button {
                    showingInstructions.toggle()
                } label: {
                    Label("How to enable manually", systemImage: "questionmark.circle")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(40)
        .sheet(isPresented: $showingInstructions) {
            ManualPermissionInstructionsView()
        }
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
            return .red
        default:
            return .blue
        }
    }
    
    private var iconBackgroundColor: Color {
        switch permissionManager.screenRecordingPermission {
        case .granted:
            return Color.green.opacity(0.2)
        case .denied:
            return Color.red.opacity(0.2)
        default:
            return Color.blue.opacity(0.2)
        }
    }
    
    private var titleText: String {
        switch permissionManager.screenRecordingPermission {
        case .granted:
            return "Permission Granted ✓"
        case .denied:
            return "Permission Required"
        default:
            return "Screen Recording Permission"
        }
    }
    
    private var descriptionText: String {
        switch permissionManager.screenRecordingPermission {
        case .granted:
            return "You're all set! Loominance can now record your screen."
        case .denied:
            return "Loominance needs screen recording permission to function. Please enable it in System Settings."
        default:
            return "Loominance needs permission to record your screen. You'll be prompted to grant access."
        }
    }
    
    private var showSecondaryButton: Bool {
        permissionManager.screenRecordingPermission == .denied
    }
    
    @ViewBuilder
    private var actionButton: some View {
        switch permissionManager.screenRecordingPermission {
        case .granted:
            EmptyView()
        case .denied:
            Button {
                permissionManager.openSystemSettingsScreenRecording()
            } label: {
                Label("Open System Settings", systemImage: "gearshape.fill")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
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
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(isRequesting)
        }
    }
    
    @ViewBuilder
    private var secondaryButton: some View {
        Button {
            permissionManager.recheckPermission()
        } label: {
            Text("Recheck Permission")
                .font(.body)
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(cardBackground)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Actions
    
    private func requestPermission() {
        isRequesting = true
        
        permissionManager.requestScreenRecordingPermission()
            .sink { state in
                isRequesting = false
                AppLogger.app.info("Permission request completed with state: \(state)")
            }
            .store(in: &cancellables)
    }
    
    @State private var cancellables = Set<AnyCancellable>()
}

// MARK: - Manual Instructions View

struct ManualPermissionInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let backgroundColor = Color(red: 0.11, green: 0.11, blue: 0.12)
    private let cardBackground = Color(red: 0.14, green: 0.14, blue: 0.15)
    
    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("How to Enable Screen Recording")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
                
                // Instructions
                VStack(alignment: .leading, spacing: 20) {
                    InstructionStep(
                        number: 1,
                        title: "Open System Settings",
                        description: "Click the Apple menu () and select 'System Settings'"
                    )
                    
                    InstructionStep(
                        number: 2,
                        title: "Go to Privacy & Security",
                        description: "In the sidebar, find and click 'Privacy & Security'"
                    )
                    
                    InstructionStep(
                        number: 3,
                        title: "Select Screen Recording",
                        description: "Scroll down and click 'Screen Recording'"
                    )
                    
                    InstructionStep(
                        number: 4,
                        title: "Enable Loominance",
                        description: "Find 'Loominance' in the list and toggle the switch ON"
                    )
                    
                    InstructionStep(
                        number: 5,
                        title: "Restart the App",
                        description: "Quit and reopen Loominance for changes to take effect"
                    )
                }
                
                Spacer()
                
                // Quick action button
                Button {
                    PermissionManager.shared.openSystemSettingsScreenRecording()
                    dismiss()
                } label: {
                    Text("Open System Settings Now")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(32)
        }
        .frame(width: 500, height: 550)
    }
}

struct InstructionStep: View {
    let number: Int
    let title: String
    let description: String
    
    private let cardBackground = Color(red: 0.14, green: 0.14, blue: 0.15)
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Step number
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 32, height: 32)
                
                Text("\(number)")
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(16)
        .background(cardBackground)
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    PermissionRequestView()
        .frame(width: 500, height: 400)
        .preferredColorScheme(.dark)
}

#Preview("Instructions") {
    ManualPermissionInstructionsView()
        .preferredColorScheme(.dark)
}

import Combine
