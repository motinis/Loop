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
    
    public func register(_ quantityType: HKQuantityType) async throws {
        // Start by reading all matching data.
        var anchor: HKQueryAnchor? = nil
        var results: HKAnchoredObjectQueryDescriptor<HKQuantitySample>.Result
        
        let timeInterval =
                                                       options: .)
            HKQuery.predicateForSamplesWithStartDate(myStartDate,
                                                     endDate: myEndDate, options: .None)
         
        let explicitTimeInterval = NSPredicate(format: "%K >= %@ AND %K < %@",
                                               HKPredicateKeyPathEndDate, myStartDate,
                                               HKPredicateKeyPathStartDate, myEndDate)

        
        var sampleData = sampleDataByType[quantityType, default: []]

        var anchorDescriptor = HKAnchoredObjectQueryDescriptor(
            predicates: [.quantitySample(type: quantityType,
                                         predicate: HKQuery.predicateForSamples(withStart: Date().advanced(by: -(settings.minimumRecency + settings.detectionThreshold)), end: nil, options: .strictStartDate)],
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
            for try await update in updateQueue {
                var sampleData = sampleDataByType[quantityType, default: []]
                
                sampleData.append(contentsOf: update.addedSamples)
                sampleData.sort{($0.startDate > $1.startDate) || (($0.startDate == $1.startDate) && ($0.endDate > $1.endDate))}
                sampleData.removeLast(max(0, settings.samplesToCache - sampleData.count))
                
                sampleDataByType[quantityType] = sampleData
                
                if sampleData.isEmpty || sampleData[0].endDate.timeIntervalSinceNow > settings.minimumRecency
                    continue
                }
            
                if let threshold = settings.perMinuteThresholds[quantityType] {
                    var intervalTotal: TimeInterval = sampleData[0].endDate.timeIntervalSinceReferenceDate(sampleData[0].startDate)
                    var sampleTotal = sampleData[0]
                    
                    for (i, sample) : sampleData.enumerated() {
                        
                    }
                }
            }
        }
    }
    
    
}
