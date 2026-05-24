import XCTest
#if os(macOS)
@testable import Film_O_Matic
#else
@testable import MovieSwift
#endif

final class OnboardingFlowTests: XCTestCase {

    // MARK: - shouldShow

    func testShouldShowReturnsFalseForUISmokeTestsRegardlessOfState() {
        // UI smoke tests bypass onboarding so the test rig can drive
        // the app from a known menu without a sheet covering the UI.
        XCTAssertFalse(OnboardingFlow.shouldShow(
            hasCompletedOnboarding: false,
            hasUsableAPIKey: false,
            isRunningUISmokeTests: true
        ))
        XCTAssertFalse(OnboardingFlow.shouldShow(
            hasCompletedOnboarding: true,
            hasUsableAPIKey: true,
            isRunningUISmokeTests: true
        ))
    }

    func testShouldShowWhenOnboardingNotCompleted() {
        XCTAssertTrue(OnboardingFlow.shouldShow(
            hasCompletedOnboarding: false,
            hasUsableAPIKey: true,
            isRunningUISmokeTests: false
        ))
    }

    func testShouldShowWhenNoAPIKeyEvenIfOnboardingCompleted() {
        // The app can't function without a key, so re-enter the flow
        // until the user provides one.
        XCTAssertTrue(OnboardingFlow.shouldShow(
            hasCompletedOnboarding: true,
            hasUsableAPIKey: false,
            isRunningUISmokeTests: false
        ))
    }

    func testShouldNotShowWhenCompletedAndKeyAvailable() {
        XCTAssertFalse(OnboardingFlow.shouldShow(
            hasCompletedOnboarding: true,
            hasUsableAPIKey: true,
            isRunningUISmokeTests: false
        ))
    }

    // MARK: - Step navigation

    func testNextStepWalksThroughTheWizard() {
        XCTAssertEqual(OnboardingFlow.nextStep(after: .welcome), .apiKey)
        XCTAssertEqual(OnboardingFlow.nextStep(after: .apiKey), .region)
        XCTAssertEqual(OnboardingFlow.nextStep(after: .region), .ready)
    }

    func testNextStepReturnsNilForLastStep() {
        XCTAssertNil(OnboardingFlow.nextStep(after: .ready))
    }

    func testPreviousStepWalksBackThroughTheWizard() {
        XCTAssertEqual(OnboardingFlow.previousStep(before: .ready), .region)
        XCTAssertEqual(OnboardingFlow.previousStep(before: .region), .apiKey)
        XCTAssertEqual(OnboardingFlow.previousStep(before: .apiKey), .welcome)
    }

    func testPreviousStepReturnsNilForFirstStep() {
        XCTAssertNil(OnboardingFlow.previousStep(before: .welcome))
    }

    // MARK: - canAdvance

    func testCanAdvanceFromWelcomeAlways() {
        XCTAssertTrue(OnboardingFlow.canAdvance(from: .welcome, hasUsableAPIKey: false))
        XCTAssertTrue(OnboardingFlow.canAdvance(from: .welcome, hasUsableAPIKey: true))
    }

    func testCanAdvanceFromRegionAlways() {
        XCTAssertTrue(OnboardingFlow.canAdvance(from: .region, hasUsableAPIKey: false))
        XCTAssertTrue(OnboardingFlow.canAdvance(from: .region, hasUsableAPIKey: true))
    }

    func testCannotAdvanceFromAPIKeyStepWithoutKey() {
        XCTAssertFalse(OnboardingFlow.canAdvance(from: .apiKey, hasUsableAPIKey: false))
    }

    func testCanAdvanceFromAPIKeyStepWithKey() {
        XCTAssertTrue(OnboardingFlow.canAdvance(from: .apiKey, hasUsableAPIKey: true))
    }

    func testCannotFinishFromReadyStepWithoutKey() {
        // Edge case: user navigated back, cleared their key, then
        // navigated forward to Ready. Finish should still be blocked.
        XCTAssertFalse(OnboardingFlow.canAdvance(from: .ready, hasUsableAPIKey: false))
    }

    func testCanFinishFromReadyStepWithKey() {
        XCTAssertTrue(OnboardingFlow.canAdvance(from: .ready, hasUsableAPIKey: true))
    }

    // MARK: - OnboardingStep model

    func testStepRawValuesAreContiguousAndStartAtZero() {
        XCTAssertEqual(OnboardingStep.welcome.rawValue, 0)
        XCTAssertEqual(OnboardingStep.apiKey.rawValue, 1)
        XCTAssertEqual(OnboardingStep.region.rawValue, 2)
        XCTAssertEqual(OnboardingStep.ready.rawValue, 3)
    }

    func testStepAllCasesIsOrdered() {
        XCTAssertEqual(OnboardingStep.allCases, [.welcome, .apiKey, .region, .ready])
    }

    func testStepTitlesAreNonEmpty() {
        for step in OnboardingStep.allCases {
            XCTAssertFalse(step.title.isEmpty, "\(step) should have a non-empty title")
        }
    }
}
