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

                Text(NSLocalizedString("Adaptive Carbohydrate Effect (ACE) is an extension to the Loop Algorithm. In standard Loop, Retrospective Correction (RC) takes the historical carb effects into account. When using ACE, each Loop cycle the prediction from the previous cycle is compared against using RC without carb effects. If using RC without carb effects gave a closer prediction to the current BG, then it will be used instead (and past meals will have reduced carb effects as they are accounted for by RC). When Carbs on Board (COB) is 10g or less, then ACE will not be used if the prediction without carbs is greater than the usual prediction.", comment: "Description of Adaptive Carbohydrate Effect toggle."))
                    .foregroundColor(.secondary)
                Divider()

                Toggle(NSLocalizedString("Enable Adaptive Carbohydrate Effect", comment: "Title for Adaptive Carbohydrate Effect toggle"), isOn: $isAdaptiveCarbohydrateEffectEnabled)
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

