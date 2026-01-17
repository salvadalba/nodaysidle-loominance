//
//  PermissionDebugView.swift
//  Loominance
//
//  Debug view for testing permission states
//

import SwiftUI
import Combine

struct PermissionDebugView: View {
    @ObservedObject private var permissionManager = PermissionManager.shared
    @State private var isRequesting = false
    @State private var lastResult = "N/A"
    @State private var cancellables = Set<AnyCancellable>()
    
    private let cardBackground = Color(red: 0.14, green: 0.14, blue: 0.15)
    private let borderColor = Color(red: 0.22, green: 0.22, blue: 0.24)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "ladybug.fill")
                    .foregroundColor(.red)
                Text("Permission Debug")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Divider()
                .background(borderColor)
            
            // Current State
            VStack(alignment: .leading, spacing: 12) {
                Text("Current State")
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack {
                    Text("Permission Status:")
                        .foregroundColor(.gray)
                    Spacer()
                    statusBadge
                }
                .padding()
                .background(cardBackground)
                .cornerRadius(8)
                
                HStack {
                    Text("Last Request Result:")
                        .foregroundColor(.gray)
                    Spacer()
                    Text(lastResult)
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
                .padding()
                .background(cardBackground)
                .cornerRadius(8)
            }
            
            // Actions
            VStack(alignment: .leading, spacing: 12) {
                Text("Actions")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Button {
                    recheckPermission()
                } label: {
                    Label("Recheck Permission", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(cardBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(borderColor, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                
                Button {
                    requestPermission()
                } label: {
                    HStack {
                        if isRequesting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        }
                        Label(isRequesting ? "Requesting..." : "Request Permission", systemImage: "lock.shield")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(isRequesting)
                
                Button {
                    permissionManager.openSystemSettingsScreenRecording()
                } label: {
                    Label("Open System Settings", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            // System Info
            VStack(alignment: .leading, spacing: 12) {
                Text("System Information")
                    .font(.headline)
                    .foregroundColor(.white)
                
                InfoRow(label: "macOS Version", value: ProcessInfo.processInfo.operatingSystemVersionString)
                InfoRow(label: "App Name", value: Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Unknown")
                InfoRow(label: "Bundle ID", value: Bundle.main.bundleIdentifier ?? "Unknown")
            }
            
            // Terminal Commands
            VStack(alignment: .leading, spacing: 12) {
                Text("Useful Terminal Commands")
                    .font(.headline)
                    .foregroundColor(.white)
                
                CommandBox(
                    title: "Reset Permission",
                    command: "tccutil reset ScreenCapture \(Bundle.main.bundleIdentifier ?? "com.app.bundle")"
                )
                
                CommandBox(
                    title: "Reset All Screen Recording",
                    command: "tccutil reset ScreenCapture"
                )
            }
            
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
    }
    
    // MARK: - Status Badge
    
    @ViewBuilder
    private var statusBadge: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(permissionManager.screenRecordingPermission.description.uppercased())
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.2))
        .cornerRadius(12)
    }
    
    private var statusColor: Color {
        switch permissionManager.screenRecordingPermission {
        case .granted:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        case .unknown:
            return .gray
        }
    }
    
    // MARK: - Actions
    
    private func recheckPermission() {
        Task {
            await permissionManager.checkScreenRecordingPermission()
            lastResult = "Rechecked: \(permissionManager.screenRecordingPermission)"
        }
    }
    
    private func requestPermission() {
        isRequesting = true
        
        permissionManager.requestScreenRecordingPermission()
            .sink { state in
                isRequesting = false
                lastResult = "Requested: \(state)"
                AppLogger.app.info("Permission debug request completed: \(state)")
            }
            .store(in: &cancellables)
    }
}

// MARK: - Helper Views

struct InfoRow: View {
    let label: String
    let value: String
    
    private let cardBackground = Color(red: 0.14, green: 0.14, blue: 0.15)
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .foregroundColor(.white)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding()
        .background(cardBackground)
        .cornerRadius(8)
    }
}

struct CommandBox: View {
    let title: String
    let command: String
    @State private var copied = false
    
    private let cardBackground = Color(red: 0.14, green: 0.14, blue: 0.15)
    private let borderColor = Color(red: 0.22, green: 0.22, blue: 0.24)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Button {
                    copyToClipboard()
                } label: {
                    Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(copied ? .green : .blue)
                }
                .buttonStyle(.plain)
            }
            
            Text(command)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.3))
                .cornerRadius(4)
        }
        .padding()
        .background(cardBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        copied = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }
}

// MARK: - Preview

#Preview {
    PermissionDebugView()
        .frame(width: 500, height: 800)
        .preferredColorScheme(.dark)
}

import AppKit
