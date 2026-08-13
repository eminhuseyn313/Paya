import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
#endif

struct FocusModeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var manager = FocusModeManager.shared
    @State private var isRequesting = false
    #if canImport(FamilyControls)
    @State private var showPicker = false
    #endif

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Blocks the apps you choose below for as long as a training session is active in Paya — a shield screen replaces them until you end or complete the session.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                #if canImport(FamilyControls)
                familyControlsSection
                #else
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Not available in this build")
                            .font(.subheadline.weight(.semibold))
                        Text("App blocking requires the FamilyControls capability, which needs a paid Apple Developer account with explicit approval from Apple.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                #endif
            }
            .navigationTitle("Block Distractions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            #if canImport(FamilyControls)
            .familyActivityPicker(isPresented: $showPicker, selection: Binding(
                get: { manager.selection },
                set: { manager.selection = $0 }
            ))
            #endif
        }
    }

    #if canImport(FamilyControls)
    private var selectedCount: Int {
        manager.selection.applicationTokens.count + manager.selection.categoryTokens.count
    }

    @ViewBuilder
    private var familyControlsSection: some View {
        Section {
            switch manager.authorizationStatus {
            case .approved:
                Toggle("Block during sessions", isOn: Binding(
                    get: { manager.isEnabled },
                    set: { manager.isEnabled = $0 }
                ))

                Button {
                    showPicker = true
                } label: {
                    HStack {
                        Text("Choose apps to block")
                        Spacer()
                        Text(selectedCount > 0 ? "\(selectedCount) selected" : "None")
                            .foregroundColor(.secondary)
                    }
                }

            case .notDetermined:
                Button {
                    Task {
                        isRequesting = true
                        await manager.requestAuthorization()
                        isRequesting = false
                    }
                } label: {
                    if isRequesting {
                        HStack {
                            Spacer()
                            SwiftUI.ProgressView()
                            Spacer()
                        }
                    } else {
                        Text("Allow Screen Time Access")
                    }
                }
                .disabled(isRequesting)

                if let error = manager.lastAuthorizationError {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Couldn't get permission")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Color(hex: "DC2626"))
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("This usually means the app isn't signed with Apple's Family Controls capability yet — personal/free developer accounts can't use it at all, so this needs a paid Apple Developer Program membership with that capability enabled.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

            case .denied:
                VStack(alignment: .leading, spacing: 6) {
                    Text("Screen Time access was denied.")
                        .font(.subheadline.weight(.semibold))
                    Text("Enable it in Settings → Screen Time → Paya, then come back here.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

            @unknown default:
                EmptyView()
            }
        } footer: {
            if manager.authorizationStatus == .approved {
                Text("Paya can turn this on or off but never sees which specific apps you chose — Apple keeps that private even from the app that set it up.")
            }
        }
    }
    #endif
}
