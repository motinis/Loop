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
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text(NSLocalizedString("Carb-Reactive Retrospective Correction", comment: "Title for carb reactive retrospective correction experiment description"))
                    .font(.headline)
                    .padding(.bottom, 20)

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text(NSLocalizedString("Carb-Reactive Retrospective Correction (CRRC) is an extension to the Loop Algorithm which allows Loop to respond more dynamically to carb absorption. When carbs are absorbed faster than predicted, Loop's standard retrospective prediction reflects the actual rate of absorption rather than the predicted, resulting in zero discrepancy. When carbs are absorbed at least twice as fast as predicted, CRRC reduces the retrospective prediction by up to half (where faster absorption results in more reduction), and additional insulin may thus be delivered sooner. This is useful when insulin needs are higher or more carbs are consumed than entered.", comment: "Description of Carb-Reactive Retrospective Correction toggle."))
                        .foregroundColor(.secondary)
                }
                Divider()

                Toggle(NSLocalizedString("🚧 Enable Carb-Reactive Retrospective Correction", comment: "Title for Carb-Reactive Retrospective Correctiont toggle"), isOn: $isCarbReactiveRetrospectiveCorrectionEnabled)
                    .padding(.top, 20)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
}

struct AdaptiveCarbEffectSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        CarbReactiveRestrospectiveCorrection(isCarbReactiveRetrospectiveCorrectionEnabled: .constant(true))
    }
}

