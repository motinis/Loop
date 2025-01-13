//
//  SuperMicroBolusSelectionView.swift
//  Loop
//
//  Created by Moti Nisenson-Ken on 08/01/2025.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//
import Foundation
import SwiftUI
import LoopKit
import LoopKitUI

public struct SuperMicroBolusSelectionView: View {
    @Binding var isSuperMicroBolusSelectionEnabled: Bool
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text(NSLocalizedString("Super Micro Bolus", comment: "Title for super micro bolus experiment description"))
                    .font(.headline)
                    .padding(.bottom, 20)

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text(String(format: NSLocalizedString("Super Micro Bolus (SMB) is a modification of how Loop corrects each cycle. If Loop would not give a correction, then it may \"borrow\" future basal to give it as a bolus to get in range faster. A zero temp basal is maintained while SMB is active for 30 - 60 minutes for safety. While SMB is active %@ will appear beside Glucose on the status screen. Eventual glucose may be above range due to the long zero temp basal.", comment: "Description of Super Micro Bolus toggle."), "🔷"))
                    Text(NSLocalizedString("SMB can be given when all of the following conditions are met:", comment: "SMB eligibility conditions list"))
                    HStack(alignment: .top) {
                        Text("•")
                        Text(NSLocalizedString("Loop would not give any automatic dosing for the predicted glucose", comment: "SMB condition 1"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack(alignment: .top) {
                        Text("•")
                        Text(NSLocalizedString("Predicted glucose does not go beneath the suspend threshold", comment: "SMB condition 2"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack(alignment: .top) {
                        Text("•")
                        Text(NSLocalizedString("Predicted glucose is above range for the next 2 hours", comment: "SMB condition 3"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack(alignment: .top) {
                        Text("•")
                        Text(NSLocalizedString("Eventual glucose is above or in range", comment: "SMB condition 4"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text(NSLocalizedString("The size of the micro bolus is 15% of the correction when suspending insulin, targetting the top of the correction range, subject to the following limitations:", comment: "SMB bolus size"))
                    HStack(alignment: .top) {
                        Text("•")
                        Text(NSLocalizedString("At least 5 minutes of the current basal when starting SMB", comment: "SMB bolus limit 1"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack(alignment: .top) {
                        Text("•")
                        Text(NSLocalizedString("At most the next 30 minutes of scheduled basal (including overrides)", comment: "SMB bolus limit 2"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Divider()

                Toggle(NSLocalizedString("Enable Super Micro Bolus", comment: "Title for Super Micro Bolus toggle"), isOn: $isSuperMicroBolusSelectionEnabled)
                    .padding(.top, 20)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
}

struct SuperMicroBolusSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        SuperMicroBolusSelectionView(isSuperMicroBolusSelectionEnabled: .constant(true))
    }
}

