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

public struct CarbReactiveRestrospectiveCorrection: View {
    @Binding var isCarbReactiveRetrospectiveCorrectionEnabled: Bool
    @Binding var isFloatingCorrectionRangeWithCarbsOnBoardEnabled: Bool
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text(NSLocalizedString("Carb-Reactive Retrospective Correction", comment: "Title for carb reactive retrospective correction experiment description"))
                    .font(.headline)
                    .padding(.bottom, 20)

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text(NSLocalizedString("Carb-Reactive Retrospective Correction (CRRC) is an extension to the Loop Algorithm which allows Loop to respond more dynamically to carb absorption. The standard Retrospective Correction (RC) algorithm treats all increases to glucose to be due to carbs. CRRC evaluates an additional RC component when carb absorption exceeds twice the predicted absorption. This additional component is weighted up to 50% of RC and is combined with the regular RC component.", comment: "Description of Carb-Reactive Retrospective Correction toggle."))
                        .foregroundColor(.secondary)
                    Text(NSLocalizedString("When CRRC is enabled, Floating Correction Range (FCR) can optionally be used as well when there are carbs on board. The FCR adjustment is calculated based on the increase in glucose relative to the expectation of twice the MAR. The adjustment is then multiplied by the percentage handled by CRRC.", comment: "Description of FCR with CRRC toggle"))
                        .foregroundColor(.secondary)
                }
                Divider()

                Toggle(NSLocalizedString("🚧 Enable Carb-Reactive Retrospective Correction", comment: "Title for Carb-Reactive Retrospective Correctiont toggle"), isOn: $isCarbReactiveRetrospectiveCorrectionEnabled)
                    .padding(.top, 20)
                Toggle(NSLocalizedString("🚧 Enable Floating Correction Range for Carbs", comment: "Title for Floating Correction Range for COB toggle"), isOn: $isFloatingCorrectionRangeWithCarbsOnBoardEnabled)
                    .padding(.top, 20)
                    .disabled(!isCarbReactiveRetrospectiveCorrectionEnabled)

            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
}

struct AdaptiveCarbEffectSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        CarbReactiveRestrospectiveCorrection(isCarbReactiveRetrospectiveCorrectionEnabled: .constant(true), isFloatingCorrectionRangeWithCarbsOnBoardEnabled: .constant(false))
    }
}

