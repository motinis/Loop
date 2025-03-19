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
import LoopCore

struct Preferences: PreferencesProvider {
    
    static var shared = Preferences()
    
    var loopSettingsUpdater: ((_ changes: (_ settings: inout LoopSettings) -> Void) -> Void)?
    
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
    
    var isSleepScheduleEnabled: Bool {
        get {
            return lookupBool("isSleepScheduleEnabled", false)
        }
        set {
            let key = "isSleepScheduleEnabled"
            UserDefaults.standard.set(newValue, forKey: key)

            if !newValue, let loopSettingsUpdater = loopSettingsUpdater {
                loopSettingsUpdater{ $0.sleepSchedule = nil }
            }

        }
    }
    
    // for UI purposes the value is persisted here. This means that disabling isSleepScheduleEnable will
    // result in LoopSettings.sleepSchedule == nil, the old value can still be stored here
    var sleepSchedule: SleepSchedule? {
        get {
            let key = "sleepSchedule"
            guard let value = UserDefaults.standard.array(forKey: key) as? [Date] else {
                return nil
            }
            return SleepSchedule(start: value[0], end: value[1])
        }
        set {
            let key = "sleepSchedule"
            if let value = newValue {
                UserDefaults.standard.set([value.start, value.end], forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
            
            if isSleepScheduleEnabled, let loopSettingsUpdater = loopSettingsUpdater {
                loopSettingsUpdater{ $0.sleepSchedule = newValue }
            }
        }
    }
}

public struct ResolvedPreferences {
    
    public static var basalLockThreshold: HKQuantity? {
        Preferences.shared.isBasalLockEnabled ? Preferences.shared.basalLockThreshold : nil
    }    
}
