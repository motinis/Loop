//
//  AutoBolusCarbsSelectionView.swift
//  Loop
//
//  Created by Moti Nisenson-Ken on 23/12/2024.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import Foundation
import SwiftUI
import LoopKit
import LoopKitUI

public struct AutoBolusCarbsSelectionView: View {
    @Binding var isAutoBolusCarbsEnabled: Bool
    @Binding var activeByDefault: Bool
    @Binding var thresholdPercentage: Double
    @Binding var applicationFactorMin: Double
    @Binding var applicationFactorMax: Double
    
    @State
    private var applicationFactorExamplesExpanded = false
    
    private let percentages = Array(stride(from: 0.0, through: 1.0, by: 0.1))
    
    private let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    
    public var body: some View {
        
        ScrollView {
            VStack(spacing: 10) {
                Text(NSLocalizedString("Auto-Bolus Carbs", comment: "Title for auto-bolus carbs experiment description"))
                    .font(.headline)
                    .padding(.bottom, 20)

                Divider()

                Text(String(format: NSLocalizedString("Auto-Bolus Carbs (ABC) is a modification of how Loop corrects each loop cycle. When enabled and active, Loop will check how much insulin is needed to cover existing carbs (similar to doing a manual bolus but without correcting for grucose). If this amount times the application factor is greater than the usual correction, a bolus for that amount will be given. Overrides can also be used to activate or deactivate. When ABC is enabled and active a %@ will appear beside Active Carbohydrates on the status screen.", comment: "Description of Auto-Bolus Carbs toggles."), "🔸"))
                    .foregroundColor(.secondary)
                Text(NSLocalizedString("The application factor is glucose-based. When glucose is beneath the threshold, no bolus will be given. The application factor increases linearly from the minimum at the threshold to the maximum value at the lower boundary of the correction range.", comment: "Description of Auto-Bolus Carbs GBAF"))
                    .foregroundColor(.secondary)
                Text(NSLocalizedString("The threshold percentage controls how far between the suspend threshold and the correction range the threshold is set, where 0% is the suspend threshold and 100% is the lower boundary of the correction range.", comment: "Description of Auto-Bolus Carbs threshold"))
                    .foregroundColor(.secondary)
                HStack {
                    Text(NSLocalizedString("Settings Examples", comment: "Title for Auto-Bolus Carbs Settings Examples"))
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "chevron.forward.circle")
                        .imageScale(.small)
                        .rotationEffect(.degrees(applicationFactorExamplesExpanded ? 90 : 0))
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .accessibilityElement(children: .combine)
                .onTapGesture {
                    applicationFactorExamplesExpanded.toggle()
                }
                
                if applicationFactorExamplesExpanded {
                    Text(NSLocalizedString("The examples below relate to three different automatic dosing strategies; Basal, Auto-Bolus, and Auto-Bolus with Glucose Based Partial Application (GPBA).\n", comment: "ABC example dosing strategy explanation"))
                        .foregroundColor(.secondary)

                    VStack {
                        Text("**Faster Carb Correction:** Set the Threshold Percentage to 100%, and the Application Factor Maximum above 20% for Basal and GPBA.  Set above 40% for Auto-Bolus.")// TODO how to support Markdown and localization with a comment?
                        Text("**Always Correct for Carbs:** Set the Threshold Percentage to 0%, and the Application Factor Minimum and Maximum to 20% for Basal and GPBA. Set the Application Factor Minimum and Maximum to 40% for Auto-Bolus.")
                        Text("**Always Bolus Carbs:** Set the Threshold Percentage as desired. Set the Application Factor Minimum and Maximum to 100%")
                    }.foregroundColor(.secondary)
                }

                Divider()

                Toggle(NSLocalizedString("Auto-Bolus Carbs Enabled", comment: "Title for Auto-Bolus Carbs Enabled toggle"), isOn: $isAutoBolusCarbsEnabled)
                    .padding(.top, 20)
                
                Toggle(NSLocalizedString("Auto-Bolus Carbs Active by Default", comment: "Title for Auto-Bolus Carbs Active by Default toggle"), isOn: $activeByDefault)
                    .padding(.top, 20)
                    .disabled(!isAutoBolusCarbsEnabled)

                HStack {
                    Text(NSLocalizedString("Threshold Percentage", comment: "Title for Auto-Bolus Carbs Threshold Percentage"))
                    Spacer()
                    Picker(selection: $thresholdPercentage, label: EmptyView()) {
                        ForEach(percentages, id: \.self) { factor in
                            Text(percentFormatter.string(from: factor)!)
                        }
                    }
                    .pickerStyle(.menu)
                }
                HStack {
                    Text(NSLocalizedString("Application Factor Minimum", comment: "Title for Auto-Bolus Carbs Application Factor Minimum"))
                    Spacer()
                    Picker(selection: $applicationFactorMin, label: EmptyView()) {
                        ForEach(percentages, id: \.self) { factor in
                            Text(percentFormatter.string(from: factor)!)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(thresholdPercentage >= 1.0)
                    .onChange(of: applicationFactorMin) { newValue in
                        if newValue > applicationFactorMax {
                            applicationFactorMax = newValue
                        }
                    }
                }
                HStack {
                    Text(NSLocalizedString("Application Factor Maximum", comment: "Title for Auto-Bolus Carbs Application Factor Maximum"))
                    Spacer()
                    Picker(selection: $applicationFactorMin, label: EmptyView()) {
                        ForEach(percentages, id: \.self) { factor in
                            Text(percentFormatter.string(from: factor)!)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: applicationFactorMax) { newValue in
                        if newValue < applicationFactorMin {
                            applicationFactorMin = newValue
                        }
                    }
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
}

struct AutoBolusCarbsSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        AutoBolusCarbsSelectionView(isAutoBolusCarbsEnabled: .constant(true), activeByDefault: .constant(false), thresholdPercentage: .constant(0.0),
                                    applicationFactorMin: .constant(0.2), applicationFactorMax: .constant(0.8))
    }
}
