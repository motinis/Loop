//
//  ExerciseDetectionSettings.swift
//  Loop
//
//  Created by Moti Nisenson-Ken on 29/03/2024.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public struct ExerciseDetectionSettings {

    public let detectionThreshold = TimeInterval(minutes: 8.0)
    
    public let minimumRecency = TimeInterval(60.0)
    public let maximumSampleGap = TimeInterval(60.0)

    public let perMinuteThresholds: [HKQuantityType : Double] = [HKQuantityType(.stepCount): 40.0, HKQuantityType(.activeEnergyBurned) : 50.0]
    
    public let samplesToCache = 10
    
}
