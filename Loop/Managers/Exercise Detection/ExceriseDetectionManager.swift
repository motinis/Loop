//
//  ExceriseDetectionManager.swift
//  Loop
//
//  Created by Moti Nisenson-Ken on 29/03/2024.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import HealthKit
import Foundation
import OSLog

@available(iOS 15.4, *)
public class ExceriseDetectionManager {
    private let log = OSLog(category: "ExceriseDetectionManager")
    
    private var sampleDataByType: [HKQuantityType: [HKQuantitySample]] = [:]
    
    private let hkHealthStore: HKHealthStore
    private var settings: ExerciseDetectionSettings
    private let exerciseListener: (DateInterval) async -> Void
    
    public init(hkHealthStore: HKHealthStore, settings: ExerciseDetectionSettings, exerciseListener: @escaping (DateInterval) async -> Void) {
        self.hkHealthStore = hkHealthStore
        self.settings = settings
        self.exerciseListener = exerciseListener
    }
    
    private func getDateCutoff() -> Date {
        Date().advanced(by: -(settings.minimumRecency + settings.detectionThreshold))
    }
    
    private func checkThresholdMet(intervalTotal: TimeInterval, sampleTotal: Double, perMinuteThreshold: Double) -> Bool {
        let minutes = intervalTotal.minutes
        
        guard minutes > 0 else {
            return false
        }
        
        return sampleTotal / minutes >= perMinuteThreshold
    }
    
    private func getExerciseRange(lastExerciseRange: DateInterval?, startDate: Date, endDate: Date) -> DateInterval {
        nil
    }
    
    public func register(_ quantityType: HKQuantityType) async throws {
        // Start by reading all matching data.
        var anchor: HKQueryAnchor? = nil
        var results: HKAnchoredObjectQueryDescriptor<HKQuantitySample>.Result
              
    
        var sampleData = sampleDataByType[quantityType, default: []]

        var anchorDescriptor = HKAnchoredObjectQueryDescriptor(
            predicates: [.quantitySample(type: quantityType,
                                         predicate: HKQuery.predicateForSamples(withStart: getDateCutoff(), end: nil, options: .strictEndDate))],
            anchor: anchor,
            limit: 5 * settings.samplesToCache
        )

        results = try await anchorDescriptor.result(for: hkHealthStore)
        anchor = results.newAnchor
        
        sampleData.append(contentsOf: results.addedSamples)
        sampleData.sort{($0.startDate > $1.startDate) || (($0.startDate == $1.startData) && ($0.endDate > $1.endDate))}
        sampleData.removeLast(max(0, settings.samplesToCache - sampleData.count))
            
        sampleDataByType[quantityType] = sampleData
                                    
        
        anchorDescriptor = HKAnchoredObjectQueryDescriptor( predicates: [.quantitySample(type: quantityType)], anchor: anchor)
        let updateQueue = anchorDescriptor.results(for: hkHealthStore)

        Task {
            var lastExerciseRange: DateInterval? = nil
            
            for try await update in updateQueue {
                var sampleData = sampleDataByType[quantityType, default: []]
                
                sampleData.append(contentsOf: update.addedSamples)
                sampleData.sort{($0.startDate > $1.startDate) || (($0.startDate == $1.startDate) && ($0.endDate > $1.endDate))}
                sampleData.removeLast(max(0, settings.samplesToCache - sampleData.count))
                
                while !sampleData.isEmpty() && sampleData.last!.endDate < cutoffDate {
                    sampleData.removeLast()
                }
                
                sampleDataByType[quantityType] = sampleData
                            
                if let threshold = settings.perMinuteThresholds[quantityType] {
                    var intervalTotal: TimeInterval = sampleData[0].endDate.timeIntervalSinceReferenceDate(sampleData[0].startDate)
                    var sampleTotal = sampleData[0]
                    
                    if checkThresholdMet(intervalTotal: intervalTotal, sampleTotal: sampleTotal, perMinuteThreshold: threshold) {
                        // TODO exercise range
                        continue
                    }
                    
                    for (i, sample) in sampleData.enumerated() {
                        if i == 0 {
                            continue
                        }
                        if sampleData[i-1].startDate.timeIntervalSince(sample.endDate) > settings.maximumSampleGap {
                            break
                        }
                        
                    }
                }
            }
        }
    }
    
    
}
