import Foundation
import CoreBluetooth
import SwiftUI

@MainActor
@Observable
class BLEHeartRateManager: NSObject {

    static let shared = BLEHeartRateManager()

    // Fixed BLE UUID constants read from nonisolated CBPeripheralDelegate
    // callbacks (CoreBluetooth calls these off the main actor) — safe to
    // mark nonisolated since they're immutable and never touch actor state.
    nonisolated static let heartRateServiceUUID     = CBUUID(string: "180D")
    nonisolated static let heartRateMeasurementUUID = CBUUID(string: "2A37")
    nonisolated static let batteryServiceUUID       = CBUUID(string: "180F")
    nonisolated static let batteryLevelUUID         = CBUUID(string: "2A19")

    private static let savedPeripheralKey = "ble_hr_saved_peripheral_uuid"

    var connectionState: ConnectionState = .idle
    var currentBPM: Int? = nil
    var batteryLevel: Int? = nil
    var connectedDeviceName: String? = nil
    var discoveredDevices: [DiscoveredDevice] = []
    var errorMessage: String? = nil

    enum ConnectionState: Equatable {
        case idle
        case bluetoothOff
        case unauthorized
        case scanning
        case connecting(deviceName: String)
        case connected
        case disconnected
    }

    struct DiscoveredDevice: Identifiable, Equatable {
        let id: UUID
        let name: String
        let rssi: Int

        var signalStrength: SignalStrength {
            switch rssi {
            case -50...0:      return .excellent
            case -70...(-51):  return .good
            case -85...(-71):  return .fair
            default:           return .poor
            }
        }

        enum SignalStrength {
            case excellent, good, fair, poor
            var color: Color {
                switch self {
                case .excellent: return Color(hex: "059669")
                case .good:      return Color(hex: "4D7C0F")
                case .fair:      return Color(hex: "B45309")
                case .poor:      return Color(hex: "DC2626")
                }
            }
            var displayName: String {
                switch self {
                case .excellent: return "Excellent"
                case .good:      return "Good"
                case .fair:      return "Fair"
                case .poor:      return "Weak"
                }
            }
        }
    }

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var hrCharacteristic: CBCharacteristic?
    private var batteryCharacteristic: CBCharacteristic?
    private var shouldAutoReconnect: Bool = true
    private var peripheralsByUUID: [UUID: CBPeripheral] = [:]

    override init() {
        super.init()
    }

    func initializeIfNeeded() {
            guard centralManager == nil else { return }
            centralManager = CBCentralManager(
                delegate: self,
                queue: .main,
                options: [
                    CBCentralManagerOptionRestoreIdentifierKey: "PayaBLECentral",
                    CBCentralManagerOptionShowPowerAlertKey: true
                ]
            )
        }

    func startScan() {
        initializeIfNeeded()
        errorMessage = nil
        discoveredDevices = []

        guard centralManager.state == .poweredOn else {
            handleBluetoothState(centralManager.state)
            return
        }

        connectionState = .scanning
        centralManager.scanForPeripherals(
            withServices: [Self.heartRateServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
            guard let self = self else { return }
            if case .scanning = self.connectionState {
                self.stopScan()
            }
        }
    }

    func stopScan() {
        centralManager?.stopScan()
        if case .scanning = connectionState {
            connectionState = .idle
        }
    }

    func connect(to device: DiscoveredDevice) {
            guard let peripheral = peripheralsByUUID[device.id] else { return }
            stopScan()
            shouldAutoReconnect = true
            connectionState = .connecting(deviceName: device.name)
            self.peripheral = peripheral
            peripheral.delegate = self
            centralManager.connect(peripheral, options: [
                CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
                CBConnectPeripheralOptionNotifyOnConnectionKey: true,
                CBConnectPeripheralOptionNotifyOnNotificationKey: true
            ])
        }

    func disconnect() {
        shouldAutoReconnect = false
        if let peripheral = peripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        peripheral = nil
        hrCharacteristic = nil
        batteryCharacteristic = nil
        connectedDeviceName = nil
        currentBPM = nil
        batteryLevel = nil
        connectionState = .disconnected
        UserDefaults.standard.removeObject(forKey: Self.savedPeripheralKey)
    }

    func attemptAutoReconnect() {
        guard let uuidString = UserDefaults.standard.string(forKey: Self.savedPeripheralKey),
              let uuid = UUID(uuidString: uuidString) else { return }

        initializeIfNeeded()

        guard centralManager.state == .poweredOn else { return }

        let known = centralManager.retrievePeripherals(withIdentifiers: [uuid])
        guard let peripheral = known.first else { return }

        self.peripheral = peripheral
                peripheral.delegate = self
                connectionState = .connecting(deviceName: peripheral.name ?? "Heart Rate Monitor")
                centralManager.connect(peripheral, options: [
                    CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
                    CBConnectPeripheralOptionNotifyOnConnectionKey: true,
                    CBConnectPeripheralOptionNotifyOnNotificationKey: true
                ])
            }

    private func handleBluetoothState(_ state: CBManagerState) {
        switch state {
        case .poweredOn:
            connectionState = .idle
            if UserDefaults.standard.string(forKey: Self.savedPeripheralKey) != nil {
                attemptAutoReconnect()
            }
        case .poweredOff:
            connectionState = .bluetoothOff
            errorMessage = "Bluetooth is off. Enable it in Settings."
        case .unauthorized:
            connectionState = .unauthorized
            errorMessage = "Paya doesn't have Bluetooth permission. Enable in Settings."
        case .unsupported:
            connectionState = .bluetoothOff
            errorMessage = "Bluetooth Low Energy is not supported on this device."
        default:
            break
        }
    }

    private func parseHeartRate(from data: Data) -> Int? {
        guard data.count >= 2 else { return nil }
        let flags = data[0]
        let isUInt16 = (flags & 0x01) != 0

        if isUInt16 {
            guard data.count >= 3 else { return nil }
            let low = UInt16(data[1])
            let high = UInt16(data[2])
            return Int(low | (high << 8))
        } else {
            return Int(data[1])
        }
    }
}

extension BLEHeartRateManager: CBCentralManagerDelegate {

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state
        Task { @MainActor in
            self.handleBluetoothState(state)
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {
        let name = peripheral.name
            ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? "Unknown HR Monitor"
        let id = peripheral.identifier
        let rssiValue = RSSI.intValue

        Task { @MainActor in
            self.peripheralsByUUID[id] = peripheral
            let device = DiscoveredDevice(id: id, name: name, rssi: rssiValue)
            if !self.discoveredDevices.contains(where: { $0.id == id }) {
                self.discoveredDevices.append(device)
                self.discoveredDevices.sort { $0.rssi > $1.rssi }
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        let name = peripheral.name ?? "Heart Rate Monitor"
        let id = peripheral.identifier

        Task { @MainActor in
            self.connectedDeviceName = name
            self.connectionState = .connected
            UserDefaults.standard.set(id.uuidString, forKey: Self.savedPeripheralKey)
            peripheral.discoverServices([
                Self.heartRateServiceUUID,
                Self.batteryServiceUUID
            ])
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: (any Error)?
    ) {
        Task { @MainActor in
            self.currentBPM = nil
            self.connectionState = .disconnected
            self.connectedDeviceName = nil

            if self.shouldAutoReconnect,
               UserDefaults.standard.string(forKey: Self.savedPeripheralKey) != nil {
                self.attemptAutoReconnect()
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: (any Error)?
    ) {
        let errorDesc = error?.localizedDescription
        Task { @MainActor in
            self.connectionState = .disconnected
            self.errorMessage = "Failed to connect: \(errorDesc ?? "unknown error")"
        }
    }
}

extension BLEHeartRateManager: CBPeripheralDelegate {

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: (any Error)?
    ) {
        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == Self.heartRateServiceUUID {
                peripheral.discoverCharacteristics([Self.heartRateMeasurementUUID], for: service)
            } else if service.uuid == Self.batteryServiceUUID {
                peripheral.discoverCharacteristics([Self.batteryLevelUUID], for: service)
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: (any Error)?
    ) {
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            if characteristic.uuid == Self.heartRateMeasurementUUID {
                Task { @MainActor in
                    self.hrCharacteristic = characteristic
                }
                peripheral.setNotifyValue(true, for: characteristic)
            } else if characteristic.uuid == Self.batteryLevelUUID {
                Task { @MainActor in
                    self.batteryCharacteristic = characteristic
                }
                peripheral.readValue(for: characteristic)
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        guard let data = characteristic.value else { return }
        let uuid = characteristic.uuid

        Task { @MainActor in
            if uuid == Self.heartRateMeasurementUUID {
                if let bpm = self.parseHeartRate(from: data) {
                    self.currentBPM = bpm
                }
            } else if uuid == Self.batteryLevelUUID, let first = data.first {
                self.batteryLevel = Int(first)
            }
        }
    }
    nonisolated func centralManager(
            _ central: CBCentralManager,
            willRestoreState dict: [String: Any]
        ) {
            // Restore peripherals iOS reconnected while the app was suspended
            if let restored = dict[CBCentralManagerRestoredStatePeripheralsKey]
                as? [CBPeripheral],
               let peripheral = restored.first {
                Task { @MainActor in
                    self.peripheral = peripheral
                    peripheral.delegate = self
                    self.connectionState = .connecting(
                        deviceName: peripheral.name ?? "Heart Rate Monitor"
                    )
                }
            }
        }
}//
//  BLEHeartRateManager.swift
//  Paya
//
//  Created by Emin Huseynzade on 05.07.26.
//

