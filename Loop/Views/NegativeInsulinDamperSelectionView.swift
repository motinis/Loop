//
//  NegativeInsulinDamperSelectionView.swift
//  Loop
//
//  Created by Moti Nisenson-Ken on 16/10/2024.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//
import Foundation
import SwiftUI
import LoopKit
import LoopKitUI

struct NegativeInsulinDamperSelectionView: View {
    @Binding var isNegativeInsulinDamperEnabled: Bool
    @Binding var isAffectedBySleepSchedule: Bool
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
                Text(NSLocalizedString("Negative Insulin Damper", comment: "Title for negative insulin damper experiment description"))
                    .font(.headline)
                    .padding(.bottom, 20)
                
                Divider()
                
                Text(NSLocalizedString("Negative Insulin Damper (NID) is used to mitigate the effects of temporarily increased insulin sensitivity. Such increases can result in spending significant times beneath target and eventually going low. Loop may erroneously predict glucose going too high, resulting in excess insulin being delivered. To counteract this, NID acts as a dynamic damper on increases to  predicted glucose. The strength of this damper is controlled by the total predicted rise in glucose due to negative insulin. The greater the amount of negative insulin, the stronger the damper and the bigger the reductions. The calculation is done with a 15 minute lag.", comment: "Description of Negative Insulin Damper toggle."))
                    .foregroundColor(.secondary)
                Text(NSLocalizedString("Damper strength may also be reduced while asleep. This option should be used if the damper is too strong when asleep resulting in extended times with glucose higher than desired.", comment: "Description of sleep schedule impact on NID toggle"))
                    .foregroundColor(.secondary)
                Divider()
                
                Toggle(NSLocalizedString("Enable Negative Insulin Damper", comment: "Title for Negative Insulin Damper toggle"), isOn: $isNegativeInsulinDamperEnabled)
                    .padding(.top, 20)
                Toggle(isOn: $isAffectedBySleepSchedule) {
                    Text(NSLocalizedString("Reduce Strength When Asleep", comment: "Title for the NID sleep schedule reduction toggle"))
                    if let sleepSchedule = sleepSchedule {
                        Text(String(format: NSLocalizedString("Sleep Schedule: %1$@ - %2$@ (%3$@)", comment: "Sleep schedule sublabel format for NID sleep schedule reduction toggle"), formatTime(sleepSchedule.start), formatTime(sleepSchedule.start + sleepSchedule.duration), numberFormatter.string(from: sleepSchedule.slowdownFactor) ?? "?"))
                    } else {
                        Text(NSLocalizedString("Sleep Schedule is Disabled", comment: "Sleep schedule disabled sublabel for NID sleep schedule reduction toggle"))
                    }
                }.disabled(!isNegativeInsulinDamperEnabled)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    struct NegativeInsulinDamperSelectionView_Previews: PreviewProvider {
        static var previews: some View {
            NegativeInsulinDamperSelectionView(isNegativeInsulinDamperEnabled: .constant(true), isAffectedBySleepSchedule: .constant(false), sleepSchedule: nil)
        }
    }
}
