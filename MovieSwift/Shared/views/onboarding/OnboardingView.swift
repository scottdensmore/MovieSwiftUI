//
//  OnboardingView.swift
//  MovieSwift
//
//  First-launch onboarding wizard. Four steps:
//   1. Welcome — explain what the app does.
//   2. TMDB API key — paste your own or fall back to the bundled key.
//   3. Region — pick the country whose release schedule the app
//      should follow.
//   4. Ready — confirm everything's set, finish.
//
//  Stateless step decisions live in OnboardingFlow so they can be
//  unit-tested without a SwiftUI view tree.
//

import SwiftUI
import Backend

struct OnboardingView: View {
    /// Called when the user completes (or successfully skips) the
    /// flow. The host scene is responsible for dismissing the sheet
    /// and marking onboarding done in AppUserDefaults.
    let onComplete: () -> Void

    @State private var currentStep: OnboardingStep = .welcome
    @State private var userAPIKeyDraft: String = AppUserDefaults.userTMDBAPIKey
    @State private var selectedRegion: String = AppUserDefaults.region

    /// Re-evaluated whenever `userAPIKeyDraft` changes — the API key
    /// step uses this to gate Continue.
    private var hasUsableAPIKey: Bool {
        let trimmed = userAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return true }
        // The user might not have entered anything but the bundled
        // key still works.
        if AppUserDefaults.userTMDBAPIKey
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return true
        }
        return BundleAPIKeyProvider().apiKey() != nil
    }

    private struct RegionOption: Identifiable, Hashable {
        let code: String
        let name: String
        var id: String { code }
    }

    private var regions: [RegionOption] {
        var options: [RegionOption] = []
        for code in NSLocale.isoCountryCodes {
            let id = NSLocale.localeIdentifier(fromComponents: [NSLocale.Key.countryCode.rawValue: code])
            if let name = NSLocale(localeIdentifier: "en_US")
                .displayName(forKey: NSLocale.Key.identifier, value: id) {
                options.append(RegionOption(code: code, name: name))
            }
        }
        return options.sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(spacing: 0) {
            stepIndicator
                .padding(.top, 28)
                .padding(.bottom, 12)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 32)

            footer
                .padding(.horizontal, 24)
                .padding(.bottom, 22)
        }
        .frame(minWidth: 520, idealWidth: 600, minHeight: 520, idealHeight: 600)
        .background(Color.steam_background.ignoresSafeArea())
        .accessibilityIdentifier("onboarding.root")
    }

    // MARK: - Step indicator

    private var stepIndicator: some View {
        HStack(spacing: 10) {
            ForEach(OnboardingStep.allCases) { step in
                Capsule()
                    .fill(step.rawValue <= currentStep.rawValue
                          ? Color.steam_gold
                          : Color.secondary.opacity(0.25))
                    .frame(width: step == currentStep ? 28 : 18, height: 5)
                    .animation(.easeInOut(duration: 0.18), value: currentStep)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(currentStep.rawValue + 1) of \(OnboardingStep.allCases.count)")
    }

    // MARK: - Step content

    @ViewBuilder
    private var content: some View {
        switch currentStep {
        case .welcome: welcomeStep
        case .apiKey:  apiKeyStep
        case .region:  regionStep
        case .ready:   readyStep
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 18) {
            Image(systemName: "film.stack")
                .font(.system(size: 64, weight: .semibold))
                .foregroundColor(.steam_gold)
                .padding(.top, 20)
            Text("Welcome to MovieSwift")
                .font(.FjallaOne(size: 32))
            Text("Browse, save, and discover movies and people from themoviedb.org. A few quick steps and you're set.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
    }

    private var apiKeyStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "key.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundColor(.steam_gold)
            Text("Set up your TMDB key")
                .font(.FjallaOne(size: 24))
            Text("MovieSwift uses themoviedb.org for everything you see. The bundled key is shared by every install — paste your own to get full personal quota and faster responses.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("API key")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                SecureField("Paste your TMDB API key (optional)", text: $userAPIKeyDraft)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("onboarding.apiKeyField")
            }
            .padding(.top, 4)

            Link(destination: URL(string: "https://www.themoviedb.org/settings/api")!) {
                Label("Get a TMDB API key", systemImage: "arrow.up.right.square")
                    .font(.callout)
                    .foregroundColor(.steam_blue)
            }
            .accessibilityIdentifier("onboarding.getKeyLink")

            apiKeyStatusFootnote
                .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var apiKeyStatusFootnote: some View {
        if hasUsableAPIKey {
            Label("Ready to go", systemImage: "checkmark.seal.fill")
                .font(.caption)
                .foregroundColor(.steam_gold)
        } else {
            Label("A TMDB key is required — paste yours above or get one with the link.",
                  systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundColor(.steam_rust)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var regionStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "globe")
                .font(.system(size: 38, weight: .semibold))
                .foregroundColor(.steam_gold)
            Text("Pick your region")
                .font(.FjallaOne(size: 24))
            Text("Region affects the upcoming-releases and now-playing lists, plus what counts as \"available\" for streaming.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Region", selection: $selectedRegion) {
                ForEach(regions) { region in
                    Text(region.name).tag(region.code)
                }
            }
            .pickerStyle(.menu)
            .tint(.steam_gold)
            .padding(.top, 4)
            .accessibilityIdentifier("onboarding.regionPicker")

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var readyStep: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64, weight: .semibold))
                .foregroundColor(.steam_gold)
                .padding(.top, 20)
            Text("You're all set")
                .font(.FjallaOne(size: 32))
            Text("Your settings are saved. Open MovieSwift to start browsing — you can always change these later in Settings.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
    }

    // MARK: - Footer (Back + Continue)

    private var footer: some View {
        HStack(spacing: 12) {
            if let previous = OnboardingFlow.previousStep(before: currentStep) {
                Button("Back") {
                    currentStep = previous
                }
                .buttonStyle(.plain)
                .foregroundColor(.steam_blue)
                .accessibilityIdentifier("onboarding.backButton")
            }
            Spacer()
            Button(action: advance) {
                Text(advanceTitle)
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(canAdvance ? Color.steam_gold : Color.secondary.opacity(0.25))
                    )
                    .foregroundColor(canAdvance ? .black : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(!canAdvance)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("onboarding.continueButton")
        }
    }

    private var canAdvance: Bool {
        OnboardingFlow.canAdvance(from: currentStep, hasUsableAPIKey: hasUsableAPIKey)
    }

    private var advanceTitle: String {
        switch currentStep {
        case .welcome: return "Get Started"
        case .apiKey:  return "Continue"
        case .region:  return "Continue"
        case .ready:   return "Open MovieSwift"
        }
    }

    private func advance() {
        switch currentStep {
        case .apiKey:
            // Persist the key now so the next step can read it back if
            // the user navigates back and forth.
            AppUserDefaults.userTMDBAPIKey = userAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        case .region:
            AppUserDefaults.region = selectedRegion
        default:
            break
        }
        if let next = OnboardingFlow.nextStep(after: currentStep) {
            currentStep = next
        } else {
            // Last step → finish.
            AppUserDefaults.hasCompletedOnboarding = true
            onComplete()
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
