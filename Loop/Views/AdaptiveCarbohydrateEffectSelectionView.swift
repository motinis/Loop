//
//  AdaptiveCarbEffectSelectionView.swift
//  Loop
//
//  Created by Moti Nisenson-Ken on 17/01/2025.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//
import Foundation
import SwiftUI
import LoopKit
import LoopKitUI

public struct AdaptiveCarbohydrateEffectSelectionView: View {
    @Binding var isAdaptiveCarbohydrateEffectEnabled: Bool
    @Binding var isDisabledWhenBolusingCarbs: Bool
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text(NSLocalizedString("Adaptive Carbohydrate Effect", comment: "Title for adaptive carbohydrate effect experiment description"))
                    .font(.headline)
                    .padding(.bottom, 20)

                Divider()

                Text(NSLocalizedString("Adaptive Carbohydrate Effect (ACE) is an extension to the Loop Algorithm. In standard Loop, Retrospective Correction (RC) and Carb Effects are used as part of the prediction, where the retrospective takes the historical carb effects into account. In ACE, each Loop cycle the prediction from the previous cycle is compared against using RC without  carb effects. If using RC without carb effects gave a closer prediction to the current BG, then the new prediction will use it and won't include carb effects. When editing a carb entry the recommended bolus may use the usual RC and carb effects, if needed. Note that after bolusing for a carb entry, if carb effects are not being used the prediction may go beneath the correction range. The next Loop cycle the prediction will update. If not using carbs is still more accurate, then it may continue to show being beneath the correction range. When Carbs on Board (COB) is 10g or less, then ACE will not be used if the prediction without carbs is greater than the usual prediction.", comment: "Description of Integral Retrospective Correction toggle."))
                    .foregroundColor(.secondary)
                Divider()

                Toggle(NSLocalizedString("Enable Adaptive Carbohydrate Effect", comment: "Title for Adaptive Carbohydrate Effect toggle"), isOn: $isAdaptiveCarbohydrateEffectEnabled)
                    .padding(.top, 20)
                Toggle(NSLocalizedString("Disable when Manually Bolusing Carbs", comment: "Title for disable when bolusing carbs toggle"), isOn: $isDisabledWhenBolusingCarbs)
                    .padding(.top, 20)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
}

struct AdaptiveCarbEffectSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        AdaptiveCarbohydrateEffectSelectionView(isAdaptiveCarbohydrateEffectEnabled: .constant(true), isDisabledWhenBolusingCarbs: .constant(true))
    }
}

