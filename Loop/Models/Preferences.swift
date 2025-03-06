//
//  Preferences.swift
//  Loop
//
//  Created by Jonas Björkert on 2024-02-25.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import HealthKit

struct Preferences: PreferencesProvider {
    
    static var shared = Preferences()
    
    private init() {}
    
    private func lookupBool(_ key: String, _ defaultValue: Bool) -> Bool {
        if UserDefaults.standard.object(forKey: key) == nil {
            return defaultValue
        }
        return UserDefaults.standard.bool(forKey: key)
    }
    
    // Basal Lock Threshold
    var basalLockThreshold: HKQuantity {
        get {
            let key = "basalLockThreshold"
            if let value = UserDefaults.standard.value(forKey: key) as? Double {
                return HKQuantity(unit: .milligramsPerDeciliter, doubleValue: value)
            } else {
                return HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 250)
            }
        }
        set {
            let key = "basalLockThreshold"
            let value = newValue.doubleValue(for: .milligramsPerDeciliter)
            UserDefaults.standard.set(value, forKey: key)
        }
    }
    
    // Basal Lock Enabled
    var isBasalLockEnabled: Bool {
        get {
            return lookupBool("isBasalLockEnabled", false)
        }
        set {
            let key = "isBasalLockEnabled"
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
    
    // Exclude Carb entry from bolus recommendation
    var isCarbEntryExcluded: Bool {
        get {
            return lookupBool("isCarbEntryExcluded", false)
        }
        set {
            let key = "isCarbEntryExcluded"
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }

    // Exclude COB correction from bolus recommendation
    var isCobCorrectionExcluded: Bool {
        get {
            return lookupBool("isCobCorrectionExcluded", false)
        }
        set {
            let key = "isCobCorrectionExcluded"
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }

    // Exclude glucose correction from bolus recommendation
    var isBgCorrectionExcluded: Bool {
        get {
            return lookupBool("isBgCorrectionExcluded", false)
        }
        set {
            let key = "isBgCorrectionExcluded"
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }

    // Whether to use the rapid acting child insulin model
    var useNewChildInsulinModel: Bool {
        get {
            return lookupBool("useNewChildInsulinModel", false)
        }
        set {
            let key = "useNewChildInsulinModel"
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }

    
    // Whether to use the rapid acting child insulin model
    var useRapidActingChildInsulinModel: Bool {
        get {
            return lookupBool("useRapidActingChildInsulinModel", false)
        }
        set {
            let key = "useRapidActingChildInsulinModel"
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
    
    // Whether use the faster adult Lyumjev insulin model
    var useFastLyumjevInsulinModel: Bool {
        get {
            return lookupBool("useFastLyumjevInsulinModel", false)
        }
        set {
            let key = "useFastLyumjevInsulinModel"
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}
