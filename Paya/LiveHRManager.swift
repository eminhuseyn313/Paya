import Foundation
import SwiftUI

@MainActor
@Observable
class LiveHRManager {

    static let shared = LiveHRManager()

    enum HRSource {
        case ble
        case watch
        case none

        var displayName: String {
            switch self {
            case .ble:   return "BLE"
            case .watch: return "Watch"
            case .none:  return "—"
            }
        }
    }

    enum HRZone: Int, CaseIterable {
        case one = 1
        case two = 2
        case three = 3
        case four = 4
        case five = 5

        var color: Color {
            switch self {
            case .one:   return Color(hex: "2563EB")
            case .two:   return Color(hex: "059669")
            case .three: return Color(hex: "B45309")
            case .four:  return Color(hex: "C2410C")
            case .five:  return Color(hex: "DC2626")
            }
        }

        var displayName: String {
            switch self {
            case .one:   return "Z1 · Recovery"
            case .two:   return "Z2 · Endurance"
            case .three: return "Z3 · Aerobic"
            case .four:  return "Z4 · Threshold"
            case .five:  return "Z5 · Max"
            }
        }

        var shortName: String { "Z\(rawValue)" }

        var lowerPercent: Double {
            switch self {
            case .one:   return 0.50
            case .two:   return 0.60
            case .three: return 0.70
            case .four:  return 0.80
            case .five:  return 0.90
            }
        }
    }

    var maxHR: Int {
        didSet { UserDefaults.standard.set(maxHR, forKey: "user_max_hr") }
    }

    init() {
        let stored = UserDefaults.standard.integer(forKey: "user_max_hr")
        self.maxHR = stored > 0 ? stored : 187
    }

    var currentBPM: Int? {
        BLEHeartRateManager.shared.currentBPM
    }

    var currentSource: HRSource {
        if BLEHeartRateManager.shared.currentBPM != nil,
           case .connected = BLEHeartRateManager.shared.connectionState {
            return .ble
        }
        return .none
    }

    var isReceivingData: Bool {
        currentBPM != nil
    }

    var currentZone: HRZone? {
        guard let bpm = currentBPM else { return nil }
        return zone(for: bpm)
    }

    func zone(for bpm: Int) -> HRZone? {
        let percent = Double(bpm) / Double(maxHR)
        switch percent {
        case 0.90...:      return .five
        case 0.80..<0.90:  return .four
        case 0.70..<0.80:  return .three
        case 0.60..<0.70:  return .two
        case 0.50..<0.60:  return .one
        default:           return nil
        }
    }

    func bpmForPercent(_ percent: Double) -> Int {
        Int(Double(maxHR) * percent)
    }

    func setMaxHRFromAge(_ age: Int) {
        maxHR = max(120, 220 - age)
    }
}//
//  LiveHRManager.swift
//  Paya
//
//  Created by Emin Huseynzade on 05.07.26.
//

