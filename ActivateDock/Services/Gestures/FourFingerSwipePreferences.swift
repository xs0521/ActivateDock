//
//  FourFingerSwipePreferences.swift
//  ActivateDock
//

import Foundation

enum FourFingerSwipePreferences {
    private static let enabledKey = "FourFingerSwipeDownEnabled"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }
}
