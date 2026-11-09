import Foundation
import XCTest
@testable import Cello

final class PitchTraceTests: XCTestCase {
    func testPitchUsesExactReferenceAndSecondsFromRecordingStart() {
        let target = HummingExample.frequency
        let data = PitchTraceData(samples: [
            sample(time: 1.2, frequency: target * 2),
            sample(time: 0.2, frequency: target),
            sample(time: 0.7, frequency: target / 2)
        ], targetFrequency: target, duration: 3)

        XCTAssertEqual(data.points.map(\.time), [0.2, 0.7, 1.2])
        XCTAssertEqual(data.points[0].cents, 0, accuracy: 1e-8)
        XCTAssertEqual(data.points[1].cents, -1_200, accuracy: 1e-8)
        XCTAssertEqual(data.points[2].cents, 1_200, accuracy: 1e-8)
        XCTAssertEqual(data.timeRange, 0...3)
        XCTAssertEqual(data.nearTargetCount, 1)
        XCTAssertEqual(data.aboveTargetCount, 1)
        XCTAssertEqual(data.belowTargetCount, 1)
    }

    func testGoalBandIncludesBothExactBoundaries() {
        let target = HummingExample.frequency
        let cents = [-25.01, -25, 25, 25.01]
        let data = PitchTraceData(samples: cents.enumerated().map { index, offset in
            sample(time: Double(index) * 0.2, frequency: target * pow(2, offset / 1_200))
        }, targetFrequency: target, duration: 3)
        XCTAssertEqual(data.nearTargetCount, 2)
        XCTAssertEqual(data.aboveTargetCount, 1)
        XCTAssertEqual(data.belowTargetCount, 1)
    }

    func testInvalidOrUnconfidentObservationsDoNotBecomePlottedPitch() {
        let target = HummingExample.frequency
        let data = PitchTraceData(samples: [
            sample(time: 0.1, frequency: target),
            sample(time: -.infinity, frequency: target),
            sample(time: -0.1, frequency: target),
            sample(time: 0.2, frequency: .nan),
            sample(time: 0.3, frequency: 0),
            sample(time: 0.4, frequency: target, confidence: 0.74),
            sample(time: 0.5, frequency: target, confidence: .infinity),
            sample(time: 0.6, frequency: target, confidence: 1.1),
            sample(time: 0.7, frequency: target, rms: .nan),
            sample(time: 0.8, frequency: target, rms: 0),
            sample(time: 3.1, frequency: target)
        ], targetFrequency: target, duration: 3)

        XCTAssertEqual(data.points.count, 1)
        XCTAssertEqual(data.points.first?.time, 0.1)
        XCTAssertEqual(data.centsRange, -50...50)
    }

    func testSilenceStaysEmptyWithoutInterpolatedPitchObservations() {
        let target = HummingExample.frequency
        let times = [0.2, 0.3, 1.7, 1.8]
        let data = PitchTraceData(samples: times.map { sample(time: $0, frequency: target) },
                                  targetFrequency: target, duration: 3)
        XCTAssertEqual(data.points.map(\.time), times)
        XCTAssertFalse(data.points.contains { $0.time > 0.3 && $0.time < 1.7 })
        XCTAssertEqual(data.timeRange.upperBound, 3)
    }

    func testWidePitchErrorsExpandTheScaleRatherThanClippingOrClamping() {
        let target = HummingExample.frequency
        let data = PitchTraceData(samples: [
            sample(time: 0.2, frequency: target * pow(2, 2_400.0 / 1_200)),
            sample(time: 0.5, frequency: target * pow(2, -1_900.0 / 1_200))
        ], targetFrequency: target, duration: 3)

        XCTAssertEqual(data.points[0].cents, 2_400, accuracy: 1e-8)
        XCTAssertEqual(data.points[1].cents, -1_900, accuracy: 1e-8)
        XCTAssertGreaterThan(data.centsRange.upperBound, 2_400)
        XCTAssertLessThan(data.centsRange.lowerBound, -2_400)
        XCTAssertTrue(data.points.allSatisfy { data.centsRange.contains($0.cents) })
    }

    func testInvalidTargetsProduceNoPitchAndUnknownDurationUsesObservedTime() {
        let observed = sample(time: 2.4, frequency: HummingExample.frequency)
        for invalidTarget in [Double.nan, .infinity, 0, -110] {
            let data = PitchTraceData(samples: [observed], targetFrequency: invalidTarget, duration: 3)
            XCTAssertFalse(data.hasValidTarget)
            XCTAssertTrue(data.points.isEmpty)
        }
        let unknownDuration = PitchTraceData(samples: [observed], targetFrequency: HummingExample.frequency,
                                            duration: .nan)
        XCTAssertEqual(unknownDuration.timeRange, 0...2.4)
        XCTAssertEqual(unknownDuration.points.count, 1)
    }

    private func sample(time: Double, frequency: Double, confidence: Double = 0.95,
                        rms: Double = 0.02) -> PitchSample {
        PitchSample(time: time, frequency: frequency, confidence: confidence, rms: rms)
    }
}
