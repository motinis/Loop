//
//  GlucoseMomentumReductionSelectionView.swift
//  Loop
//
//  Created by Moti Nisenson-Ken on 02/05/2025.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//
import Foundation
import SwiftUI
import LoopKit
import LoopKitUI


public struct GlucoseMomentumReductionEnabledSelectionView: View {
    @Binding var isGlucoseMomentumReductionEnabled: Bool
    @Binding var isGlucoseMomentumReductionEnabledWhenAsleep: Bool
    let sleepSchedule: SleepSchedule?
    
    var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }
    
    var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        timeFormatter.string(from: Date(timeIntervalSince1970: time))
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text(NSLocalizedString("Glucose Momentum Reduction", comment: "Title for glucose momentum reduction experiment description"))
                    .font(.headline)
                    .padding(.bottom, 20)

                Divider()

                Text(NSLocalizedString("Glucose Momentum Reduction (GMR) is an extension to the Loop Algorithm. When enabled, GMR reduces glucose momentum when glucose has increased over the previous 20 minutes. This can prevent Loop from correcting too aggressively when handling transient spikes. The reduction is greater when glucose has increased more.", comment: "Description of Glucose Momentum Reduction toggle."))
                    .foregroundColor(.secondary)
                Text(NSLocalizedString("GMR may also be additionally enabled when sleeping. By default, it is not enabled since spikes are less likely to be transient when asleep.", comment: "Description of Glucose Momentum Reduction enabled when asleep toggle."))
                    .foregroundColor(.secondary)
                Divider()

                Toggle(NSLocalizedString("🚧 Enable Glucose Momentum Reduction", comment: "Title for Glucose Momentum Reduction toggle"), isOn: $isGlucoseMomentumReductionEnabled)
                    .padding(.top, 20)
                Toggle(isOn: $isGlucoseMomentumReductionEnabledWhenAsleep) {
                    Text(NSLocalizedString("🚧 Enable When Asleep", comment: "Title for Glucose Momentum Reduction When Asleep toggle"))
                    if let sleepSchedule = sleepSchedule {
                        Text(String(format: NSLocalizedString("Sleep Schedule: %1$@ - %2$@ (%3$@)", comment: "Sleep schedule sublabel format for GMR When Asleep toggle"), formatTime(sleepSchedule.start), formatTime(sleepSchedule.start + sleepSchedule.duration), numberFormatter.string(from: sleepSchedule.slowdownFactor) ?? "?"))
                    } else {
                        Text(NSLocalizedString("Sleep Schedule is Disabled", comment: "Sleep schedule disabled sublabel for GMR When Asleep toggle"))
                    }
                }.disabled(!isGlucoseMomentumReductionEnabled)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct GlucoseMomentumReductionSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        GlucoseMomentumReductionEnabledSelectionView(isGlucoseMomentumReductionEnabled: .constant(true), isGlucoseMomentumReductionEnabledWhenAsleep: .constant(false), sleepSchedule: nil)
    }
}
