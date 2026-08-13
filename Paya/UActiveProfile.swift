import Foundation

// MARK: - Active Profile accessor
// Single source of truth for "whose data are we reading/writing right now".

enum ActiveProfile {
    static var id: UUID? {
        guard let s = UserDefaults.standard.string(forKey: "current_profile_id") else { return nil }
        return UUID(uuidString: s)
    }
}//
//  UActiveProfile.swift
//  Paya
//
//  Created by Emin Huseynzade on 11.07.26.
//

