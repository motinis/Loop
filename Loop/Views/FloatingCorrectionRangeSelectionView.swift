//
//  FloatingCorrectionRangeSelectionView.swift
//  Loop
//
//  Created by Moti Nisenson-Ken on 02/05/2025.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//
import Foundation
import SwiftUI
import LoopKit
import LoopKitUI


public struct FloatingCorrectionRangeEnabledSelectionView: View {
    @Binding var isFloatingCorrectionRangeEnabled: Bool
    @Binding var isFloatingCorrectionRangeEnabledWhenAsleep: Bool
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
        formatter.timeZone = .gmt
        return formatter
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        timeFormatter.string(from: Date(timeIntervalSince1970: time))
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text(NSLocalizedString("Floating Correction Range", comment: "Title for floating correction range experiment description"))
                    .font(.headline)
                    .padding(.bottom, 20)

                Divider()

                Text(NSLocalizedString("Floating Correction Range (FCR) is an extension to the Loop Algorithm. When enabled, FCR adjusts the correction range up (beyond any changes made by overrides) when glucose has increased over the previous 20 minutes. This can prevent Loop from correcting too aggressively when handling transient spikes. The adjustment is dependent on how much glucose has increased, and will not exceed 3/4 of the increase. This adjustment only applies when there are no carbs on board.", comment: "Description of Floating Correction Range toggle."))
                    .foregroundColor(.secondary)
                Text(NSLocalizedString("By default, FCR does not apply when sleeping, since spikes are less likely to be transient.", comment: "Description of Floating Correction Range enabled when asleep toggle."))
                    .foregroundColor(.secondary)
                Divider()

                Toggle(NSLocalizedString("🚧 Enable Floating Correction Range", comment: "Title for Floating Correction Range toggle"), isOn: $isFloatingCorrectionRangeEnabled)
                    .padding(.top, 20)
                Toggle(isOn: $isFloatingCorrectionRangeEnabledWhenAsleep) {
                    Text(NSLocalizedString("🚧 Enable When Asleep", comment: "Title for Floating Correction Range When Asleep toggle"))
                    if let sleepSchedule = sleepSchedule {
                        Text(String(format: NSLocalizedString("Sleep Schedule: %1$@ - %2$@ (%3$@)", comment: "Sleep schedule sublabel format for FCR When Asleep toggle"), formatTime(sleepSchedule.start), formatTime(sleepSchedule.start + sleepSchedule.duration), numberFormatter.string(from: sleepSchedule.slowdownFactor) ?? "?"))
                    } else {
                        Text(NSLocalizedString("Sleep Schedule is Disabled", comment: "Sleep schedule disabled sublabel for NID sleep schedule reduction toggle"))
                    }
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FloatingCorrectionRangeSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        FloatingCorrectionRangeEnabledSelectionView(isFloatingCorrectionRangeEnabled: .constant(true), isFloatingCorrectionRangeEnabledWhenAsleep: .constant(false), sleepSchedule: nil)
    }
}
