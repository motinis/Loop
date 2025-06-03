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
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text(NSLocalizedString("Floating Correction Range", comment: "Title for floating correction range experiment description"))
                    .font(.headline)
                    .padding(.bottom, 20)

                Divider()

                Text(NSLocalizedString("Floating Correction Range (FCR) is an extension to the Loop Algorithm. When enabled, FCR adjusts the correction range up (beyond any changes made by overrides) when glucose has increased over the previous 20 minutes. This can prevent Loop from correcting too aggressively when handling transient spikes. The adjustment is dependent on how much glucose has increased, and will not exceed 3/4 of the increase. This adjustment only applies when there are no carbs on board.", comment: "Description of Floating Correction Range toggle."))
                    .foregroundColor(.secondary)
                Divider()

                Toggle(NSLocalizedString("Enable Floating Correction Range", comment: "Title for Floating Correction Range toggle"), isOn: $isFloatingCorrectionRangeEnabled)
                    .padding(.top, 20)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FloatingCorrectionRangeSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        FloatingCorrectionRangeEnabledSelectionView(isFloatingCorrectionRangeEnabled: .constant(true))
    }
}
