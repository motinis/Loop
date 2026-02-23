//
//  LoopDataManagerDosingTests.swift
//  LoopTests
//
//  Created by Anna Quinlan on 10/19/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
import LoopKit
@testable import LoopCore
@testable import Loop

class MockDelegate: LoopDataManagerDelegate {
    let pumpManager = MockPumpManager()
    
    var bolusUnits: Double?
    func loopDataManager(_ manager: Loop.LoopDataManager, estimateBolusDuration units: Double) -> TimeInterval? {
        self.bolusUnits = units
        return pumpManager.estimatedDuration(toBolus: units)
    }
    
    var recommendation: AutomaticDoseRecommendation?
    var error: LoopError?
    func loopDataManager(_ manager: LoopDataManager, didRecommend automaticDose: (recommendation: AutomaticDoseRecommendation, date: Date), completion: @escaping (LoopError?) -> Void) {
        self.recommendation = automaticDose.recommendation
        completion(error)
    }
    func roundBasalRate(unitsPerHour: Double) -> Double { Double(Int(unitsPerHour / 0.05)) * 0.05 }
    func roundBolusVolume(units: Double) -> Double { Double(Int(units / 0.05)) * 0.05 }
    var pumpManagerStatus: PumpManagerStatus?
    var cgmManagerStatus: CGMManagerStatus?
    var pumpStatusHighlight: DeviceStatusHighlight?
}

class LoopDataManagerDosingTests: LoopDataManagerTests {
    // MARK: Functions to load fixtures
    func loadLocalDateGlucoseEffect(_ name: String) -> [GlucoseEffect] {
        let fixture: [JSONDictionary] = loadFixture(name)
        let localDateFormatter = ISO8601DateFormatter.localTimeDate()

        return fixture.map {
            return GlucoseEffect(startDate: localDateFormatter.date(from: $0["date"] as! String)!, quantity: HKQuantity(unit: HKUnit(from: $0["unit"] as! String), doubleValue:$0["amount"] as! Double))
        }
    }

    func loadPredictedGlucoseFixture(_ name: String) -> [PredictedGlucoseValue] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let url = bundle.url(forResource: name, withExtension: "json")!
        return try! decoder.decode([PredictedGlucoseValue].self, from: try! Data(contentsOf: url))
    }
    
    func testGlucoseMomentumReduction() {        
        let glucose = SimpleGlucoseValue(startDate: Date(), quantity: HKQuantity(unit: .mgdL, doubleValue: 100))
        let prevGlucoseDate = glucose.startDate.addingTimeInterval(.minutes(-20))
        
        // out of date range:
        XCTAssertEqual(0.0, LoopDataManager.calculateGlucoseMomentumReduction(glucose, HistoricalGlucoseValue(startDate: glucose.startDate.addingTimeInterval(.minutes(-22)), quantity: HKQuantity(unit: .mgdL, doubleValue: 0.0))))
        XCTAssertEqual(0.0, LoopDataManager.calculateGlucoseMomentumReduction(glucose, HistoricalGlucoseValue(startDate: glucose.startDate.addingTimeInterval(.minutes(-18)), quantity: HKQuantity(unit: .mgdL, doubleValue: 0.0))))
        
        // prevGlucose was higher than glucose
        XCTAssertEqual(0.0, LoopDataManager.calculateGlucoseMomentumReduction(glucose, HistoricalGlucoseValue(startDate: prevGlucoseDate, quantity: HKQuantity(unit: .mgdL, doubleValue: 101.0))))

        
        for i in 0...30 {
            let delta = Double(i)
            let prevGlucose = HistoricalGlucoseValue(startDate: prevGlucoseDate, quantity: HKQuantity(unit: .mgdL, doubleValue: 100.0 - delta))

            XCTAssertEqual(-delta * delta / 80.0, LoopDataManager.calculateGlucoseMomentumReduction(glucose, prevGlucose), accuracy: 1E-6)
        }
        
        for i in 31...50 {
            let delta = Double(i)
            let prevGlucose = HistoricalGlucoseValue(startDate: prevGlucoseDate, quantity: HKQuantity(unit: .mgdL, doubleValue: 100.0 - delta))

            XCTAssertEqual( 11.25 - 3 * delta / 4.0, LoopDataManager.calculateGlucoseMomentumReduction(glucose, prevGlucose), accuracy: 1E-6)
        }
    }
    
    func testNegativeInsulinDamper() {
        let marginalSlope = 0.05
        let anchorAlpha = 0.75
        let anchorPoint = 50.0

        XCTAssertEqual(1.0, LoopDataManager.calculateNegativeInsulinDamperAlpha(anchorAlpha, anchorPoint, marginalSlope, 0))

        XCTAssertEqual(anchorAlpha, LoopDataManager.calculateNegativeInsulinDamperAlpha(anchorAlpha, anchorPoint, marginalSlope, anchorPoint), accuracy: 1E-6)
        
        let linearScaleSlope = (1 - anchorAlpha)/anchorPoint
        let transitionPoint = (1 - marginalSlope) / (2 * linearScaleSlope)
        let transitionValue = (1 - linearScaleSlope * transitionPoint) * transitionPoint
        
        XCTAssertEqual(marginalSlope, LoopDataManager.calculateNegativeInsulinDamperAlpha(anchorAlpha, anchorPoint, marginalSlope, 1E12), accuracy: 1E-6)
        
        var prevAlpha = 1.1
        for i in 0...1_000_000 {
            let iVal = Double(i)
            let alpha = LoopDataManager.calculateNegativeInsulinDamperAlpha(anchorAlpha, anchorPoint, marginalSlope, iVal)
            
            XCTAssertLessThan(alpha, prevAlpha)
            XCTAssertGreaterThan(alpha, marginalSlope)
            
            if Double(i) <= transitionPoint {
                XCTAssertEqual(alpha, 1.0 - iVal * linearScaleSlope, accuracy: 1E-6)
            } else {
                XCTAssertEqual(alpha * iVal, transitionValue + marginalSlope * (iVal - transitionPoint), accuracy: 1E-6)
            }
            prevAlpha = alpha
        }
    }

    // MARK: Tests
    // SKIPPED: Live Capture Input Data Isn't Relevant After Other Fixes
    func skip_testForecastFromLiveCaptureInputData() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let url = bundle.url(forResource: "live_capture_input", withExtension: "json")!
        let predictionInput = try! decoder.decode(LoopPredictionInput.self, from: try! Data(contentsOf: url))

        // Therapy settings in the "live capture" input only have one value, so we can fake some schedules
        // from the first entry of each therapy setting's history.
        let basalRateSchedule = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: 0, value: predictionInput.settings.basal.first!.value)
        ])
        let insulinSensitivitySchedule = InsulinSensitivitySchedule(
            unit: .milligramsPerDeciliter,
            dailyItems: [
                RepeatingScheduleValue(startTime: 0, value: predictionInput.settings.sensitivity.first!.value.doubleValue(for: .milligramsPerDeciliter))
            ],
            timeZone: .utcTimeZone
        )!
        let carbRatioSchedule = CarbRatioSchedule(
            unit: .gram(),
            dailyItems: [
                RepeatingScheduleValue(startTime: 0.0, value: predictionInput.settings.carbRatio.first!.value)
            ],
            timeZone: .utcTimeZone
        )!

        let settings = LoopSettings(
            dosingEnabled: false,
            glucoseTargetRangeSchedule: glucoseTargetRangeSchedule,
            insulinSensitivitySchedule: insulinSensitivitySchedule,
            basalRateSchedule: basalRateSchedule,
            carbRatioSchedule: carbRatioSchedule,
            maximumBasalRatePerHour: 10,
            maximumBolus: 5,
            suspendThreshold: predictionInput.settings.suspendThreshold,
            automaticDosingStrategy: .automaticBolus
        )

        let glucoseStore = MockGlucoseStore()
        glucoseStore.storedGlucose = predictionInput.glucoseHistory

        let currentDate = glucoseStore.latestGlucose!.startDate
        now = currentDate

        let doseStore = MockDoseStore()
        doseStore.basalProfile = basalRateSchedule
        doseStore.basalProfileApplyingOverrideHistory = doseStore.basalProfile
        doseStore.sensitivitySchedule = insulinSensitivitySchedule
        doseStore.doseHistory = predictionInput.doses
        doseStore.lastAddedPumpData = predictionInput.doses.last!.startDate
        let carbStore = MockCarbStore()
        carbStore.insulinSensitivityScheduleApplyingOverrideHistory = insulinSensitivitySchedule
        carbStore.carbRatioSchedule = carbRatioSchedule
        carbStore.carbRatioScheduleApplyingOverrideHistory = carbRatioSchedule
        carbStore.carbHistory = predictionInput.carbEntries


        dosingDecisionStore = MockDosingDecisionStore()
        automaticDosingStatus = AutomaticDosingStatus(automaticDosingEnabled: true, isAutomaticDosingAllowed: true)
        loopDataManager = LoopDataManager(
            lastLoopCompleted: currentDate,
            basalDeliveryState: .active(currentDate),
            settings: settings,
            overrideHistory: TemporaryScheduleOverrideHistory(),
            analyticsServicesManager: AnalyticsServicesManager(),
            localCacheDuration: .days(1),
            doseStore: doseStore,
            glucoseStore: glucoseStore,
            carbStore: carbStore,
            dosingDecisionStore: dosingDecisionStore,
            latestStoredSettingsProvider: MockLatestStoredSettingsProvider(),
            now: { currentDate },
            pumpInsulinType: .novolog,
            automaticDosingStatus: automaticDosingStatus,
            trustedTimeOffset: { 0 }
        )

        let expectedPredictedGlucose = loadPredictedGlucoseFixture("live_capture_predicted_glucose")

        let updateGroup = DispatchGroup()
        updateGroup.enter()
        var predictedGlucose: [PredictedGlucoseValue]?
        var recommendedBasal: TempBasalRecommendation?
        self.loopDataManager.getLoopState { _, state in
            predictedGlucose = state.predictedGlucoseIncludingPendingInsulin
            recommendedBasal = state.recommendedAutomaticDose?.recommendation.basalAdjustment
            updateGroup.leave()
        }
        // We need to wait until the task completes to get outputs
        updateGroup.wait()

        XCTAssertNotNil(predictedGlucose)

        XCTAssertEqual(expectedPredictedGlucose.count, predictedGlucose!.count)

        for (expected, calculated) in zip(expectedPredictedGlucose, predictedGlucose!) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: .milligramsPerDeciliter), calculated.quantity.doubleValue(for: .milligramsPerDeciliter), accuracy: defaultAccuracy)
        }
    }
    
    func testFlatAndStable() {
        setUp(for: .flatAndStable)
        let predictedGlucoseOutput = loadLocalDateGlucoseEffect("flat_and_stable_predicted_glucose")

        let updateGroup = DispatchGroup()
        updateGroup.enter()
        var predictedGlucose: [PredictedGlucoseValue]?
        var recommendedDose: AutomaticDoseRecommendation?
        self.loopDataManager.getLoopState { _, state in
            predictedGlucose = state.predictedGlucose
            recommendedDose = state.recommendedAutomaticDose?.recommendation
            updateGroup.leave()
        }
        // We need to wait until the task completes to get outputs
        updateGroup.wait()

        XCTAssertNotNil(predictedGlucose)
        XCTAssertEqual(predictedGlucoseOutput.count, predictedGlucose!.count)
        
        for (expected, calculated) in zip(predictedGlucoseOutput, predictedGlucose!) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: .milligramsPerDeciliter), calculated.quantity.doubleValue(for: .milligramsPerDeciliter), accuracy: defaultAccuracy)
        }
        
        let recommendedTempBasal = recommendedDose?.basalAdjustment

        XCTAssertEqual(1.40, recommendedTempBasal!.unitsPerHour, accuracy: defaultAccuracy)
    }
    
    func getDosageRatioForHighAndStable() -> Double {
        // ISF schedule switches at 09:00, dose is given at ~5:39.
        // This means that 36.39/45 of a unit dose is given at ISF 45, and then the remainder is at 55
        let weight = 36.393359243966223 / 45.0
        return weight + (1 - weight) * 45.0 / 55
    }
    
    func getDosageForHighAndStableTempBasal(_ value: Double) -> Double {
        // the scheduled basal is 1 U/hr, therefore this part should not be adjusted
        return 1.0 + getDosageRatioForHighAndStable() * (value - 1.0)
    }
    
    func testHighAndStable() {
        setUp(for: .highAndStable)
        let predictedGlucoseOutput = loadLocalDateGlucoseEffect("high_and_stable_predicted_glucose")

        let updateGroup = DispatchGroup()
        updateGroup.enter()
        var predictedGlucose: [PredictedGlucoseValue]?
        var recommendedBasal: TempBasalRecommendation?
        self.loopDataManager.getLoopState { _, state in
            predictedGlucose = state.predictedGlucose
            recommendedBasal = state.recommendedAutomaticDose?.recommendation.basalAdjustment
            updateGroup.leave()
        }
        // We need to wait until the task completes to get outputs
        updateGroup.wait()

        XCTAssertNotNil(predictedGlucose)
        XCTAssertEqual(predictedGlucoseOutput.count, predictedGlucose!.count)
        
        for (expected, calculated) in zip(predictedGlucoseOutput, predictedGlucose!) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: .milligramsPerDeciliter), calculated.quantity.doubleValue(for: .milligramsPerDeciliter), accuracy: defaultAccuracy)
        }
        
        // ISF changes from

        XCTAssertEqual(getDosageForHighAndStableTempBasal(4.63), recommendedBasal!.unitsPerHour, accuracy: defaultAccuracy)
    }
    
    func testCarbResponsiveRetrospectiveCorrectionActive() {
        let step = 0.01
        for i in 1...10 {
            // use different cobValues so it's easier to see in messages which test failed
            let j = Double(i)
            
            // note that expectedRelativeAbsorption is copied out from debugging LoopDataManager; it is very sensitive to the parameters and data used in the tests
            
            doTestCarbResponsiveRetrospectiveCorrectionActive(cobValue: j + 1 * step, carbFactor: 1.5, absorptionFactor: 3, expectedRelativeAbsorption: 2.46)
            doTestCarbResponsiveRetrospectiveCorrectionActive(cobValue: j + 2 * step, carbFactor: 1.5, absorptionFactor: 4, expectedRelativeAbsorption: 3.95)
            doTestCarbResponsiveRetrospectiveCorrectionActive(cobValue: j + 3 * step, carbFactor: 1.5, absorptionFactor: 6, expectedRelativeAbsorption: 8.8)
            doTestCarbResponsiveRetrospectiveCorrectionActive(cobValue: j + 4 * step, carbFactor: 1.5, absorptionFactor: 8, expectedRelativeAbsorption: 15.64)
            
            doTestCarbResponsiveRetrospectiveCorrectionActive(cobValue: j + 11 * step, carbFactor: 2, absorptionFactor: 3, expectedRelativeAbsorption: 2.96)
            doTestCarbResponsiveRetrospectiveCorrectionActive(cobValue: j + 12 * step, carbFactor: 2, absorptionFactor: 4, expectedRelativeAbsorption: 5.21)
            doTestCarbResponsiveRetrospectiveCorrectionActive(cobValue: j + 13 * step, carbFactor: 2, absorptionFactor: 6, expectedRelativeAbsorption: 11.73)
            doTestCarbResponsiveRetrospectiveCorrectionActive(cobValue: j + 14 * step, carbFactor: 2, absorptionFactor: 8, expectedRelativeAbsorption: 20.85)
            
            doTestCarbResponsiveRetrospectiveCorrectionActive(cobValue: j + 21 * step, carbFactor: 2.5, absorptionFactor: 3, expectedRelativeAbsorption: 3.67)
            doTestCarbResponsiveRetrospectiveCorrectionActive(cobValue: j + 22 * step, carbFactor: 2.5, absorptionFactor: 4, expectedRelativeAbsorption: 6.52)
            doTestCarbResponsiveRetrospectiveCorrectionActive(cobValue: j + 23 * step, carbFactor: 2.5, absorptionFactor: 6, expectedRelativeAbsorption: 14.66)
            doTestCarbResponsiveRetrospectiveCorrectionActive(cobValue: j + 24 * step, carbFactor: 2.5, absorptionFactor: 8, expectedRelativeAbsorption: 26.06)

        }
    }
    
    func doTestCarbResponsiveRetrospectiveCorrectionActive(cobValue: Double, carbFactor: Double, absorptionFactor: Double, expectedRelativeAbsorption: Double) {
        // simulate small and very slow acting carbs which just "activated" when the retrospective begins.
        // this scenario does have ICE, however the carb effect will be significantly less, resulting in CRRC being active
                        
        // Without CRRC, approximately 2.85 grams are absorbed during the RC interval (although it is necessary to use time >= 35 minutes in absorptionTime calculation;
        // This seems likely to be due to a boundary condition, where using e.g. 30 minutes instead results in the absorption rate not being small enough).
        // by multiplying carbs by carbFactor and extending the absorption time by carbFactor * absorptionFactor / 1.5, the MAR becomes 1/absorptionFactor smaller.
        // In practical terms, MAR isn't actually used, since piecewise linear absorption is. But this just gives us a reasonable values to ensure CRRC is active.
        let rcCarbs = 2.85
        let carbs = carbFactor * rcCarbs
        let absorptionTime : TimeInterval = .minutes(35) * carbFactor * absorptionFactor / CarbMath.defaultAbsorptionTimeOverrun
                
        setUp(for: .highAndFalling, predictCarbGlucoseEffects: true, doseHistorySupplier: { _ in [DoseEntry]() },
              carbHistorySupplier: {[StoredCarbEntry(startDate: $0.addingTimeInterval(.minutes(-40)), quantity: HKQuantity(unit: .gram(), doubleValue: carbs), absorptionTime: absorptionTime)]}, carbsOnBoardSupplier: {CarbValue(startDate: $0, value: cobValue)}, carbResponsiveRetrospectiveCorrectionEnabled: true)
        
        let updateGroup = DispatchGroup()
        updateGroup.enter()
        var totalRetrospectiveCorrection: HKQuantity?
        var predTotal: Double?
        var standardTotalRC: Double?
            
        let retrospectiveStart = self.now.addingTimeInterval(.minutes(-30))
        
        self.loopDataManager.getLoopState { _, state in
            self.carbStore.getGlucoseEffects(start: retrospectiveStart, end: self.now.addingTimeInterval(.minutes(0)), effectVelocities: state.insulinCounteractionEffects.filter {$0.endDate <= retrospectiveStart}) { (result) -> Void in
                switch result {
                case .failure(_):
                    predTotal = nil
                case .success(let (_, effects)):
                    let crrcCarbEffect = LoopDataManager.calculateCarbResponsiveRCCarbEffect(effects)
                    predTotal = state.insulinCounteractionEffects.subtracting(crrcCarbEffect, withUniformInterval: self.carbStore.delta).map{ $0.quantity.doubleValue(for: .mgdL)}.reduce(0.0, +)
                }
            }
            
            self.carbStore.getGlucoseEffects(start: retrospectiveStart, end: self.now.addingTimeInterval(.minutes(0)), effectVelocities: state.insulinCounteractionEffects) { (result) -> Void in
                switch result {
                case .failure(_):
                    standardTotalRC = nil
                case .success(let (_, effects)):
                    standardTotalRC = state.insulinCounteractionEffects.subtracting(effects, withUniformInterval: self.carbStore.delta).map{ $0.quantity.doubleValue(for: .mgdL)}.reduce(0.0, +)
                }
            }

            totalRetrospectiveCorrection = state.totalRetrospectiveCorrection
            updateGroup.leave()
        }
        // We need to wait until the task completes to get outputs
        updateGroup.wait()

        XCTAssertNotNil(standardTotalRC)
        XCTAssertNotNil(predTotal)
        
        let expectedWeight = min(LoopDataManager.CRRC_MAX_WEIGHT, LoopDataManager.calculateCRRCWeight(cobValue) * 1/sqrt(2 * expectedRelativeAbsorption))
        let expectedRC = (1 - expectedWeight) * standardTotalRC! + expectedWeight * predTotal!

        XCTAssertNotNil(totalRetrospectiveCorrection)
        XCTAssertEqual((totalRetrospectiveCorrection!.doubleValue(for: .mgdL) - expectedRC)/expectedRC, 0.0, accuracy: 0.01, "Tested with cobValue \(cobValue)")
    }
    
    func testBeneathRangeForAutoBolusCarbs() {
        // this scenario starts beneath the correction range
        setUp(for: .highAndRisingWithCOB, correctionRanges: correctionRange(150.0), autoBolusCarbs: true)
        let updateGroup = DispatchGroup()
        updateGroup.enter()
        var recommendedBolus: Double?
        var manualBolusRecommendation: ManualBolusRecommendation?
        self.loopDataManager.getLoopState { _, state in
            recommendedBolus = state.recommendedAutomaticDose?.recommendation.bolusUnits
            manualBolusRecommendation = try? state.recommendBolus(consideringPotentialCarbEntry: nil, replacingCarbEntry: nil, considerPositiveVelocityAndRC: FeatureFlags.usePositiveMomentumAndRCForManualBoluses)
            updateGroup.leave()
        }
        // We need to wait until the task completes to get outputs
        updateGroup.wait()
        
        XCTAssertNotNil(recommendedBolus)
        XCTAssertEqual(min(manualBolusRecommendation!.amount, manualBolusRecommendation!.bolusBreakdown!.cobCorrectionAmount), recommendedBolus!, accuracy: defaultAccuracy)
    }
    
    func testBeneathRangeForAutoBolusCarbsWithGBPA() {
        // this scenario starts beneath the correction range
        setUp(for: .highAndRisingWithCOB, correctionRanges: correctionRange(150.0), autoBolusCarbs: true)
        UserDefaults.standard.autoBolusCarbsThresholdPercentage = (100.0 - 75) / (150.0 - 75) // set the effective threshold to 100
        UserDefaults.standard.autoBolusCarbsApplicationFactorMin = 0.2
        UserDefaults.standard.autoBolusCarbsApplicationFactorMax = 0.8
        
        let expectedApplicationFactor = 0.2 + (129.93174411197853 - 100.0) / (150.0 - 100) * (0.8 - 0.2)
        
        let updateGroup = DispatchGroup()
        updateGroup.enter()
        var recommendedBolus: Double?
        var manualBolusRecommendation: ManualBolusRecommendation?
        self.loopDataManager.getLoopState { _, state in
            recommendedBolus = state.recommendedAutomaticDose?.recommendation.bolusUnits
            manualBolusRecommendation = try? state.recommendBolus(consideringPotentialCarbEntry: nil, replacingCarbEntry: nil, considerPositiveVelocityAndRC: FeatureFlags.usePositiveMomentumAndRCForManualBoluses)
            updateGroup.leave()
        }
        // We need to wait until the task completes to get outputs
        updateGroup.wait()
        
        XCTAssertNotNil(recommendedBolus)
        XCTAssertEqual(expectedApplicationFactor * min(manualBolusRecommendation!.amount, manualBolusRecommendation!.bolusBreakdown!.cobCorrectionAmount), recommendedBolus!, accuracy: defaultAccuracy)
    }

    
    func testBeneathRangeForAutoBolusCarbsBeneathThreshold() {
        // this scenario starts beneath the correction range
        setUp(for: .highAndRisingWithCOB, correctionRanges: correctionRange(150.0), autoBolusCarbs: true)
        UserDefaults.standard.autoBolusCarbsThresholdPercentage = (130.0 - 75) / (150.0 - 75) // set the effective threshold to 130
        
        let updateGroup = DispatchGroup()
        updateGroup.enter()
        var recommendation: AutomaticDoseRecommendation?
        self.loopDataManager.getLoopState { _, state in
            recommendation = state.recommendedAutomaticDose?.recommendation
            updateGroup.leave()
        }
        // We need to wait until the task completes to get outputs
        updateGroup.wait()
        
        XCTAssertNotNil(recommendation)
        XCTAssertNil(recommendation!.basalAdjustment)
        XCTAssertNil(recommendation!.bolusUnits)
    }

    
    func testBeneathRangeForAutoBolusCarbsAutoIobMax() {
        // this scenario starts beneath the correction range
        // autoIobMax = 2*maxBolus and mockDoseStore has IOB of 9.5 - so headroom is 0.1
        setUp(for: .highAndRisingWithCOB, maxBolus: 4.8, correctionRanges: correctionRange(150.0), autoBolusCarbs: true)
        let updateGroup = DispatchGroup()
        updateGroup.enter()
        var recommendedBolus: Double?
        self.loopDataManager.getLoopState { _, state in
            recommendedBolus = state.recommendedAutomaticDose?.recommendation.bolusUnits
            updateGroup.leave()
        }
        // We need to wait until the task completes to get outputs
        updateGroup.wait()
        
        XCTAssertNotNil(recommendedBolus)
        XCTAssertEqual(0.1, recommendedBolus!, accuracy: defaultAccuracy)
    }
    
    func testHighAndStableWithAutoBolusCarbsForAutoBolusResult() {
        // note that the default setup for .highAndStable has a _carb_effect file reflecting a 5g carb effect (with 45 ISF)
        // predicted glucose starts from 200 and goes down to 176.21882841682697 (taking into account _insulin_effect)
        let isf = 45.0
        let cir = 10.0
        
        let expectedBgCorrectionAmount = 1.82 + (200 - 176.21882841682697) / isf // COB correction is to 200. BG correction is the rest
        
        // 0.4*(cobCorrection + bgCorrection) will be the dosage compared against
        // for this test we want cobCorrection < 0.4*(cobCorrection + bgCorrection)
        // in other words we need cobCorrection < 2/3 * bgCorrection
        let expectedCobCorrectionAmount = 0.6 * expectedBgCorrectionAmount
        
        let carbValue = 5.0 + cir * ((200 - 176.21882841682697) / isf + expectedCobCorrectionAmount)
        
        setUp(for: .highAndStable, dosingStrategy: .automaticBolus, predictCarbGlucoseEffects: true,
              carbHistorySupplier: {[StoredCarbEntry(startDate: $0, quantity: HKQuantity(unit: .gram(), doubleValue: carbValue))]}, autoBolusCarbs: true)
        
        let updateGroup = DispatchGroup()
        updateGroup.enter()
        var recommendedBolus: Double?
        self.loopDataManager.getLoopState { _, state in
            recommendedBolus = state.recommendedAutomaticDose?.recommendation.bolusUnits
            updateGroup.leave()
        }
        // We need to wait until the task completes to get outputs
        updateGroup.wait()

        XCTAssertNotNil(recommendedBolus)
        XCTAssertEqual(getDosageRatioForHighAndStable() * 0.4 * (expectedCobCorrectionAmount + expectedBgCorrectionAmount), recommendedBolus!, accuracy: defaultAccuracy)
    }
    
    func testHighAndStableWithAutoBolusCarbsForABCResultVsAutoBolus() {
        // note that the default setup for .highAndStable has a _carb_effect file reflecting a 5g carb effect (with 45 ISF)
        // predicted glucose starts from 200 and goes down to 176.21882841682697 (taking into account _insulin_effect)
        let isf = 45.0
        let cir = 10.0
        
        let expectedBgCorrectionAmount = 1.82 + (200 - 176.21882841682697) / isf // COB correction is to 200. BG correction is the rest
        
        // 0.4*(cobCorrection + bgCorrection) will be the dosage compared against
        // for this test we want cobCorrection > 0.4*(cobCorrection + bgCorrection)
        // in other words we need cobCorrection > 2/3 * bgCorrection
        let expectedCobCorrectionAmount = 0.7 * expectedBgCorrectionAmount
        
        let carbValue = 5.0 + cir * ((200 - 176.21882841682697) / isf + expectedCobCorrectionAmount)
        
        setUp(for: .highAndStable, dosingStrategy: .automaticBolus, predictCarbGlucoseEffects: true,
              carbHistorySupplier: {[StoredCarbEntry(startDate: $0, quantity: HKQuantity(unit: .gram(), doubleValue: carbValue))]}, autoBolusCarbs: true)
        
        let updateGroup = DispatchGroup()
        updateGroup.enter()
        var recommendedBolus: Double?
        self.loopDataManager.getLoopState { _, state in
            recommendedBolus = state.recommendedAutomaticDose?.recommendation.bolusUnits
            updateGroup.leave()
        }
        // We need to wait until the task completes to get outputs
        updateGroup.wait()

        XCTAssertNotNil(recommendedBolus)
        XCTAssertEqual(getDosageRatioForHighAndStable() * expectedCobCorrectionAmount, recommendedBolus!, accuracy: defaultAccuracy)
    }
    
    func testHighAndStableWithAutoBolusCarbsForABCResultVsAutoBolusWithMaxFactor() {
        // note that the default setup for .highAndStable has a _carb_effect file reflecting a 5g carb effect (with 45 ISF)
        // predicted glucose starts from 200 and goes down to 176.21882841682697 (taking into account _insulin_effect)
        let isf = 45.0
        let cir = 10.0
        
        let expectedBgCorrectionAmount = 1.82 + (200 - 176.21882841682697) / isf // COB correction is to 200. BG correction is the rest
        
        let maxFactor = 0.8
        
        // 0.4*(cobCorrection + bgCorrection) will be the dosage compared against
        // for this test we want maxFactor * cobCorrection > 0.4*(cobCorrection + bgCorrection)
        // in other words we need cobCorrection > bgCorrection / (maxFactor/0.4 - 1)
        let expectedCobCorrectionAmount = 1.1 * expectedBgCorrectionAmount / (maxFactor / 0.4 - 1)
        
        let carbValue = 5.0 + cir * ((200 - 176.21882841682697) / isf + expectedCobCorrectionAmount)
        
        setUp(for: .highAndStable, dosingStrategy: .automaticBolus, predictCarbGlucoseEffects: true,
              carbHistorySupplier: {[StoredCarbEntry(startDate: $0, quantity: HKQuantity(unit: .gram(), doubleValue: carbValue))]}, autoBolusCarbs: true)
        
        UserDefaults.standard.autoBolusCarbsApplicationFactorMin = 0.0
        UserDefaults.standard.autoBolusCarbsApplicationFactorMax = maxFactor
        
        let updateGroup = DispatchGroup()
        updateGroup.enter()
        var recommendedBolus: Double?
        self.loopDataManager.getLoopState { _, state in
            recommendedBolus = state.recommendedAutomaticDose?.recommendation.bolusUnits
            updateGroup.leave()
        }
        // We need to wait until the task completes to get outputs
        updateGroup.wait()

        XCTAssertNotNil(recommendedBolus)
        XCTAssertEqual(getDosageRatioForHighAndStable() * maxFactor * expectedCobCorrectionAmount, recommendedBolus!, accuracy: defaultAccuracy)
    }
    
    func testHighAndStableWithAutoBolusCarbsForTempBasalResult() {
        // note that the default setup for .highAndStable has a _carb_effect file reflecting a 5g carb effect (with 45 ISF)
        // predicted glucose starts from 200 and goes down to 176.21882841682697 (taking into account _insulin_effect)
        let isf = 45.0
        let cir = 10.0
        
        let expectedBgCorrectionAmount = 1.82 + (200 - 176.21882841682697) / isf // COB correction is to 200. BG correction is the rest
        
        // (cobCorrection + bgCorrection)/6 will be the dosage compared against
        // for this test we want cobCorrection < (cobCorrection + bgCorrection)/6
        // in other words we need cobCorrection < bgCorrection / 5
        let expectedCobCorrectionAmount = expectedBgCorrectionAmount / 6
        
        let carbValue = 5.0 + cir * ((200 - 176.21882841682697) / isf + expectedCobCorrectionAmount)
        
        setUp(for: .highAndStable, maxBasalRate: 7.0, predictCarbGlucoseEffects: true,
              carbHistorySupplier: {[StoredCarbEntry(startDate: $0, quantity: HKQuantity(unit: .gram(), doubleValue: carbValue))]}, autoBolusCarbs: true)
        
        let updateGroup = DispatchGroup()
        updateGroup.enter()
        var recommendedBasal: TempBasalRecommendation?
        self.loopDataManager.getLoopState { _, state in
            recommendedBasal = state.recommendedAutomaticDose?.recommendation.basalAdjustment
            updateGroup.leave()
        }
        // We need to wait until the task completes to get outputs
        updateGroup.wait()

        // unadjusted basal rate is 1.0
        XCTAssertEqual(getDosageForHighAndStableTempBasal(1.0 + 2*(expectedBgCorrectionAmount + expectedCobCorrectionAmount)), recommendedBasal!.unitsPerHour, accuracy: defaultAccuracy)
    }
    
    func testHighAndStableWithAutoBolusCarbsForABCResultvsTempBasal() {
        // note that the default setup for .highAndStable has a _carb_effect file reflecting a 5g carb effect (with 45 ISF)
        // predicted glucose starts from 200 and goes down to 176.21882841682697 (taking into account _insulin_effect)
        let isf = 45.0
        let cir = 10.0
        
        let expectedBgCorrectionAmount = 1.82 + (200 - 176.21882841682697) / isf // COB correction is to 200. BG correction is the rest
        
        // (cobCorrection + bgCorrection)/6 will be the dosage compared against
        // for this test we want cobCorrection > (cobCorrection + bgCorrection)/6
        // in other words we need cobCorrection > bgCorrection / 5
        let expectedCobCorrectionAmount = expectedBgCorrectionAmount / 4

        let carbValue = 5.0 + cir * ((200 - 176.21882841682697) / isf + expectedCobCorrectionAmount)
        
        setUp(for: .highAndStable, predictCarbGlucoseEffects: true,
              carbHistorySupplier: {[StoredCarbEntry(startDate: $0, quantity: HKQuantity(unit: .gram(), doubleValue: carbValue))]}, autoBolusCarbs: true)
        
        let updateGroup = DispatchGroup()
        updateGroup.enter()
        var recommendedBolus: Double?
        self.loopDataManager.getLoopState { _, state in
            recommendedBolus = state.recommendedAutomaticDose?.recommendation.bolusUnits
            updateGroup.leave()
        }
        // We need to wait until the task completes to get outputs
        updateGroup.wait()

        XCTAssertNotNil(recommendedBolus)
        XCTAssertEqual(getDosageRatioForHighAndStable() * expectedCobCorrectionAmount, recommendedBolus!, accuracy: defaultAccuracy)
    }
    
    func testHighAndFalling() {
        setUp(for: .highAndFalling)
        let predictedGlucoseOutput = loadLocalDateGlucoseEffect("high_and_falling_predicted_glucose")

        let updateGroup = DispatchGroup()
        updateGroup.enter()
        var predictedGlucose: [PredictedGlucoseValue]?
        var recommendedTempBasal: TempBasalRecommendation?
        self.loopDataManager.getLoopState { _, state in
            predictedGlucose = state.predictedGlucose
            recommendedTempBasal = state.recommendedAutomaticDose?.recommendation.basalAdjustment
            updateGroup.leave()
        }
        // We need to wait until the task completes to get outputs
        updateGroup.wait()

        XCTAssertNotNil(predictedGlucose)
        XCTAssertEqual(predictedGlucoseOutput.count, predictedGlucose!.count)
        
        for (expected, calculated) in zip(predictedGlucoseOutput, predictedGlucose!) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: .milligramsPerDeciliter), calculated.quantity.doubleValue(for: .milligramsPerDeciliter), accuracy: defaultAccuracy)
        }

        XCTAssertEqual(0, recommendedTempBasal!.unitsPerHour, accuracy: defaultAccuracy)
    }
    
    func testHighAndRisingWithCOB() {
        setUp(for: .highAndRisingWithCOB)
        let predictedGlucoseOutput = loadLocalDateGlucoseEffect("high_and_rising_with_cob_predicted_glucose")

        let updateGroup = DispatchGroup()
        updateGroup.enter()
        var predictedGlucose: [PredictedGlucoseValue]?
        var recommendedBolus: ManualBolusRecommendation?
        self.loopDataManager.getLoopState { _, state in
            predictedGlucose = state.predictedGlucose
            recommendedBolus = try? state.recommendBolus(consideringPotentialCarbEntry: nil, replacingCarbEntry: nil, considerPositiveVelocityAndRC: true)
            updateGroup.leave()
        }
        // We need to wait until the task completes to get outputs
        updateGroup.wait()

        XCTAssertNotNil(predictedGlucose)
        XCTAssertEqual(predictedGlucoseOutput.count, predictedGlucose!.count)
        
        for (expected, calculated) in zip(predictedGlucoseOutput, predictedGlucose!) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: .milligramsPerDeciliter), calculated.quantity.doubleValue(for: .milligramsPerDeciliter), accuracy: defaultAccuracy)
        }

        XCTAssertEqual(1.6, recommendedBolus!.amount, accuracy: defaultAccuracy)
    }
    
    func testLowAndFallingWithCOB() {
        setUp(for: .lowAndFallingWithCOB)
        let predictedGlucoseOutput = loadLocalDateGlucoseEffect("low_and_falling_predicted_glucose")

        let updateGroup = DispatchGroup()
        updateGroup.enter()
        var predictedGlucose: [PredictedGlucoseValue]?
        var recommendedTempBasal: TempBasalRecommendation?
        self.loopDataManager.getLoopState { _, state in
            predictedGlucose = state.predictedGlucose
            recommendedTempBasal = state.recommendedAutomaticDose?.recommendation.basalAdjustment
            updateGroup.leave()
        }
        // We need to wait until the task completes to get outputs
        updateGroup.wait()

        XCTAssertNotNil(predictedGlucose)
        XCTAssertEqual(predictedGlucoseOutput.count, predictedGlucose!.count)
        
        for (expected, calculated) in zip(predictedGlucoseOutput, predictedGlucose!) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: .milligramsPerDeciliter), calculated.quantity.doubleValue(for: .milligramsPerDeciliter), accuracy: defaultAccuracy)
        }

        XCTAssertEqual(0, recommendedTempBasal!.unitsPerHour, accuracy: defaultAccuracy)
    }
    
    func testLowWithLowTreatment() {
        setUp(for: .lowWithLowTreatment)
        let predictedGlucoseOutput = loadLocalDateGlucoseEffect("low_with_low_treatment_predicted_glucose")

        let updateGroup = DispatchGroup()
        updateGroup.enter()
        var predictedGlucose: [PredictedGlucoseValue]?
        var recommendedTempBasal: TempBasalRecommendation?
        self.loopDataManager.getLoopState { _, state in
            predictedGlucose = state.predictedGlucose
            recommendedTempBasal = state.recommendedAutomaticDose?.recommendation.basalAdjustment
            updateGroup.leave()
        }
        // We need to wait until the task completes to get outputs
        updateGroup.wait()

        XCTAssertNotNil(predictedGlucose)
        XCTAssertEqual(predictedGlucoseOutput.count, predictedGlucose!.count)
        
        for (expected, calculated) in zip(predictedGlucoseOutput, predictedGlucose!) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: .milligramsPerDeciliter), calculated.quantity.doubleValue(for: .milligramsPerDeciliter), accuracy: defaultAccuracy)
        }

        XCTAssertEqual(0, recommendedTempBasal!.unitsPerHour, accuracy: defaultAccuracy)
    }

    func waitOnDataQueue(timeout: TimeInterval = 1.0) {
        let e = expectation(description: "dataQueue")
        loopDataManager.getLoopState { _, _ in
            e.fulfill()
        }
        wait(for: [e], timeout: timeout)
    }
    
    func testValidateMaxTempBasalDoesntCancelTempBasalIfHigher() {
        let dose = DoseEntry(type: .tempBasal, startDate: Date(), endDate: nil, value: 3.0, unit: .unitsPerHour, deliveredUnits: nil, description: nil, syncIdentifier: nil, scheduledBasalRate: nil)
        setUp(for: .highAndStable, basalDeliveryState: .tempBasal(dose))
        // This wait is working around the issue presented by LoopDataManager.init().  It cancels the temp basal if
        // `isClosedLoop` is false (which it is from `setUp` above). When that happens, it races with
        // `maxTempBasalSavePreflight` below.  This ensures only one happens at a time.
        waitOnDataQueue()
        let delegate = MockDelegate()
        loopDataManager.delegate = delegate
        var error: Error?
        let exp = expectation(description: #function)
        XCTAssertNil(delegate.recommendation)
        loopDataManager.maxTempBasalSavePreflight(unitsPerHour: 5.0) {
            error = $0
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
        XCTAssertNil(error)
        XCTAssertNil(delegate.recommendation)
        XCTAssertTrue(dosingDecisionStore.dosingDecisions.isEmpty)
    }
    
    func testValidateMaxTempBasalCancelsTempBasalIfLower() {
        let dose = DoseEntry(type: .tempBasal, startDate: Date(), endDate: nil, value: 5.0, unit: .unitsPerHour, deliveredUnits: nil, description: nil, syncIdentifier: nil, scheduledBasalRate: nil)
        setUp(for: .highAndStable, basalDeliveryState: .tempBasal(dose))
        // This wait is working around the issue presented by LoopDataManager.init().  It cancels the temp basal if
        // `isClosedLoop` is false (which it is from `setUp` above). When that happens, it races with
        // `maxTempBasalSavePreflight` below.  This ensures only one happens at a time.
        waitOnDataQueue()
        let delegate = MockDelegate()
        loopDataManager.delegate = delegate
        var error: Error?
        let exp = expectation(description: #function)
        XCTAssertNil(delegate.recommendation)
        loopDataManager.maxTempBasalSavePreflight(unitsPerHour: 3.0) {
            error = $0
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
        XCTAssertNil(error)
        XCTAssertEqual(delegate.recommendation, AutomaticDoseRecommendation(basalAdjustment: .cancel))
        XCTAssertEqual(dosingDecisionStore.dosingDecisions.count, 1)
        XCTAssertEqual(dosingDecisionStore.dosingDecisions[0].reason, "maximumBasalRateChanged")
        XCTAssertEqual(dosingDecisionStore.dosingDecisions[0].automaticDoseRecommendation, AutomaticDoseRecommendation(basalAdjustment: .cancel))
    }
    
    func testChangingMaxBasalUpdatesLoopData() {
        setUp(for: .highAndStable)
        waitOnDataQueue()
        var loopDataUpdated = false
        let exp = expectation(description: #function)
        let observer = NotificationCenter.default.addObserver(forName: .LoopDataUpdated, object: nil, queue: nil) { _ in
            loopDataUpdated = true
            exp.fulfill()
        }
        XCTAssertFalse(loopDataUpdated)
        loopDataManager.mutateSettings { $0.maximumBasalRatePerHour = 2.0 }
        wait(for: [exp], timeout: 1.0)
        XCTAssertTrue(loopDataUpdated)
        NotificationCenter.default.removeObserver(observer)
    }

    func testOpenLoopCancelsTempBasal() {
        let dose = DoseEntry(type: .tempBasal, startDate: Date(), value: 1.0, unit: .unitsPerHour)
        setUp(for: .highAndStable, basalDeliveryState: .tempBasal(dose))
        waitOnDataQueue()
        let delegate = MockDelegate()
        loopDataManager.delegate = delegate
        let exp = expectation(description: #function)
        let observer = NotificationCenter.default.addObserver(forName: .LoopDataUpdated, object: nil, queue: nil) { _ in
            exp.fulfill()
        }
        automaticDosingStatus.automaticDosingEnabled = false
        wait(for: [exp], timeout: 1.0)
        let expectedAutomaticDoseRecommendation = AutomaticDoseRecommendation(basalAdjustment: .cancel)
        XCTAssertEqual(delegate.recommendation, expectedAutomaticDoseRecommendation)
        XCTAssertEqual(dosingDecisionStore.dosingDecisions.count, 1)
        XCTAssertEqual(dosingDecisionStore.dosingDecisions[0].reason, "automaticDosingDisabled")
        XCTAssertEqual(dosingDecisionStore.dosingDecisions[0].automaticDoseRecommendation, expectedAutomaticDoseRecommendation)
        NotificationCenter.default.removeObserver(observer)
    }

    func testReceivedUnreliableCGMReadingCancelsTempBasal() {
        let dose = DoseEntry(type: .tempBasal, startDate: Date(), value: 5.0, unit: .unitsPerHour)
        setUp(for: .highAndStable, basalDeliveryState: .tempBasal(dose))
        waitOnDataQueue()
        let delegate = MockDelegate()
        loopDataManager.delegate = delegate
        let exp = expectation(description: #function)
        let observer = NotificationCenter.default.addObserver(forName: .LoopDataUpdated, object: nil, queue: nil) { _ in
            exp.fulfill()
        }
        loopDataManager.receivedUnreliableCGMReading()
        wait(for: [exp], timeout: 1.0)
        let expectedAutomaticDoseRecommendation = AutomaticDoseRecommendation(basalAdjustment: .cancel)
        XCTAssertEqual(delegate.recommendation, expectedAutomaticDoseRecommendation)
        XCTAssertEqual(dosingDecisionStore.dosingDecisions.count, 1)
        XCTAssertEqual(dosingDecisionStore.dosingDecisions[0].reason, "unreliableCGMData")
        XCTAssertEqual(dosingDecisionStore.dosingDecisions[0].automaticDoseRecommendation, expectedAutomaticDoseRecommendation)
        NotificationCenter.default.removeObserver(observer)
    }

    func testLoopEnactsTempBasalWithoutManualBolusRecommendation() {
        setUp(for: .highAndStable)
        waitOnDataQueue()
        let delegate = MockDelegate()
        loopDataManager.delegate = delegate
        let exp = expectation(description: #function)
        let observer = NotificationCenter.default.addObserver(forName: .LoopCompleted, object: nil, queue: nil) { _ in
            exp.fulfill()
        }
        loopDataManager.loop()
        wait(for: [exp], timeout: 1.0)
        let expectedAutomaticDoseRecommendation = AutomaticDoseRecommendation(basalAdjustment: TempBasalRecommendation(unitsPerHour: delegate.roundBasalRate(unitsPerHour: getDosageForHighAndStableTempBasal(4.57)), duration: .minutes(30)))
        XCTAssertEqual(delegate.recommendation, expectedAutomaticDoseRecommendation)
        XCTAssertEqual(dosingDecisionStore.dosingDecisions.count, 1)
        if dosingDecisionStore.dosingDecisions.count == 1 {
            XCTAssertEqual(dosingDecisionStore.dosingDecisions[0].reason, "loop")
            XCTAssertEqual(dosingDecisionStore.dosingDecisions[0].automaticDoseRecommendation, expectedAutomaticDoseRecommendation)
            XCTAssertNil(dosingDecisionStore.dosingDecisions[0].manualBolusRecommendation)
            XCTAssertNil(dosingDecisionStore.dosingDecisions[0].manualBolusRequested)
        }
        NotificationCenter.default.removeObserver(observer)
    }

    func testLoopRecommendsTempBasalWithoutEnactingIfOpenLoop() {
        setUp(for: .highAndStable)
        automaticDosingStatus.automaticDosingEnabled = false
        waitOnDataQueue()
        let delegate = MockDelegate()
        loopDataManager.delegate = delegate
        let exp = expectation(description: #function)
        let observer = NotificationCenter.default.addObserver(forName: .LoopCompleted, object: nil, queue: nil) { _ in
            exp.fulfill()
        }
        loopDataManager.loop()
        wait(for: [exp], timeout: 1.0)
        let expectedAutomaticDoseRecommendation = AutomaticDoseRecommendation(basalAdjustment: TempBasalRecommendation(unitsPerHour: delegate.roundBasalRate( unitsPerHour: getDosageForHighAndStableTempBasal(4.57)), duration: .minutes(30)))
        XCTAssertNil(delegate.recommendation)
        XCTAssertEqual(dosingDecisionStore.dosingDecisions.count, 1)
        XCTAssertEqual(dosingDecisionStore.dosingDecisions[0].reason, "loop")
        XCTAssertEqual(dosingDecisionStore.dosingDecisions[0].automaticDoseRecommendation, expectedAutomaticDoseRecommendation)
        XCTAssertNil(dosingDecisionStore.dosingDecisions[0].manualBolusRecommendation)
        XCTAssertNil(dosingDecisionStore.dosingDecisions[0].manualBolusRequested)
        NotificationCenter.default.removeObserver(observer)
    }
    
    func dummyReplacementEntry() -> StoredCarbEntry{
        StoredCarbEntry(startDate: now, quantity: HKQuantity(unit: .gram(), doubleValue: -1))
    }
    
    func dummyCarbEntry() -> NewCarbEntry {
        NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 1E-50), startDate: now.addingTimeInterval(TimeInterval(days: -2)),
                     foodType: nil, absorptionTime: TimeInterval(hours: 3))
    }
    
    func correctionRange(_ value: Double) -> GlucoseRangeSchedule {
        correctionRange(value, value)
    }

    func correctionRange(_ minValue: Double, _ maxValue: Double) -> GlucoseRangeSchedule {
        GlucoseRangeSchedule(unit: HKUnit.milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue(startTime: TimeInterval(0), value: DoubleRange(minValue: minValue, maxValue: maxValue))])!
    }

    func testLoopGetStateRecommendsManualBolus() {
        setUp(for: .flatAndStable, correctionRanges: correctionRange(106.26136802382213 - 1.82 * 55), suspendThresholdValue: 0.0)
        let exp = expectation(description: #function)
        var recommendedBolus: ManualBolusRecommendation?
        loopDataManager.getLoopState { (_, loopState) in
            recommendedBolus = try? loopState.recommendBolus(consideringPotentialCarbEntry: nil, replacingCarbEntry: nil, considerPositiveVelocityAndRC: true)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 100000.0)
        XCTAssertEqual(recommendedBolus!.amount, 1.82, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.bgCorrectionAmount, 1.82, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.cobCorrectionAmount, 0, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.carbsAmount!, 0, accuracy: 0.01)
        XCTAssertNil(recommendedBolus!.missingAmount)
    }
    
    func testLoopGetStateRecommendsManualBolusMaxBolusClamping() {
        setUp(for: .flatAndStable, maxBolus: 1, correctionRanges: correctionRange(106.26136802382213 - 1.82 * 55), suspendThresholdValue: 0.0)
        let exp = expectation(description: #function)
        var recommendedBolus: ManualBolusRecommendation?
        loopDataManager.getLoopState { (_, loopState) in
            recommendedBolus = try? loopState.recommendBolus(consideringPotentialCarbEntry: nil, replacingCarbEntry: nil, considerPositiveVelocityAndRC: true)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 100000.0)
        XCTAssertEqual(recommendedBolus!.amount, 1, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.bgCorrectionAmount, 1.82, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.cobCorrectionAmount, 0, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.carbsAmount!, 0, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.missingAmount!, 0.82, accuracy: 0.01)
    }
        
    func testLoopGetStateRecommendsManualBolusForCob() {
        // note that the default setup for .highAndStable has a _carb_effect file reflecting a 5g carb effect (with 45 ISF)
        // predicted glucose starts from 200 and goes down to 176.21882841682697 (taking into account _insulin_effect)
        let isf = 45.0
        let cir = 10.0

        let expectedCobCorrectionAmount = 0.5
        let expectedBgCorrectionAmount = 1.82 + (200 - 176.21882841682697) / isf // COB correction is to 200. BG correction is the rest
        
        let carbValue = 5.0 + cir * ((200 - 176.21882841682697) / isf + expectedCobCorrectionAmount)
        
        setUp(for: .highAndStable, predictCarbGlucoseEffects: true,
              carbHistorySupplier: {[StoredCarbEntry(startDate: $0, quantity: HKQuantity(unit: .gram(), doubleValue: carbValue))]})
                
        let exp = expectation(description: #function)
        
        var recommendedBolus: ManualBolusRecommendation?

        loopDataManager.mutateSettings { settings in settings.insulinSensitivitySchedule = InsulinSensitivitySchedule(
            unit: .milligramsPerDeciliter,
            dailyItems: [RepeatingScheduleValue(startTime: 0, value: isf)],
            timeZone: .utcTimeZone
        )!}
        loopDataManager.getLoopState { (_, loopState) in
            recommendedBolus = try? loopState.recommendBolus(consideringPotentialCarbEntry: self.dummyCarbEntry(), replacingCarbEntry: self.dummyReplacementEntry(), considerPositiveVelocityAndRC: false)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 100000.0)
        XCTAssertEqual(recommendedBolus!.amount, expectedBgCorrectionAmount + expectedCobCorrectionAmount, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.bgCorrectionAmount, expectedBgCorrectionAmount, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.cobCorrectionAmount, expectedCobCorrectionAmount, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.carbsAmount!, 0, accuracy: 0.01)
        XCTAssertNil(recommendedBolus!.missingAmount)
    }
    
    func testLoopGetStateRecommendsManualBolusForCobAndReducingCarbEntry() {
        // note that the default setup for .highAndStable has a _carb_effect file reflecting a 5g carb effect (with 45 ISF)
        // predicted glucose starts from 200 and goes down to 176.21882841682697 (taking into account _insulin_effect)
        let isf = 45.0
        let cir = 10.0

        let expectedCobCorrectionAmount = 0.6
        let expectedBgCorrectionAmount = 1.82 + (200 - 176.21882841682697) / isf // COB correction is to 200. BG correction is the rest
        let expectedCarbsAmount = 0.5
        
        let carbValue = 5.0 + cir * ((200 - 176.21882841682697) / isf + expectedCobCorrectionAmount)
        
        setUp(for: .highAndStable, predictCarbGlucoseEffects: true,
              carbHistorySupplier: {[
                StoredCarbEntry(startDate: $0, quantity: HKQuantity(unit: .gram(), doubleValue: carbValue)),
                StoredCarbEntry(startDate: $0, quantity: HKQuantity(unit: .gram(), doubleValue: 10))
              ]})
        
        loopDataManager.mutateSettings { settings in settings.insulinSensitivitySchedule = InsulinSensitivitySchedule(
            unit: .milligramsPerDeciliter,
            dailyItems: [RepeatingScheduleValue(startTime: 0, value: isf)],
            timeZone: .utcTimeZone
        )!}
                
        let exp = expectation(description: #function)
        
        let carbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: expectedCarbsAmount * cir), startDate: now, foodType: nil, absorptionTime: TimeInterval(hours: 1))
        
        var recommendedBolus: ManualBolusRecommendation?

        loopDataManager.getLoopState { (_, loopState) in
            
            recommendedBolus = try? loopState.recommendBolus(consideringPotentialCarbEntry: carbEntry, replacingCarbEntry: StoredCarbEntry(startDate: self.now, quantity: HKQuantity(unit: .gram(), doubleValue: 10)), considerPositiveVelocityAndRC: false)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 100000.0)
        XCTAssertEqual(recommendedBolus!.amount, (expectedCarbsAmount + expectedBgCorrectionAmount + expectedCobCorrectionAmount), accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.bgCorrectionAmount, expectedBgCorrectionAmount, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.cobCorrectionAmount, expectedCobCorrectionAmount, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.carbsAmount!, expectedCarbsAmount, accuracy: 0.01)
        XCTAssertNil(recommendedBolus!.missingAmount)
    }
    
    func testLoopGetStateRecommendsManualBolusForZeroCorrectionCobAndCarbEntry() {
        // note that the default setup for .highAndStable has a _carb_effect file reflecting a 5g carb effect (with 45 ISF)
        // predicted glucose starts from 200 and goes down to 176.21882841682697 (taking into account _insulin_effect)
        let isf = 45.0
        let cir = 10.0

        let expectedCobCorrectionAmount = 0.0
        let expectedCarbsAmount = 0.5
        let expectedBgOffset = -0.2
        let expectedBgCorrectionAmount = 1.82 + (200 - 176.21882841682697) / isf + expectedBgOffset
        
        
        let carbValue = 5.0 + cir * ((200 - 176.21882841682697) / isf + expectedBgOffset)
        
        setUp(for: .highAndStable, predictCarbGlucoseEffects: true,
              carbHistorySupplier: {[
                StoredCarbEntry(startDate: $0, quantity: HKQuantity(unit: .gram(), doubleValue: carbValue))
              ]})
                
        let exp = expectation(description: #function)
        
        let carbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: expectedCarbsAmount * cir), startDate: now, foodType: nil, absorptionTime: TimeInterval(hours: 1))
        
        var recommendedBolus: ManualBolusRecommendation?

        loopDataManager.getLoopState { (_, loopState) in
            
            recommendedBolus = try? loopState.recommendBolus(consideringPotentialCarbEntry: carbEntry, replacingCarbEntry: self.dummyReplacementEntry(), considerPositiveVelocityAndRC: false)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 100000.0)
        XCTAssertEqual(recommendedBolus!.amount, getDosageRatioForHighAndStable() * (expectedCarbsAmount + expectedBgCorrectionAmount + expectedCobCorrectionAmount), accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.bgCorrectionAmount, getDosageRatioForHighAndStable() * expectedBgCorrectionAmount, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.cobCorrectionAmount, expectedCobCorrectionAmount, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.carbsAmount!, getDosageRatioForHighAndStable() * expectedCarbsAmount, accuracy: 0.01)
        XCTAssertNil(recommendedBolus!.missingAmount)
    }
    
    func testLoopGetStateRecommendsManualBolusForCarbEntry() {
        setUp(for: .highAndStable, predictCarbGlucoseEffects: true)
        let exp = expectation(description: #function)
        
        var recommendedBolus: ManualBolusRecommendation?

        let carbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 5.0), startDate: now, foodType: nil, absorptionTime: TimeInterval(hours: 1.0))
        loopDataManager.getLoopState { (_, loopState) in
            recommendedBolus = try? loopState.recommendBolus(consideringPotentialCarbEntry: carbEntry, replacingCarbEntry: nil, considerPositiveVelocityAndRC: false)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 100000.0)
        XCTAssertEqual(recommendedBolus!.amount, getDosageRatioForHighAndStable() * 2.32, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.bgCorrectionAmount, getDosageRatioForHighAndStable() * 1.82, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.cobCorrectionAmount, 0, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.carbsAmount!, getDosageRatioForHighAndStable() * 0.5, accuracy: 0.01)
        XCTAssertNil(recommendedBolus!.missingAmount)
    }
    
    func testLoopGetStateRecommendsManualBolusForCarbEntryMaxBolusClamping() {
        setUp(for: .highAndStable, maxBolus: 1, predictCarbGlucoseEffects: true)
        let exp = expectation(description: #function)
        
        var recommendedBolus: ManualBolusRecommendation?

        let carbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 5.0), startDate: now, foodType: nil, absorptionTime: TimeInterval(hours: 1.0))
        loopDataManager.getLoopState { (_, loopState) in
            recommendedBolus = try? loopState.recommendBolus(consideringPotentialCarbEntry: carbEntry, replacingCarbEntry: nil, considerPositiveVelocityAndRC: false)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 100000.0)
        XCTAssertEqual(recommendedBolus!.amount, 1, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.bgCorrectionAmount, getDosageRatioForHighAndStable() * 1.82, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.cobCorrectionAmount, 0, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.carbsAmount!, getDosageRatioForHighAndStable() * 0.5, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.missingAmount!, getDosageRatioForHighAndStable() * 2.32 - 1, accuracy: 0.01)
    }
    
    func testLoopGetStateRecommendsManualBolusForBeneathRange() {
        setUp(for: .flatAndStable, correctionRanges: correctionRange(160))
        
        let exp = expectation(description: #function)
        var recommendedBolus: ManualBolusRecommendation?
        loopDataManager.getLoopState { (_, loopState) in
            recommendedBolus = try? loopState.recommendBolus(consideringPotentialCarbEntry: nil, replacingCarbEntry: nil, considerPositiveVelocityAndRC: true)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 100000.0)
        XCTAssertEqual(recommendedBolus!.amount, 0, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.bgCorrectionAmount, (106.21882841682697 - 160) / 55, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.cobCorrectionAmount, 0, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.carbsAmount!, 0, accuracy: 0.01)
        XCTAssertNil(recommendedBolus!.missingAmount)
    }
    
    func testLoopGetStateRecommendsManualBolusForInRangeAboveMidPoint() {
        setUp(for: .flatAndStable, correctionRanges: correctionRange(80, 110))
        
        let exp = expectation(description: #function)
        var recommendedBolus: ManualBolusRecommendation?
        loopDataManager.getLoopState { (_, loopState) in
            recommendedBolus = try? loopState.recommendBolus(consideringPotentialCarbEntry: nil, replacingCarbEntry: nil, considerPositiveVelocityAndRC: true)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 100000.0)
        XCTAssertEqual(recommendedBolus!.amount, 0, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.bgCorrectionAmount, 0, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.cobCorrectionAmount, 0, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.carbsAmount!, 0, accuracy: 0.01)
        XCTAssertNil(recommendedBolus!.missingAmount)
    }
    
    func testLoopGetStateRecommendsManualBolusForSuspendForCarbEntry() {
        setUp(for: .highAndStable, predictCarbGlucoseEffects: true, correctionRanges: correctionRange(230), suspendThresholdValue: 220)
        
        let exp = expectation(description: #function)
        var recommendedBolus: ManualBolusRecommendation?

        let carbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 15.0), startDate: now, foodType: nil, absorptionTime: TimeInterval(hours: 1.0))
        loopDataManager.getLoopState { (_, loopState) in
            recommendedBolus = try? loopState.recommendBolus(consideringPotentialCarbEntry: carbEntry, replacingCarbEntry: nil, considerPositiveVelocityAndRC: false)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 100000.0)
        XCTAssertEqual(recommendedBolus!.amount, 0, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.bgCorrectionAmount, getDosageRatioForHighAndStable() * (176.21882841682697 - 230) / 45, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.cobCorrectionAmount, 0, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.carbsAmount!, getDosageRatioForHighAndStable() * 1.5, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.missingAmount!, getDosageRatioForHighAndStable() * (1.5 + (176.21882841682697 - 230) / 45), accuracy: 0.01)
    }
    
    func testLoopGetStateRecommendsManualBolusForBigAndSlowCarbEntry() {
        setUp(for: .highAndStable, predictCarbGlucoseEffects: true, correctionRanges: correctionRange(176.2188), suspendThresholdValue: 176.218)
        
        let exp = expectation(description: #function)
        var recommendedBolus: ManualBolusRecommendation?

        let carbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 100.0), startDate: now, foodType: nil, absorptionTime: TimeInterval(hours: 4.0))
        loopDataManager.getLoopState { (_, loopState) in
            recommendedBolus = try? loopState.recommendBolus(consideringPotentialCarbEntry: carbEntry, replacingCarbEntry: nil, considerPositiveVelocityAndRC: false)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 100000.0)
        XCTAssertEqual(recommendedBolus!.amount, getDosageRatioForHighAndStable() * 7.27, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.bgCorrectionAmount, 0, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.cobCorrectionAmount, 0, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.carbsAmount!, getDosageRatioForHighAndStable() * 9.99, accuracy: 0.01) // 9.99 and not 10 since there is 10 minute delay, leaving 0.01 remaining
        XCTAssertEqual(recommendedBolus!.missingAmount!, getDosageRatioForHighAndStable() * (9.99 - 7.27), accuracy: 0.01)
    }

    
    func testLoopGetStateRecommendsManualBolusNoMissingForSuspendForCarbEntry() {
        setUp(for: .highAndStable, predictCarbGlucoseEffects: true, correctionRanges: correctionRange(230), suspendThresholdValue: 220)
        
        let exp = expectation(description: #function)
        var recommendedBolus: ManualBolusRecommendation?

        let carbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 5.0), startDate: now, foodType: nil, absorptionTime: TimeInterval(hours: 1.0))
        loopDataManager.getLoopState { (_, loopState) in
            recommendedBolus = try? loopState.recommendBolus(consideringPotentialCarbEntry: carbEntry, replacingCarbEntry: nil, considerPositiveVelocityAndRC: false)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 100000.0)
        XCTAssertEqual(recommendedBolus!.amount, 0, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.bgCorrectionAmount, getDosageRatioForHighAndStable() * (176.21882841682697 - 230) / 45, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.cobCorrectionAmount, 0, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.carbsAmount!, getDosageRatioForHighAndStable() * 0.5, accuracy: 0.01)
        XCTAssertNil(recommendedBolus!.missingAmount) // carbsAmount + bgCorrectionAmount < 0, so nothing is missing
    }
    
    func testLoopGetStateRecommendsManualBolusForSuspendNoCarbEntry() {
        setUp(for: .highAndStable, predictCarbGlucoseEffects: true, correctionRanges: correctionRange(230), suspendThresholdValue: 180)
        
        let exp = expectation(description: #function)
        var recommendedBolus: ManualBolusRecommendation?

        let carbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 5.0), startDate: now, foodType: nil, absorptionTime: TimeInterval(hours: 1.0))
        loopDataManager.getLoopState { (_, loopState) in
            recommendedBolus = try? loopState.recommendBolus(consideringPotentialCarbEntry: nil, replacingCarbEntry: nil, considerPositiveVelocityAndRC: false)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 100000.0)
        XCTAssertEqual(recommendedBolus!.amount, 0, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.bgCorrectionAmount, getDosageRatioForHighAndStable() * (176.21882841682697 - 230) / 45, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.cobCorrectionAmount, 0, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus!.bolusBreakdown!.carbsAmount!, 0.0, accuracy: 0.01)
        XCTAssertNil(recommendedBolus!.missingAmount)
    }
    
    func testLoopGetStateRecommendsManualBolusForInRangeCarbEntry() {
        setUp(for: .highAndStable, predictCarbGlucoseEffects: true, correctionRanges: correctionRange(170, 210))
                        
        let exp1 = expectation(description: #function)
        var recommendedBolus1: ManualBolusRecommendation?
        
        let exp2 = expectation(description: #function)
        var recommendedBolus2: ManualBolusRecommendation?

        // note that 176.218 + 5/10*45 < 210
        let carbEntry1 = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 5), startDate: now, foodType: nil, absorptionTime: TimeInterval(hours: 1.0))
        loopDataManager.getLoopState { (_, loopState) in
            recommendedBolus1 = try? loopState.recommendBolus(consideringPotentialCarbEntry: carbEntry1, replacingCarbEntry: nil, considerPositiveVelocityAndRC: false)
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: 100000.0)

        let carbEntry2 = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 4.8), startDate: now, foodType: nil, absorptionTime: TimeInterval(hours: 1.0))
        loopDataManager.getLoopState { (_, loopState) in
            recommendedBolus2 = try? loopState.recommendBolus(consideringPotentialCarbEntry: carbEntry2, replacingCarbEntry: nil, considerPositiveVelocityAndRC: false)
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 100000.0)

                
        XCTAssertEqual(recommendedBolus1!.amount, 0, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus1!.bolusBreakdown!.bgCorrectionAmount, getDosageRatioForHighAndStable() * -0.5, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus1!.bolusBreakdown!.cobCorrectionAmount, 0, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus1!.bolusBreakdown!.carbsAmount!, getDosageRatioForHighAndStable() * 0.5, accuracy: 0.01)
        XCTAssertNil(recommendedBolus1!.missingAmount)
        
        XCTAssertEqual(recommendedBolus2!.amount, 0, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus2!.bolusBreakdown!.bgCorrectionAmount, getDosageRatioForHighAndStable() * -0.48, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus2!.bolusBreakdown!.cobCorrectionAmount, 0, accuracy: 0.01)
        XCTAssertEqual(recommendedBolus2!.bolusBreakdown!.carbsAmount!, getDosageRatioForHighAndStable() * 0.48, accuracy: 0.01)
        XCTAssertNil(recommendedBolus2!.missingAmount)
    }

    func testLoopGetStateRecommendsManualBolusWithMomentum() {
        setUp(for: .highAndRisingWithCOB)
        let exp = expectation(description: #function)
        var recommendedBolus: ManualBolusRecommendation?
        loopDataManager.getLoopState { (_, loopState) in
            recommendedBolus = try? loopState.recommendBolus(consideringPotentialCarbEntry: nil, replacingCarbEntry: nil, considerPositiveVelocityAndRC: true)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(recommendedBolus!.amount, 1.62, accuracy: 0.01)
    }

    func testLoopGetStateRecommendsManualBolusWithoutMomentum() {
        setUp(for: .highAndRisingWithCOB)
        let exp = expectation(description: #function)
        var recommendedBolus: ManualBolusRecommendation?
        loopDataManager.getLoopState { (_, loopState) in
            recommendedBolus = try? loopState.recommendBolus(consideringPotentialCarbEntry: nil, replacingCarbEntry: nil, considerPositiveVelocityAndRC: false)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(recommendedBolus!.amount, 1.52, accuracy: 0.01)
    }

    func testIsClosedLoopAvoidsTriggeringTempBasalCancelOnCreation() {
        let settings = LoopSettings(
            dosingEnabled: false,
            glucoseTargetRangeSchedule: glucoseTargetRangeSchedule,
            maximumBasalRatePerHour: 5,
            maximumBolus: 10,
            suspendThreshold: suspendThreshold
        )

        let doseStore = MockDoseStore()
        let glucoseStore = MockGlucoseStore(for: .flatAndStable)
        let carbStore = MockCarbStore()

        let currentDate = Date()

        dosingDecisionStore = MockDosingDecisionStore()
        automaticDosingStatus = AutomaticDosingStatus(automaticDosingEnabled: false, isAutomaticDosingAllowed: true)
        let existingTempBasal = DoseEntry(
            type: .tempBasal,
            startDate: currentDate.addingTimeInterval(-.minutes(2)),
            endDate: currentDate.addingTimeInterval(.minutes(28)),
            value: 1.0,
            unit: .unitsPerHour,
            deliveredUnits: nil,
            description: "Mock Temp Basal",
            syncIdentifier: "asdf",
            scheduledBasalRate: nil,
            insulinType: .novolog,
            automatic: true,
            manuallyEntered: false,
            isMutable: true)
        loopDataManager = LoopDataManager(
            lastLoopCompleted: currentDate.addingTimeInterval(-.minutes(5)),
            basalDeliveryState: .tempBasal(existingTempBasal),
            settings: settings,
            overrideHistory: TemporaryScheduleOverrideHistory(),
            analyticsServicesManager: AnalyticsServicesManager(),
            localCacheDuration: .days(1),
            doseStore: doseStore,
            glucoseStore: glucoseStore,
            carbStore: carbStore,
            dosingDecisionStore: dosingDecisionStore,
            latestStoredSettingsProvider: MockLatestStoredSettingsProvider(),
            now: { currentDate },
            pumpInsulinType: .novolog,
            automaticDosingStatus: automaticDosingStatus,
            trustedTimeOffset: { 0 }
        )
        let mockDelegate = MockDelegate()
        loopDataManager.delegate = mockDelegate

        // Dose enacting happens asynchronously, as does receiving isClosedLoop signals
        waitOnMain(timeout: 5)
        XCTAssertNil(mockDelegate.recommendation)
    }

    func testAutoBolusMaxIOBClamping() {
        /// `maxBolus` is set to clamp the automatic dose
        /// Autobolus without clamping: 0.65 U. Clamped recommendation: 0.2 U.
        setUp(for: .highAndRisingWithCOB, maxBolus: 5, dosingStrategy: .automaticBolus)

        // This sets up dose rounding
        let delegate = MockDelegate()
        loopDataManager.delegate = delegate

        let updateGroup = DispatchGroup()
        updateGroup.enter()

        var insulinOnBoard: InsulinValue?
        var recommendedBolus: Double?
        self.loopDataManager.getLoopState { _, state in
            insulinOnBoard = state.insulinOnBoard
            recommendedBolus = state.recommendedAutomaticDose?.recommendation.bolusUnits
            updateGroup.leave()
        }
        updateGroup.wait()

        XCTAssertEqual(recommendedBolus!, 0.5, accuracy: 0.01)
        XCTAssertEqual(insulinOnBoard?.value, 9.5)

        /// Set the `maximumBolus` to 10U so there's no clamping
        updateGroup.enter()
        self.loopDataManager.mutateSettings { settings in settings.maximumBolus = 10 }
        self.loopDataManager.getLoopState { _, state in
            insulinOnBoard = state.insulinOnBoard
            recommendedBolus = state.recommendedAutomaticDose?.recommendation.bolusUnits
            updateGroup.leave()
        }
        updateGroup.wait()

        XCTAssertEqual(recommendedBolus!, 0.65, accuracy: 0.01)
        XCTAssertEqual(insulinOnBoard?.value, 9.5)
    }

    func testTempBasalMaxIOBClamping() {
        /// `maximumBolus` is set to 5U to clamp max IOB at 10U
        /// Without clamping: 4.25 U/hr. Clamped recommendation: 2.0 U/hr.
        setUp(for: .highAndRisingWithCOB, maxBolus: 5)

        // This sets up dose rounding
        let delegate = MockDelegate()
        loopDataManager.delegate = delegate

        let updateGroup = DispatchGroup()
        updateGroup.enter()

        var insulinOnBoard: InsulinValue?
        var recommendedBasal: TempBasalRecommendation?
        self.loopDataManager.getLoopState { _, state in
            insulinOnBoard = state.insulinOnBoard
            recommendedBasal = state.recommendedAutomaticDose?.recommendation.basalAdjustment
            updateGroup.leave()
        }
        updateGroup.wait()

        XCTAssertEqual(recommendedBasal!.unitsPerHour, 2.0, accuracy: 0.01)
        XCTAssertEqual(insulinOnBoard?.value, 9.5)

        /// Set the `maximumBolus` to 10U so there's no clamping
        updateGroup.enter()
        self.loopDataManager.mutateSettings { settings in settings.maximumBolus = 10 }
        self.loopDataManager.getLoopState { _, state in
            insulinOnBoard = state.insulinOnBoard
            recommendedBasal = state.recommendedAutomaticDose?.recommendation.basalAdjustment
            updateGroup.leave()
        }
        updateGroup.wait()

        XCTAssertEqual(recommendedBasal!.unitsPerHour, 4.25, accuracy: 0.01)
        XCTAssertEqual(insulinOnBoard?.value, 9.5)
    }

}
