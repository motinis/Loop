//
//  SettingsView+algorithmExperimentsSection.swift
//  Loop
//
//  Created by Jonas Björkert on 2023-06-03.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import SwiftUI
import LoopKit
import LoopKitUI

extension SettingsView {
    internal var algorithmExperimentsSection: some View {
        NavigationLink(NSLocalizedString("Algorithm Experiments", comment: "The title of the Algorithm Experiments section in settings")) {
            ExperimentsSettingsView(automaticDosingStrategy: viewModel.automaticDosingStrategy, sleepSchedule: viewModel.loopSettings().sleepSchedule)
        }
    }
}

public struct ExperimentRow: View {
    var name: String
    var enabled: Bool?

    public var body: some View {
        HStack {
            Text(name)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            Spacer()
            if let enabled = enabled {
                Text(enabled ? "On" : "Off")
                    .foregroundColor(enabled ? .red : .secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .foregroundColor(.accentColor)
        .cornerRadius(10)
    }
}

public struct ExperimentsSettingsView: View {
    @AppStorage(UserDefaults.Key.GlucoseBasedApplicationFactorEnabled.rawValue) private var isGlucoseBasedApplicationFactorEnabled = false
    @AppStorage(UserDefaults.Key.IntegralRetrospectiveCorrectionEnabled.rawValue) private var isIntegralRetrospectiveCorrectionEnabled = false
    @AppStorage(UserDefaults.Key.NegativeInsulinDamperEnabled.rawValue) private var isNegativeInsulinDamperEnabled = false
    @AppStorage(UserDefaults.Key.SleepScheduleAffectsNegativeInsulinDamperEnabled.rawValue) private var isSleepScheduleAffectsNegativeInsulinDamperEnabled = false
    @AppStorage(UserDefaults.Key.AutoBolusCarbsEnabled.rawValue) private var isAutoBolusCarbsEnabled = false
    @AppStorage(UserDefaults.Key.AutoBolusCarbsActiveByDefault.rawValue) private var autoBolusCarbsActiveByDefault = false
    @AppStorage(UserDefaults.Key.AutoBolusCarbsThresholdPercentage.rawValue) private var autoBolusCarbsThresholdPercentage = UserDefaults.DEFAULT_AUTO_BOLUS_CARBS_THRESHOLD_PERCENTAGE
    @AppStorage(UserDefaults.Key.AutoBolusCarbsApplicationFactorMin.rawValue) private var autoBolusCarbsApplicationFactorMin = UserDefaults.DEFAULT_AUTO_BOLUS_CARBS_APPLICATION_FACTOR_MIN
    @AppStorage(UserDefaults.Key.AutoBolusCarbsApplicationFactorMax.rawValue) private var autoBolusCarbsApplicationFactorMax = UserDefaults.DEFAULT_AUTO_BOLUS_CARBS_APPLICATION_FACTOR_MAX

    @AppStorage(UserDefaults.Key.CarbResponsiveRetrospectiveCorrectionEnabled.rawValue) private var isCarbResponsiveRetrospectiveCorrectionEnabled = false
    
    @AppStorage(UserDefaults.Key.GlucoseMomentumReductionEnabled.rawValue) private var isGlucoseMomentumReductionEnabled = false
    @AppStorage(UserDefaults.Key.GlucoseMomentumReductionEnabledWhenAsleep.rawValue) private var isGlucoseMomentumReductionEnabledWhenAsleep = false
    
    var automaticDosingStrategy: AutomaticDosingStrategy
    var sleepSchedule: SleepSchedule?

    public var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 12) {
                Text(NSLocalizedString("Algorithm Experiments", comment: "Navigation title for algorithms experiments screen"))
                    .font(.headline)
                VStack {
                    Text("⚠️").font(.largeTitle)
                    Text("Caution")
                }
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("Algorithm Experiments are optional modifications to the Loop Algorithm. These modifications are less tested than the standard Loop Algorithm, so please use carefully.", comment: "Algorithm Experiments description."))
                    Text(NSLocalizedString("In future versions of Loop these experiments may change, end up as standard parts of the Loop Algorithm, or be removed from Loop entirely. Please follow along in the Loop Zulip chat to stay informed of possible changes to these features.", comment: "Algorithm Experiments description second paragraph."))
                }
                .foregroundColor(.secondary)

                Divider()
                NavigationLink(destination: GlucoseBasedApplicationFactorSelectionView(isGlucoseBasedApplicationFactorEnabled: $isGlucoseBasedApplicationFactorEnabled, automaticDosingStrategy: automaticDosingStrategy)) {
                    ExperimentRow(
                        name: NSLocalizedString("Glucose Based Partial Application", comment: "Title of glucose based partial application experiment"),
                        enabled: isGlucoseBasedApplicationFactorEnabled && automaticDosingStrategy == .automaticBolus)
                }
                NavigationLink(destination: IntegralRetrospectiveCorrectionSelectionView(isIntegralRetrospectiveCorrectionEnabled: $isIntegralRetrospectiveCorrectionEnabled)) {
                    ExperimentRow(
                        name: NSLocalizedString("Integral Retrospective Correction", comment: "Title of integral retrospective correction experiment"),
                        enabled: isIntegralRetrospectiveCorrectionEnabled)
                }
                NavigationLink(destination: NegativeInsulinDamperSelectionView(isNegativeInsulinDamperEnabled: $isNegativeInsulinDamperEnabled, isAffectedBySleepSchedule: $isSleepScheduleAffectsNegativeInsulinDamperEnabled, sleepSchedule: sleepSchedule)) {
                    ExperimentRow(
                        name: NSLocalizedString("Negative Insulin Damper", comment: "Title of negative insulin damper experiment"),
                        enabled: isNegativeInsulinDamperEnabled)
                }
                Divider()
                Text("🚧 🚧 🚧")
                NavigationLink(destination: AutoBolusCarbsSelectionView(isAutoBolusCarbsEnabled: $isAutoBolusCarbsEnabled, activeByDefault: $autoBolusCarbsActiveByDefault, thresholdPercentage: $autoBolusCarbsThresholdPercentage, applicationFactorMin: $autoBolusCarbsApplicationFactorMin, applicationFactorMax: $autoBolusCarbsApplicationFactorMax)) {
                    ExperimentRow(
                        name: NSLocalizedString("Auto-Bolus Carbs", comment: "Title of auto-bolus carbs experiment"),
                        enabled: isAutoBolusCarbsEnabled)
                }
                NavigationLink(destination: CarbReactiveRestrospectiveCorrection(isCarbReactiveRetrospectiveCorrectionEnabled: $isCarbResponsiveRetrospectiveCorrectionEnabled)) {
                    ExperimentRow(
                        name: NSLocalizedString("Carb-Reactive Retrospective Correction", comment: "Title of reactive-carb retrospective correction experiment"),
                        enabled: isCarbResponsiveRetrospectiveCorrectionEnabled)
                }
                NavigationLink(destination: GlucoseMomentumReductionEnabledSelectionView(isGlucoseMomentumReductionEnabled: $isGlucoseMomentumReductionEnabled, isGlucoseMomentumReductionEnabledWhenAsleep: $isGlucoseMomentumReductionEnabledWhenAsleep, sleepSchedule: sleepSchedule)) {
                    ExperimentRow(
                        name: NSLocalizedString("Glucose Momentum Reduction", comment: "Title of glucose momentum reduction experiment"),
                        enabled: isGlucoseMomentumReductionEnabled)
                }
                Spacer()
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: isGlucoseBasedApplicationFactorEnabled) { _ in
            NotificationCenter.default.post(name: .AlgorithmExperimentsChanged, object: UserDefaults.standard, userInfo: nil)
        }
        .onChange(of: isIntegralRetrospectiveCorrectionEnabled) { _ in
            NotificationCenter.default.post(name: .AlgorithmExperimentsChanged, object: UserDefaults.standard, userInfo: nil)
        }
        .onChange(of: isNegativeInsulinDamperEnabled) { _ in
            NotificationCenter.default.post(name: .AlgorithmExperimentsChanged, object: UserDefaults.standard, userInfo: nil)
        }
        .onChange(of: isSleepScheduleAffectsNegativeInsulinDamperEnabled) { _ in
            NotificationCenter.default.post(name: .AlgorithmExperimentsChanged, object: UserDefaults.standard, userInfo: nil)
        }
        .onChange(of: isAutoBolusCarbsEnabled) { _ in
            NotificationCenter.default.post(name: .AlgorithmExperimentsChanged, object: UserDefaults.standard, userInfo: nil)
        }
        .onChange(of: autoBolusCarbsActiveByDefault) { _ in
            NotificationCenter.default.post(name: .AlgorithmExperimentsChanged, object: UserDefaults.standard, userInfo: nil)
        }
        .onChange(of: isCarbResponsiveRetrospectiveCorrectionEnabled) {_ in
            NotificationCenter.default.post(name: .AlgorithmExperimentsChanged, object: UserDefaults.standard, userInfo: nil)
        }
        .onChange(of: isGlucoseMomentumReductionEnabled) {_ in
            NotificationCenter.default.post(name: .AlgorithmExperimentsChanged, object: UserDefaults.standard, userInfo: nil)
        }
        .onChange(of: isGlucoseMomentumReductionEnabledWhenAsleep) {_ in
            NotificationCenter.default.post(name: .AlgorithmExperimentsChanged, object: UserDefaults.standard, userInfo: nil)
        }
    }
}

extension Notification.Name {
    static let AlgorithmExperimentsChanged = Notification.Name(rawValue:  "com.loopKit.notification.AlgorithmExperimentsChanged")
}

extension UserDefaults {
    
    static let DEFAULT_AUTO_BOLUS_CARBS_THRESHOLD_PERCENTAGE = 0.0
    static let DEFAULT_AUTO_BOLUS_CARBS_APPLICATION_FACTOR_MIN = 0.2
    static let DEFAULT_AUTO_BOLUS_CARBS_APPLICATION_FACTOR_MAX = 0.8
    
    fileprivate enum Key: String {
        case GlucoseBasedApplicationFactorEnabled = "com.loopkit.algorithmExperiments.glucoseBasedApplicationFactorEnabled"
        case IntegralRetrospectiveCorrectionEnabled = "com.loopkit.algorithmExperiments.integralRetrospectiveCorrectionEnabled"
        case NegativeInsulinDamperEnabled = "com.loopkit.algorithmExperiments.negativeInsulinDamperEnabled"
        case SleepScheduleAffectsNegativeInsulinDamperEnabled = "com.loopkit.algorithmExperiments.sleepScheduleAffectsNegativeInsulinDamperEnabled"
        case AutoBolusCarbsEnabled = "com.loopkit.algorithmExperiments.autoBolusCarbsEnabled"
        case AutoBolusCarbsActiveByDefault = "com.loopkit.algorithmExperiments.autoBolusCarbsActiveByDefault"
        case AutoBolusCarbsThresholdPercentage = "com.loopkit.algorithmExperiments.autoBolusCarbsThresholdPercentage"
        case AutoBolusCarbsApplicationFactorMin = "com.loopkit.algorithmExperiments.autoBolusCarbsApplicationFactorMin"
        case AutoBolusCarbsApplicationFactorMax = "com.loopkit.algorithmExperiments.autoBolusCarbsApplicationFactorMax"
        case CarbResponsiveRetrospectiveCorrectionEnabled = "com.loopkit.algorithmExperiments.carbResponsiveRetrospectiveCorrectionEnabled"
        case GlucoseMomentumReductionEnabled = "com.loopkit.algorithmExperiments.glucoseMomentumReductionEnabled"
        case GlucoseMomentumReductionEnabledWhenAsleep = "com.loopkit.algorithmExperiments.glucoseMomentumReductionEnabledWhenAsleep"
    }

    var glucoseBasedApplicationFactorEnabled: Bool {
        get {
            bool(forKey: Key.GlucoseBasedApplicationFactorEnabled.rawValue) as Bool
        }
        set {
            set(newValue, forKey: Key.GlucoseBasedApplicationFactorEnabled.rawValue)
        }
    }

    var integralRetrospectiveCorrectionEnabled: Bool {
        get {
            bool(forKey: Key.IntegralRetrospectiveCorrectionEnabled.rawValue) as Bool
        }
        set {
            set(newValue, forKey: Key.IntegralRetrospectiveCorrectionEnabled.rawValue)
        }
    }

    var negativeInsulinDamperEnabled: Bool {
        get {
            bool(forKey: Key.NegativeInsulinDamperEnabled.rawValue) as Bool
        }
        set {
            set(newValue, forKey: Key.NegativeInsulinDamperEnabled.rawValue)
        }
    }
    
    var sleepScheduleAffectsNegativeInsulinDamperEnabled: Bool {
        get {
            bool(forKey: Key.SleepScheduleAffectsNegativeInsulinDamperEnabled.rawValue) as Bool
        }
        set {
            set(newValue, forKey: Key.SleepScheduleAffectsNegativeInsulinDamperEnabled.rawValue)
        }
    }

    var autoBolusCarbsEnabled: Bool {
        get {
            bool(forKey: Key.AutoBolusCarbsEnabled.rawValue) as Bool
        }
        set {
            set(newValue, forKey: Key.AutoBolusCarbsEnabled.rawValue)
        }
    }

    var autoBolusCarbsActiveByDefault: Bool {
        get {
            bool(forKey: Key.AutoBolusCarbsActiveByDefault.rawValue) as Bool
        }
        set {
            set(newValue, forKey: Key.AutoBolusCarbsActiveByDefault.rawValue)
        }
    }
    
    var autoBolusCarbsThresholdPercentage: Double {
        get {
            let result = double(forKey: Key.AutoBolusCarbsThresholdPercentage.rawValue) as Double
            return result != 0.0 ? result : Self.DEFAULT_AUTO_BOLUS_CARBS_THRESHOLD_PERCENTAGE
        }
        set {
            set(newValue, forKey: Key.AutoBolusCarbsThresholdPercentage.rawValue)
        }
    }
    
    var autoBolusCarbsApplicationFactorMin: Double {
        get {
            let result = double(forKey: Key.AutoBolusCarbsApplicationFactorMin.rawValue) as Double
            return result != 0.0 ? result : Self.DEFAULT_AUTO_BOLUS_CARBS_APPLICATION_FACTOR_MIN
        }
        set {
            set(newValue, forKey: Key.AutoBolusCarbsApplicationFactorMin.rawValue)
        }
    }
    
    var autoBolusCarbsApplicationFactorMax: Double {
        get {
            let result = double(forKey: Key.AutoBolusCarbsApplicationFactorMin.rawValue) as Double
            return result != 0.0 ? result : Self.DEFAULT_AUTO_BOLUS_CARBS_APPLICATION_FACTOR_MAX
        }
        set {
            set(newValue, forKey: Key.AutoBolusCarbsApplicationFactorMax.rawValue)
        }
    }
    
    var carbResponsiveRetrospectiveCorrection: Bool {
        get {
            bool(forKey: Key.CarbResponsiveRetrospectiveCorrectionEnabled.rawValue) as Bool
        }
        set {
            set(newValue, forKey: Key.CarbResponsiveRetrospectiveCorrectionEnabled.rawValue)
        }
    }
    
    var glucoseMomentumReductionEnabled: Bool {
        get {
            bool(forKey: Key.GlucoseMomentumReductionEnabled.rawValue) as Bool
        }
        set {
            set(newValue, forKey: Key.GlucoseMomentumReductionEnabled.rawValue)
        }
    }
    
    var glucoseMomentumReductionEnabledWhenAsleep: Bool {
        get {
            bool(forKey: Key.GlucoseMomentumReductionEnabledWhenAsleep.rawValue) as Bool
        }
        set {
            set(newValue, forKey: Key.GlucoseMomentumReductionEnabledWhenAsleep.rawValue)
        }
    }

}
