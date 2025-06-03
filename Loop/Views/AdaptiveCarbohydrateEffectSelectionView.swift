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
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text(NSLocalizedString("Adaptive Carbohydrate Effect", comment: "Title for adaptive carbohydrate effect experiment description"))
                    .font(.headline)
                    .padding(.bottom, 20)

                Divider()

                Text(NSLocalizedString("Adaptive Carbohydrate Effect (ACE) is an extension to the Loop Algorithm. When enabled, ACE allows Loop to respond more dynamically to carb absorption. Each Loop cycle, it calculates the percentage of the carb effect from past meals which should be handled by Retrospective Correction (RC) for the next predicted value. This percentage decays over the next 60 minutes as usual for RC. When Carbs on Board (COB) is 10g or less, this will only be used if the resulting prediction will be less than the standard carb effect. When ACE is enabled, Floating Correction Range (FCR) is automatically applied when there are carbs on board, where the FCR adjustment is multiplied by the ACE percentage.", comment: "Description of Adaptive Carbohydrate Effect toggle."))
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
        AdaptiveCarbohydrateEffectSelectionView(isAdaptiveCarbohydrateEffectEnabled: .constant(true))
    }
}

