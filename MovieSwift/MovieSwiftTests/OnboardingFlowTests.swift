import Testing
#if os(macOS)
@testable import Film_O_Matic
#else
@testable import MovieSwift
#endif

@Suite struct OnboardingFlowTests {

    // MARK: - shouldShow

    @Test func shouldShowReturnsFalseForUISmokeTestsRegardlessOfState() {
        // UI smoke tests bypass onboarding so the test rig can drive
        // the app from a known menu without a sheet covering the UI.
        #expect(!(OnboardingFlow.shouldShow(
            hasCompletedOnboarding: false,
            hasUsableAPIKey: false,
            isRunningUISmokeTests: true
        )))
        #expect(!(OnboardingFlow.shouldShow(
            hasCompletedOnboarding: true,
            hasUsableAPIKey: true,
            isRunningUISmokeTests: true
        )))
    }

    @Test func shouldShowWhenOnboardingNotCompleted() {
        #expect(OnboardingFlow.shouldShow(
            hasCompletedOnboarding: false,
            hasUsableAPIKey: true,
            isRunningUISmokeTests: false
        ))
    }

    @Test func shouldShowWhenNoAPIKeyEvenIfOnboardingCompleted() {
        // The app can't function without a key, so re-enter the flow
        // until the user provides one.
        #expect(OnboardingFlow.shouldShow(
            hasCompletedOnboarding: true,
            hasUsableAPIKey: false,
            isRunningUISmokeTests: false
        ))
    }

    @Test func shouldNotShowWhenCompletedAndKeyAvailable() {
        #expect(!(OnboardingFlow.shouldShow(
            hasCompletedOnboarding: true,
            hasUsableAPIKey: true,
            isRunningUISmokeTests: false
        )))
    }

    // MARK: - Step navigation

    @Test func nextStepWalksThroughTheWizard() {
        #expect(OnboardingFlow.nextStep(after: .welcome) == .apiKey)
        #expect(OnboardingFlow.nextStep(after: .apiKey) == .region)
        #expect(OnboardingFlow.nextStep(after: .region) == .ready)
    }

    @Test func nextStepReturnsNilForLastStep() {
        #expect(OnboardingFlow.nextStep(after: .ready) == nil)
    }

    @Test func previousStepWalksBackThroughTheWizard() {
        #expect(OnboardingFlow.previousStep(before: .ready) == .region)
        #expect(OnboardingFlow.previousStep(before: .region) == .apiKey)
        #expect(OnboardingFlow.previousStep(before: .apiKey) == .welcome)
    }

    @Test func previousStepReturnsNilForFirstStep() {
        #expect(OnboardingFlow.previousStep(before: .welcome) == nil)
    }

    // MARK: - canAdvance

    @Test func canAdvanceFromWelcomeAlways() {
        #expect(OnboardingFlow.canAdvance(from: .welcome, hasUsableAPIKey: false))
        #expect(OnboardingFlow.canAdvance(from: .welcome, hasUsableAPIKey: true))
    }

    @Test func canAdvanceFromRegionAlways() {
        #expect(OnboardingFlow.canAdvance(from: .region, hasUsableAPIKey: false))
        #expect(OnboardingFlow.canAdvance(from: .region, hasUsableAPIKey: true))
    }

    @Test func cannotAdvanceFromAPIKeyStepWithoutKey() {
        #expect(!(OnboardingFlow.canAdvance(from: .apiKey, hasUsableAPIKey: false)))
    }

    @Test func canAdvanceFromAPIKeyStepWithKey() {
        #expect(OnboardingFlow.canAdvance(from: .apiKey, hasUsableAPIKey: true))
    }

    @Test func cannotFinishFromReadyStepWithoutKey() {
        // Edge case: user navigated back, cleared their key, then
        // navigated forward to Ready. Finish should still be blocked.
        #expect(!(OnboardingFlow.canAdvance(from: .ready, hasUsableAPIKey: false)))
    }

    @Test func canFinishFromReadyStepWithKey() {
        #expect(OnboardingFlow.canAdvance(from: .ready, hasUsableAPIKey: true))
    }

    // MARK: - OnboardingStep model

    @Test func stepRawValuesAreContiguousAndStartAtZero() {
        #expect(OnboardingStep.welcome.rawValue == 0)
        #expect(OnboardingStep.apiKey.rawValue == 1)
        #expect(OnboardingStep.region.rawValue == 2)
        #expect(OnboardingStep.ready.rawValue == 3)
    }

    @Test func stepAllCasesIsOrdered() {
        #expect(OnboardingStep.allCases == [.welcome, .apiKey, .region, .ready])
    }

    @Test func stepTitlesAreNonEmpty() {
        for step in OnboardingStep.allCases {
            #expect(!(step.title.isEmpty), "\(step) should have a non-empty title")
        }
    }
}
