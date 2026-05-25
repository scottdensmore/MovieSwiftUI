//  Pure-logic helpers for the first-launch onboarding flow:
//  what step is the user on, can they advance, can they finish, and
//  should we be showing onboarding at all? UI lives in
//  OnboardingView; everything testable lives here.

import Foundation
import Backend

/// One step in the onboarding wizard. Ordered as the user sees them.
public enum OnboardingStep: Int, CaseIterable, Identifiable, Hashable {
    case welcome
    case apiKey
    case region
    case ready

    public var id: Int { rawValue }

    public var title: String {
        // Compiled into the app targets (Shared/, not a package), so the
        // default Bundle.main lookup resolves the app's catalog correctly.
        switch self {
        case .welcome: return String(localized: "Welcome", comment: "Onboarding step name: welcome")
        case .apiKey:  return String(localized: "TMDB key", comment: "Onboarding step name: TMDB API key setup")
        case .region:  return String(localized: "Region", comment: "Onboarding step name: region selection")
        case .ready:   return String(localized: "Ready", comment: "Onboarding step name: finished")
        }
    }
}

/// Stateless decisions about onboarding: should it appear, can the
/// user continue from a given step, can they finish? Lives separate
/// from the view so each branch is unit-testable.
public enum OnboardingFlow {

    // MARK: - Visibility

    /// Whether onboarding should be shown right now.
    ///
    /// Returns true when:
    /// - The user has never finished onboarding, OR
    /// - The app has no usable API key (forcing the user to pick one),
    /// AND the runtime isn't a UI smoke test (those bypass the flow).
    public static func shouldShow(
        hasCompletedOnboarding: Bool,
        hasUsableAPIKey: Bool,
        isRunningUISmokeTests: Bool
    ) -> Bool {
        if isRunningUISmokeTests { return false }
        return !hasCompletedOnboarding || !hasUsableAPIKey
    }

    /// Production convenience that pulls the inputs from
    /// AppUserDefaults and the layered API key provider.
    public static func shouldShowFromCurrentState(isRunningUISmokeTests: Bool) -> Bool {
        shouldShow(
            hasCompletedOnboarding: AppUserDefaults.hasCompletedOnboarding,
            hasUsableAPIKey: LayeredAPIKeyProvider.userKeyOverridingBundle.apiKey() != nil,
            isRunningUISmokeTests: isRunningUISmokeTests
        )
    }

    // MARK: - Step navigation

    /// Returns the next step after `current`, or nil if `current` is
    /// the last step.
    public static func nextStep(after current: OnboardingStep) -> OnboardingStep? {
        let all = OnboardingStep.allCases
        guard let idx = all.firstIndex(of: current),
              idx + 1 < all.count else { return nil }
        return all[idx + 1]
    }

    /// Returns the step before `current`, or nil if `current` is the
    /// first step.
    public static func previousStep(before current: OnboardingStep) -> OnboardingStep? {
        let all = OnboardingStep.allCases
        guard let idx = all.firstIndex(of: current),
              idx - 1 >= 0 else { return nil }
        return all[idx - 1]
    }

    /// Whether the Continue / Finish button on `step` should be
    /// enabled given the current state.
    ///
    /// Per-step rules:
    /// - `.welcome` and `.region` always advance.
    /// - `.apiKey` only advances when there's a usable key (user or
    ///   bundled). The user can paste one or fall back to the bundled
    ///   default.
    /// - `.ready` is the finish step — only available when there's
    ///   still a usable key by the time we get there.
    public static func canAdvance(from step: OnboardingStep, hasUsableAPIKey: Bool) -> Bool {
        switch step {
        case .welcome, .region:
            return true
        case .apiKey, .ready:
            return hasUsableAPIKey
        }
    }
}
