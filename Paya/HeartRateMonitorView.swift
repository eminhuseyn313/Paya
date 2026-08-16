import SwiftUI

struct HeartRateMonitorView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    var ble: BLEHeartRateManager = .shared
    var hr: LiveHRManager = .shared

    @State private var showZoneEditor: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    StatusCard(ble: ble, hr: hr)

                    if hr.currentBPM != nil {
                        LiveHRDetailsCard(hr: hr)
                    }

                    if case .connected = ble.connectionState {
                        ConnectedActionsCard(ble: ble)
                    } else {
                        ScanControlsCard(ble: ble)
                    }

                    CompatibleDevicesInfo()

                    MaxHRCard(hr: hr, appState: appState) {
                        showZoneEditor = true
                    }

                    if showZoneEditor {
                        ZonesBreakdownCard(hr: hr)
                    }

                    Spacer().frame(height: 30)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("Heart Rate Monitor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                ble.initializeIfNeeded()
                ble.attemptAutoReconnect()
            }
        }
    }
}

struct StatusCard: View {
    var ble: BLEHeartRateManager
    var hr: LiveHRManager

    var statusColor: Color {
        switch ble.connectionState {
        case .connected: return Color(hex: "059669")
        case .connecting, .scanning: return Color(hex: "B45309")
        case .bluetoothOff, .unauthorized: return Color(hex: "DC2626")
        default: return .secondary
        }
    }

    var statusText: String {
        switch ble.connectionState {
        case .idle:                             return "Not connected"
        case .bluetoothOff:                     return "Bluetooth is off"
        case .unauthorized:                     return "Bluetooth permission needed"
        case .scanning:                         return "Searching..."
        case .connecting(let name):             return "Connecting to \(name)..."
        case .connected:
            return ble.connectedDeviceName ?? "Connected"
        case .disconnected:                     return "Disconnected"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "heart.fill")
                    .font(.system(size: 34))
                    .foregroundColor(statusColor)
            }
            Text(statusText)
                .font(.subheadline.weight(.semibold))
            if let battery = ble.batteryLevel {
                HStack(spacing: 4) {
                    Image(systemName: battery > 20 ? "battery.100" : "battery.25")
                        .font(.caption)
                    Text("\(battery)%")
                        .font(.caption.weight(.semibold))
                }
                .foregroundColor(battery > 20 ? .secondary : Color(hex: "B45309"))
            }
            if let error = ble.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(Color(hex: "B45309"))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .payaCard(padding: 20)
    }
}

struct LiveHRDetailsCard: View {
    var hr: LiveHRManager

    @State private var pulse: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "heart.fill")
                    .font(.title)
                    .foregroundColor(.red)
                    .scaleEffect(pulse ? 1.15 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                        value: pulse
                    )
                Text("\(hr.currentBPM ?? 0)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                VStack(alignment: .leading, spacing: 0) {
                    Text("BPM")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.secondary)
                    if let zone = hr.currentZone {
                        Text(zone.shortName)
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(zone.color)
                    }
                }
            }
            if let zone = hr.currentZone {
                Text(zone.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(zone.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(zone.color.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .payaCard(padding: 20)
        .onAppear { pulse = true }
    }
}

struct ScanControlsCard: View {
    var ble: BLEHeartRateManager

    var isScanning: Bool {
        if case .scanning = ble.connectionState { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Available devices")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if !isScanning && ble.discoveredDevices.isEmpty {
                    Text("Tap Scan to search")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if isScanning {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Searching for heart rate monitors...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !ble.discoveredDevices.isEmpty {
                VStack(spacing: 8) {
                    ForEach(ble.discoveredDevices) { device in
                        Button {
                            ble.connect(to: device)
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(device.signalStrength.color)
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.primary)
                                    Text("Signal: \(device.signalStrength.displayName)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("Pair")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .background(Color(hex: "2563EB"))
                                    .clipShape(Capsule())
                            }
                            .padding(10)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }

            Button {
                if isScanning {
                    ble.stopScan()
                } else {
                    ble.startScan()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            } label: {
                HStack {
                    Image(systemName: isScanning ? "stop.fill" : "magnifyingglass")
                    Text(isScanning ? "Stop scanning" : "Scan for devices")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isScanning
                    ? Color(hex: "B45309")
                    : Color(hex: "2563EB"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .payaCard(padding: 14)
    }
}

struct ConnectedActionsCard: View {
    var ble: BLEHeartRateManager

    var body: some View {
        Button {
            ble.disconnect()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            HStack {
                Image(systemName: "xmark.circle.fill")
                Text("Disconnect and forget")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct CompatibleDevicesInfo: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(Color(hex: "2563EB"))
                Text("Compatible with any standard BLE HR device")
                    .font(.caption.weight(.semibold))
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                CompatBullet(text: "Coospo armbands & chest straps (HW9, HW706, H6, H808S)")
                CompatBullet(text: "Polar chest straps (H10, H9, OH1)")
                CompatBullet(text: "Wahoo TICKR series")
                CompatBullet(text: "Garmin HRM-Dual, HRM-Pro, HRM-Fit")
                CompatBullet(text: "Any device supporting BLE profile 0x180D")
            }
            .padding(.leading, 4)
        }
        .payaCard(padding: 14)
    }
}

struct CompatBullet: View {
    var text: String
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("·").foregroundColor(.secondary)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct MaxHRCard: View {
    var hr: LiveHRManager
    var appState: AppState
    var onShowZones: () -> Void

    @State private var age: Int = 33
    @State private var maxHR: Int = 187

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your zones")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    onShowZones()
                } label: {
                    Text("Show breakdown")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color(hex: "2563EB"))
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Age")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Stepper("\(age)", value: $age, in: 15...90)
                            .labelsHidden()
                        Text("\(age)")
                            .font(.subheadline.weight(.bold))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Max HR")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(maxHR) BPM")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(Color(hex: "DC2626"))
                }
            }
            .padding(10)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text("Max HR is estimated as 220 minus your age. Override in User Profile if you know your true max.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .payaCard(padding: 14)
        .onAppear {
            age = appState.profile.age
            maxHR = hr.maxHR
        }
        .onChange(of: age) { _, newAge in
            appState.profile.age = newAge   // triggers UserProfile.age setter → updates birthYear
            hr.setMaxHRFromAge(newAge)
            maxHR = hr.maxHR
        }
    }
}

struct ZonesBreakdownCard: View {
    var hr: LiveHRManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Zone breakdown")
                .font(.subheadline.weight(.semibold))

            ForEach(LiveHRManager.HRZone.allCases, id: \.rawValue) { zone in
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(zone.color)
                        .frame(width: 4, height: 32)
                        .clipShape(Capsule())
                    VStack(alignment: .leading, spacing: 1) {
                        Text(zone.displayName)
                            .font(.caption.weight(.bold))
                            .foregroundColor(zone.color)
                        Text("\(hr.bpmForPercent(zone.lowerPercent))–\(hr.bpmForPercent(zone.lowerPercent + 0.10)) BPM")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .payaCard(padding: 14)
    }
}//
//  HeartRateMonitorView.swift
//  Paya
//
//  Created by Emin Huseynzade on 05.07.26.
//

