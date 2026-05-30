import SwiftUI
import Foundation
@preconcurrency import SwiftUIFlux
import Backend
import MovieSwiftFluxCore

enum SettingsFormRefreshPolicy {
    static func shouldRefreshMovieMenus(previousRegion: String, selectedRegion: String) -> Bool {
        previousRegion != selectedRegion
    }

    static func menusToRefresh(previousRegion: String, selectedRegion: String) -> [MoviesMenu] {
        guard shouldRefreshMovieMenus(previousRegion: previousRegion,
                                      selectedRegion: selectedRegion) else {
            return []
        }

        return MoviesMenu.allCases
    }
}

enum SettingsFormDebugState {
    static func moviesCount(from movies: [Int: Movie]) -> Int {
        movies.count
    }
}

enum SettingsFormState {
    static func moviesCount(in state: AppState) -> Int {
        SettingsFormDebugState.moviesCount(from: state.moviesState.movies)
    }
}

enum SettingsFormCacheResetPolicy {
    static func clearCachedData(state: AppState,
                                dispatch: @escaping DispatchFunction,
                                clearImageCache: () -> Void = {
                                    ImageLoaderCache.shared.clear()
                                },
                                clearURLCache: () -> Void = {
                                    URLCache.shared.removeAllCachedResponses()
                                },
                                archiveState: (AppState) -> Void = { state in
                                    AppPersistence.archiveNow(state: state)
                                }) {
        let cachedState = AppStateCacheReset.persistentSnapshot(from: state)
        clearImageCache()
        clearURLCache()
        dispatch(AppActions.ClearCachedData())
        archiveState(cachedState)
    }
}

struct SettingsForm: ConnectedView {
    struct Props {
        let dispatch: DispatchFunction
        let debugMoviesCount: Int
    }

    private struct RegionOption: Identifiable {
        let code: String
        let name: String
        var id: String { code }
    }

    @State var selectedRegionCode: String = AppUserDefaults.region
    @State var alwaysOriginalTitle: Bool = false
    @State private var isClearCacheConfirmationPresented = false
    @State private var isExportPresented = false
    @State private var exportDocument: UserDataDocument?
    @State private var exportSuggestedFilename: String = AppDataExport.suggestedFilename(for: Date())
    @State private var exportErrorMessage: String?
    @State private var isImportPickerPresented = false
    @State private var pendingImportEnvelope: AppDataExportEnvelope?
    @State private var pendingImportCounts: AppDataImport.Counts?
    @State private var importErrorMessage: String?
    @State private var importSuccessCounts: AppDataImport.Counts?
    @State private var backupErrorMessage: String?
    @State private var backupSuccessDate: Date?
    @State private var lastICloudBackupDate: Date? = AppDataICloudBackup.resolvedLastBackupDate()
    @State private var isPreviousVersionsSheetPresented = false
    @State private var availableICloudVersions: [AppDataICloudBackup.BackupVersionInfo] = []
    @State private var isCrashReportsSheetPresented = false
    @State private var crashReportFiles: [CrashReportStore.CrashReportFile] = []
    @State private var userAPIKeyDraft: String = AppUserDefaults.userTMDBAPIKey
    @FocusState private var isUserAPIKeyFocused: Bool
    /// Mirrors `AppUserDefaults.userTMDBAPIKey` for SwiftUI's observation
    /// system. The plain `@UserDefault` wrapper writes to `UserDefaults`
    /// but does NOT publish changes through SwiftUI's dependency graph,
    /// so without this `@AppStorage` mirror the status row, Save button,
    /// and Clear button do not update after saving or clearing — fields
    /// that read `AppUserDefaults.userTMDBAPIKey` directly stay stale
    /// until the next unrelated state change forces a re-render. Both
    /// wrappers point at the same `UserDefaults` key, so reads from
    /// `AppUserDefaults` elsewhere (APIKeyProviding, exports, etc.) see
    /// the new value too.
    @AppStorage("user_tmdb_api_key") private var persistedUserTMDBAPIKey: String = ""
    @State private var isOnboardingResetConfirmationPresented = false
    var embedInNavigationStack = true
    var showNavigationTitle = true
    var onClose: (() -> Void)?
    @EnvironmentObject private var store: Store<AppState>
    @Environment(\.dismiss) private var dismiss
    @Environment(\.archivedStateSizeDescription) private var archivedStateSizeDescription

    func map(state: AppState, dispatch: @escaping DispatchFunction) -> Props {
        Props(dispatch: dispatch,
              debugMoviesCount: SettingsFormState.moviesCount(in: state))
    }

    private var isModalPresentation: Bool {
        onClose != nil
    }

    private var regions: [RegionOption] {
        var regions: [RegionOption] = []
        for code in NSLocale.isoCountryCodes {
            let id = NSLocale.localeIdentifier(fromComponents: [NSLocale.Key.countryCode.rawValue: code])
            if let name = NSLocale(localeIdentifier: "en_US")
                .displayName(forKey: NSLocale.Key.identifier, value: id) {
                regions.append(RegionOption(code: code, name: name))
            }
        }
        return regions.sorted { $0.name < $1.name }
    }

    func debugInfoView(title: String, info: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(info).font(.body).foregroundStyle(.secondary)
        }
    }

    private func loadCurrentPreferences() {
        if regions.contains(where: { $0.code == AppUserDefaults.region }) {
            selectedRegionCode = AppUserDefaults.region
        } else if let firstRegion = regions.first {
            selectedRegionCode = firstRegion.code
        }
        alwaysOriginalTitle = AppUserDefaults.alwaysOriginalTitle
    }

    private func savePreferences(dispatch: DispatchFunction) {
        let previousRegion = AppUserDefaults.region
        AppUserDefaults.region = selectedRegionCode
        AppUserDefaults.alwaysOriginalTitle = alwaysOriginalTitle

        for menu in SettingsFormRefreshPolicy.menusToRefresh(previousRegion: previousRegion,
                                                             selectedRegion: selectedRegionCode) {
            dispatch(MoviesActions.FetchMoviesMenuList(list: menu, page: 1))
        }
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func cancelAction() {
        close()
    }

    private func clearCachedData(props: Props) {
        SettingsFormCacheResetPolicy.clearCachedData(state: store.state,
                                                     dispatch: props.dispatch)
    }

    private func startExport() {
        let now = Date()
        do {
            let data = try AppDataExport.data(from: store.state, exportDate: now)
            exportDocument = UserDataDocument(data: data)
            exportSuggestedFilename = AppDataExport.suggestedFilename(for: now)
            isExportPresented = true
        } catch {
            exportErrorMessage = "Couldn't build the export file: \(error.localizedDescription)"
        }
    }

    private func handleExportResult(_ result: Result<URL, Error>) {
        // Drop the in-memory document either way — the user has either
        // saved it or cancelled, and we don't want to keep ~20 KB of
        // their state in @State for the lifetime of the view.
        exportDocument = nil
        if case .failure(let error) = result {
            // The user cancelling is reported as a CancellationError on
            // some OS versions, so don't surface that as a real error.
            if (error as NSError).domain != NSCocoaErrorDomain || (error as NSError).code != NSUserCancelledError {
                exportErrorMessage = "Export failed: \(error.localizedDescription)"
            }
        }
    }

    private func handleImportSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            // User cancellation isn't an error worth showing.
            if (error as NSError).domain != NSCocoaErrorDomain || (error as NSError).code != NSUserCancelledError {
                importErrorMessage = "Import failed: \(error.localizedDescription)"
            }
        case .success(let urls):
            guard let url = urls.first else { return }
            // .fileImporter returns a security-scoped URL on macOS sandbox.
            // We must explicitly start/stop access while reading the file.
            let didStart = url.startAccessingSecurityScopedResource()
            defer { if didStart { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let envelope = try AppDataImport.decodeEnvelope(from: data)
                let counts = AppDataImport.previewCounts(for: envelope, against: store.state)
                pendingImportEnvelope = envelope
                pendingImportCounts = counts
            } catch let error as AppDataImport.ImportError {
                importErrorMessage = error.errorDescription
            } catch {
                importErrorMessage = "Couldn't read the export file: \(error.localizedDescription)"
            }
        }
    }

    private func confirmImport(props: Props) {
        guard let envelope = pendingImportEnvelope else { return }
        let counts = pendingImportCounts
        pendingImportEnvelope = nil
        pendingImportCounts = nil
        props.dispatch(AppActions.ImportAppData(envelope: envelope))
        importSuccessCounts = counts
    }

    private func cancelPendingImport() {
        pendingImportEnvelope = nil
        pendingImportCounts = nil
    }

    private func importPreviewMessage(_ counts: AppDataImport.Counts) -> String {
        guard counts.hasAnyChanges else {
            return "This export doesn't add anything new — your library already contains all of these items."
        }
        var lines: [String] = []
        if counts.wishlistAdded > 0 {
            lines.append("• \(counts.wishlistAdded) movie\(counts.wishlistAdded == 1 ? "" : "s") to your wishlist")
        }
        if counts.seenlistAdded > 0 {
            lines.append("• \(counts.seenlistAdded) movie\(counts.seenlistAdded == 1 ? "" : "s") to your seenlist")
        }
        if counts.fanClubAdded > 0 {
            lines.append("• \(counts.fanClubAdded) \(counts.fanClubAdded == 1 ? "person" : "people") to your fan club")
        }
        if counts.customListsAdded > 0 {
            lines.append("• \(counts.customListsAdded) new custom list\(counts.customListsAdded == 1 ? "" : "s")")
        }
        if counts.customListsUpdated > 0 {
            lines.append("• \(counts.customListsUpdated) existing custom list\(counts.customListsUpdated == 1 ? "" : "s") will be replaced")
        }
        return "Will add:\n" + lines.joined(separator: "\n")
    }

    private func importSuccessMessage(_ counts: AppDataImport.Counts) -> String {
        guard counts.hasAnyChanges else {
            return "Import finished. Nothing new was added — your library already contained these items."
        }
        return "Imported \(counts.total) item\(counts.total == 1 ? "" : "s") into your library."
    }

    // MARK: - iCloud backup / restore

    private func performICloudBackup() {
        let now = Date()
        do {
            try AppDataICloudBackup.writeBackupToICloud(state: store.state, date: now)
            lastICloudBackupDate = now
            backupSuccessDate = now
        } catch let error as AppDataICloudBackup.BackupError {
            backupErrorMessage = error.errorDescription
        } catch {
            backupErrorMessage = "Backup failed: \(error.localizedDescription)"
        }
    }

    private func performICloudRestore() {
        do {
            let envelope = try AppDataICloudBackup.readBackupFromICloud()
            let counts = AppDataImport.previewCounts(for: envelope, against: store.state)
            pendingImportEnvelope = envelope
            pendingImportCounts = counts
        } catch let error as AppDataICloudBackup.BackupError {
            backupErrorMessage = error.errorDescription
        } catch {
            backupErrorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    /// Reload the version list from iCloud and present the sheet.
    /// Called when the user taps "Show previous backups…" — we
    /// re-query NSFileVersion each time rather than caching, so a
    /// freshly-uploaded backup from another device shows up.
    private func showPreviousICloudVersions() {
        availableICloudVersions = AppDataICloudBackup.resolvedAvailableVersions()
        isPreviousVersionsSheetPresented = true
    }

    /// Restore from a specific version (rather than the current one).
    /// After reading, marks any unresolved conflicts as resolved so
    /// iCloud stops surfacing them — the user has now picked a
    /// winner.
    private func restoreFromICloudVersion(_ info: AppDataICloudBackup.BackupVersionInfo) {
        do {
            let envelope = try AppDataICloudBackup.readBackup(at: info.version)
            let counts = AppDataImport.previewCounts(for: envelope, against: store.state)
            pendingImportEnvelope = envelope
            pendingImportCounts = counts
            AppDataICloudBackup.resolvedMarkAllConflictsResolved()
            isPreviousVersionsSheetPresented = false
        } catch let error as AppDataICloudBackup.BackupError {
            backupErrorMessage = error.errorDescription
        } catch {
            backupErrorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    private func formattedBackupDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func backupSuccessMessage(_ date: Date) -> String {
        "Your data was backed up to iCloud Drive at \(formattedBackupDate(date))."
    }

    // MARK: - TMDB API key

    /// Which key the app is currently using for TMDB requests.
    private enum APIKeySource {
        case userProvided
        case bundled
        case missing
    }

    private var currentAPIKeySource: APIKeySource {
        if !persistedUserTMDBAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .userProvided
        }
        if BundleAPIKeyProvider().apiKey() != nil {
            return .bundled
        }
        return .missing
    }

    /// Persist the draft key to UserDefaults — the LayeredAPIKeyProvider
    /// inside APIService.shared re-reads on every call, so subsequent
    /// requests immediately use the new key. We write through the
    /// `@AppStorage` mirror so SwiftUI invalidates the dependent rows
    /// (status, Save/Clear buttons) on the same tick.
    private func saveUserAPIKey() {
        persistedUserTMDBAPIKey = userAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        isUserAPIKeyFocused = false
    }

    private func clearUserAPIKey() {
        userAPIKeyDraft = ""
        persistedUserTMDBAPIKey = ""
        isUserAPIKeyFocused = false
    }

    private var canSaveUserAPIKey: Bool {
        let trimmed = userAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed != persistedUserTMDBAPIKey
    }

    private var hasUserAPIKey: Bool {
        !persistedUserTMDBAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var originalTitlePreferenceRow: some View {
        Button {
            alwaysOriginalTitle.toggle()
        } label: {
            HStack {
                Text("Always show original title")
                Spacer()
                Toggle("", isOn: $alwaysOriginalTitle)
                    .labelsHidden()
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("settings.alwaysOriginalTitleToggle")
            }
            .padding(.vertical, 6)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.alwaysOriginalTitleRow")
    }

    @ViewBuilder
    private func formContent(props: Props) -> some View {
        #if os(macOS)
        macOSContent(props: props)
        #else
        iOSFormContent(props: props)
        #endif
    }

    private func iOSFormContent(props: Props) -> some View {
        Form {
            Section(header: Text("Region preferences"),
                    footer: Text("Region is used to display a more accurate movies list"),
                    content: {
                    originalTitlePreferenceRow
                    Picker("Region", selection: $selectedRegionCode) {
                            ForEach(regions) { region in
                                Text(region.name)
                                    .tag(region.code)
                                    .accessibilityIdentifier("settings.regionPicker.option.\(region.code)")
                            }
                    }
                    .accessibilityIdentifier("settings.regionPicker")
            })
            Section(header: Text("TMDB API key"),
                    footer: Text("MovieSwift uses the TMDB API for everything you see. The bundled key is shared by every install — paste your own key from your TMDB account to use your own quota."),
                    content: {
                HStack {
                    Text("Status")
                    Spacer()
                    switch currentAPIKeySource {
                    case .userProvided: Text("Using your key").foregroundStyle(.secondary)
                    case .bundled:      Text("Using bundled").foregroundStyle(.secondary)
                    case .missing:      Text("No key configured").foregroundStyle(.red)
                    }
                }
                .accessibilityIdentifier("settings.tmdb.statusLabel")

                SecureField("Paste your TMDB API key", text: $userAPIKeyDraft)
                    .focused($isUserAPIKeyFocused)
                    .submitLabel(.done)
                    .onSubmit { saveUserAPIKey() }
                    .accessibilityIdentifier("settings.tmdb.apiKeyField")

                Button {
                    saveUserAPIKey()
                } label: {
                    Label("Save key", systemImage: "checkmark.circle")
                }
                .disabled(!canSaveUserAPIKey)
                .accessibilityIdentifier("settings.tmdb.saveButton")

                if hasUserAPIKey {
                    Button(role: .destructive) {
                        clearUserAPIKey()
                    } label: {
                        Label("Clear key", systemImage: "xmark.circle")
                    }
                    .accessibilityIdentifier("settings.tmdb.clearButton")
                }

                Link(destination: URL(string: "https://www.themoviedb.org/settings/api")!) {
                    Label("Get a TMDB API key", systemImage: "arrow.up.right.square")
                }
                .accessibilityIdentifier("settings.tmdb.getKeyLink")
            })
            Section(header: Text("App data"),
                    // swiftlint:disable:next line_length
                    footer: Text("Export and Import work with a local JSON file you choose yourself. Backup uploads the same envelope to iCloud Drive (overwriting any previous backup), and Restore merges the latest iCloud backup back into your library. Your existing data is preserved on Restore — Clear cached data first if you want a clean slate."),
                    content: {
                Button(role: .destructive) {
                    isClearCacheConfirmationPresented = true
                } label: {
                    Text("Clear cached data")
                }
                .accessibilityIdentifier("settings.clearCachedDataButton")

                Button {
                    startExport()
                } label: {
                    Label("Export my data", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("settings.exportDataButton")

                Button {
                    isImportPickerPresented = true
                } label: {
                    Label("Import my data", systemImage: "square.and.arrow.down")
                }
                .accessibilityIdentifier("settings.importDataButton")

                Button {
                    performICloudBackup()
                } label: {
                    HStack {
                        Label("Back up to iCloud", systemImage: "icloud.and.arrow.up")
                        Spacer()
                        if let date = lastICloudBackupDate {
                            Text(formattedBackupDate(date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityIdentifier("settings.backupToICloudButton")

                Button {
                    performICloudRestore()
                } label: {
                    Label("Restore from iCloud", systemImage: "icloud.and.arrow.down")
                }
                .disabled(lastICloudBackupDate == nil)
                .accessibilityIdentifier("settings.restoreFromICloudButton")
            })

            Section(header: Text("Debug info")) {
                debugInfoView(title: "Movies in state",
                              info: "\(props.debugMoviesCount)")
                debugInfoView(title: "Archived state size",
                              info: archivedStateSizeDescription())
                debugInfoView(title: "Crash reports stored",
                              info: "\(CrashReportStore.countOfStoredReports())")
                Button {
                    crashReportFiles = CrashReportStore.listReportFilesInDefaultDirectory()
                    isCrashReportsSheetPresented = true
                } label: {
                    Label("View crash reports…", systemImage: "doc.text.magnifyingglass")
                }
                .accessibilityIdentifier("settings.viewCrashReportsButton")

                Button {
                    isOnboardingResetConfirmationPresented = true
                } label: {
                    Label("Show onboarding again", systemImage: "arrow.counterclockwise")
                }
                .accessibilityIdentifier("settings.resetOnboardingButton")
            }
            Section(header: Text("About"),
                    footer: Text("Movie and people data, posters, and biographies are provided by The Movie Database (TMDB). MovieSwift is an unofficial client.")) {
                HStack {
                    Label("MovieSwift", systemImage: "app.badge.fill")
                    Spacer()
                    Text("\(AppDataExport.bundleVersion()) (\(AppDataExport.bundleBuild()))")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("settings.about.versionRow")

                Link(destination: URL(string: "https://www.themoviedb.org")!) {
                    VStack(alignment: .leading, spacing: 3) {
                        Label("Powered by TMDB", systemImage: "film.stack")
                            .foregroundStyle(Color.steam_blue)
                        Text("This product uses the TMDB API but is not endorsed or certified by TMDB.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("settings.about.tmdbAttributionLink")

                if let privacyURL = privacyPolicyURL {
                    Link(destination: privacyURL) {
                        Label("Privacy policy", systemImage: "lock.shield")
                            .foregroundStyle(Color.steam_blue)
                    }
                    .accessibilityIdentifier("settings.about.privacyPolicyLink")
                }
            }
        }
        .onAppear(perform: loadCurrentPreferences)
            .onChange(of: selectedRegionCode) { _, _ in
                if !isModalPresentation {
                    savePreferences(dispatch: props.dispatch)
                }
            }
            .onChange(of: alwaysOriginalTitle) { _, _ in
                if !isModalPresentation {
                    savePreferences(dispatch: props.dispatch)
                }
            }
            .tint(.steam_gold)
            .scrollContentBackground(.hidden)
            .background(Color.steam_background)
            .safeAreaPadding(.horizontal, isModalPresentation ? 0 : 12)
    }

    // MARK: - macOS styled layout
    //
    // The system Form / Section look fights the rest of the app's
    // steam-themed design. This rebuilds Settings as a ScrollView of
    // grouped cards with FjallaOne section headers, steam_gold accents,
    // and steam_rust for destructive actions — matching the language used
    // by My Lists, Fan Club, Discover, and the sidebar.

    private func macOSContent(props: Props) -> some View {
        ScrollView {
            // Two-frame wrap so the readable column stays at 720pt while the
            // ScrollView's content fills the detail pane.
            //   - inner frame caps the card at 720pt
            //   - outer frame is `.infinity` so the wrapper spans the
            //     available width, which makes the ScrollView's content
            //     track full-width and pins the vertical scroller to the
            //     right edge of the detail pane (instead of floating at
            //     ~column 720 with empty space to its right).
            // The card itself is centered horizontally inside the wrapper —
            // matches the System Settings / Xcode preferences pattern on
            // wide windows.
            VStack(alignment: .leading, spacing: 22) {
                regionPreferencesSection
                tmdbAPIKeySection
                appDataSection
                debugInfoSection(props: props)
                aboutSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.steam_background)
        .tint(.steam_gold)
        .onAppear(perform: loadCurrentPreferences)
        .onChange(of: selectedRegionCode) { _, _ in
            if !isModalPresentation {
                savePreferences(dispatch: props.dispatch)
            }
        }
        .onChange(of: alwaysOriginalTitle) { _, _ in
            if !isModalPresentation {
                savePreferences(dispatch: props.dispatch)
            }
        }
    }

    // MARK: Section primitives

    @ViewBuilder
    private func sectionCard<Content: View>(
        title: String,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.FjallaOne(size: 14))
                .tracking(1.4)
                .foregroundStyle(Color.steam_gold)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )

            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var rowDivider: some View {
        Divider()
            .padding(.leading, 14)
            .background(Color.primary.opacity(0.04))
    }

    // MARK: Sections

    private var regionPreferencesSection: some View {
        sectionCard(title: "Region preferences",
                    footer: "Region is used to display a more accurate movies list.") {
            regionRow
            rowDivider
            originalTitleRow
        }
    }

    private var tmdbAPIKeySection: some View {
        sectionCard(title: "TMDB API key",
                    // swiftlint:disable:next line_length
                    footer: "MovieSwift uses the TMDB API for everything you see. The bundled key is shared by every install — paste your own key from your TMDB account to use your own quota and avoid shared rate limits.") {
            apiKeyStatusRow
            rowDivider
            apiKeyEntryRow
            rowDivider
            apiKeyActionsRow
        }
    }

    private var appDataSection: some View {
        sectionCard(title: "App data",
                    // swiftlint:disable:next line_length
                    footer: "Export and Import work with a local JSON file you choose yourself. Backup uploads the same envelope to iCloud Drive (overwriting the latest version), and Restore merges the latest iCloud backup back into your library. Show previous backups lets you pick from older versions iCloud Drive has retained — useful if you accidentally backed up empty state. Your existing data is preserved on Restore — Clear cached data first if you want a clean slate.") {
            clearCachedDataRow
            rowDivider
            exportDataRow
            rowDivider
            importDataRow
            rowDivider
            backupToICloudRow
            rowDivider
            restoreFromICloudRow
            if lastICloudBackupDate != nil {
                rowDivider
                showPreviousVersionsRow
            }
        }
    }

    private func debugInfoSection(props: Props) -> some View {
        sectionCard(title: "Debug info") {
            debugRow(title: "Movies in state",
                     info: "\(props.debugMoviesCount)")
            rowDivider
            debugRow(title: "Archived state size",
                     info: archivedStateSizeDescription())
            rowDivider
            debugRow(title: "Crash reports stored",
                     info: "\(CrashReportStore.countOfStoredReports())")
            rowDivider
            viewCrashReportsRow
            rowDivider
            resetOnboardingRow
        }
    }

    private var viewCrashReportsRow: some View {
        Button {
            crashReportFiles = CrashReportStore.listReportFilesInDefaultDirectory()
            isCrashReportsSheetPresented = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.body)
                    .foregroundStyle(Color.steam_blue)
                    .frame(width: 22)
                Text("View crash reports…")
                    .foregroundStyle(Color.steam_blue)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.viewCrashReportsButton")
    }

    // MARK: - About / TMDB attribution
    //
    // TMDB's terms require attribution wherever their data is used in
    // an app. This section makes that visible, alongside the app's
    // version & build for support purposes.

    private var aboutSection: some View {
        sectionCard(title: "About",
                    footer: "Movie and people data, posters, and biographies are provided by The Movie Database (TMDB). MovieSwift is an unofficial client.") {
            appVersionRow
            rowDivider
            tmdbAttributionRow
            // Privacy policy row only renders when an URL has been
            // configured via PRIVACY_POLICY_URL — keeps a placeholder
            // link out of dev builds and out of the App Store
            // submission until a real policy is hosted.
            if let privacyURL = privacyPolicyURL {
                rowDivider
                privacyPolicyRow(url: privacyURL)
            }
        }
    }

    /// Reads `PRIVACY_POLICY_URL` from the app bundle's Info.plist
    /// and validates it parses as a real URL. Returns nil when
    /// unset (the substitution wasn't filled in) so the Settings
    /// row can be hidden.
    private var privacyPolicyURL: URL? {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "PRIVACY_POLICY_URL") as? String) ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed != "$(PRIVACY_POLICY_URL)",
              let url = URL(string: trimmed),
              url.scheme == "https" else {
            return nil
        }
        return url
    }

    private func privacyPolicyRow(url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.body)
                    .foregroundStyle(Color.steam_blue)
                    .frame(width: 22)
                Text("Privacy policy")
                    .foregroundStyle(Color.steam_blue)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.about.privacyPolicyLink")
    }

    private var appVersionRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "app.badge.fill")
                .font(.body)
                .foregroundStyle(Color.steam_gold)
                .frame(width: 22)
            Text("MovieSwift")
            Spacer(minLength: 12)
            Text("\(AppDataExport.bundleVersion()) (\(AppDataExport.bundleBuild()))")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityIdentifier("settings.about.versionRow")
    }

    private var tmdbAttributionRow: some View {
        Link(destination: URL(string: "https://www.themoviedb.org")!) {
            HStack(spacing: 12) {
                Image(systemName: "film.stack")
                    .font(.body)
                    .foregroundStyle(Color.steam_blue)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Powered by TMDB")
                        .foregroundStyle(Color.steam_blue)
                    Text("This product uses the TMDB API but is not endorsed or certified by TMDB.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.about.tmdbAttributionLink")
    }

    private var resetOnboardingRow: some View {
        Button {
            isOnboardingResetConfirmationPresented = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.body)
                    .foregroundStyle(Color.steam_blue)
                    .frame(width: 22)
                Text("Show onboarding again")
                    .foregroundStyle(Color.steam_blue)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.resetOnboardingButton")
    }

    // MARK: Rows

    private var regionRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .font(.body)
                .foregroundStyle(Color.steam_blue)
                .frame(width: 22)
            Text("Region")
            Spacer(minLength: 12)
            Picker("Region", selection: $selectedRegionCode) {
                ForEach(regions) { region in
                    Text(region.name).tag(region.code)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(.steam_gold)
            .accessibilityIdentifier("settings.regionPicker")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var originalTitleRow: some View {
        Button {
            alwaysOriginalTitle.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "character.book.closed")
                    .font(.body)
                    .foregroundStyle(Color.steam_blue)
                    .frame(width: 22)
                Text("Always show original title")
                Spacer(minLength: 12)
                Toggle("", isOn: $alwaysOriginalTitle)
                    .labelsHidden()
                    .allowsHitTesting(false)
                    .tint(.steam_gold)
                    .accessibilityIdentifier("settings.alwaysOriginalTitleToggle")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.alwaysOriginalTitleRow")
    }

    private var clearCachedDataRow: some View {
        Button {
            isClearCacheConfirmationPresented = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "trash")
                    .font(.body)
                    .foregroundStyle(Color.steam_rust)
                    .frame(width: 22)
                Text("Clear cached data")
                    .foregroundStyle(Color.steam_rust)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.clearCachedDataButton")
    }

    private var exportDataRow: some View {
        Button {
            startExport()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.up")
                    .font(.body)
                    .foregroundStyle(Color.steam_blue)
                    .frame(width: 22)
                Text("Export my data")
                    .foregroundStyle(Color.steam_blue)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.exportDataButton")
    }

    private var importDataRow: some View {
        Button {
            isImportPickerPresented = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.down")
                    .font(.body)
                    .foregroundStyle(Color.steam_blue)
                    .frame(width: 22)
                Text("Import my data")
                    .foregroundStyle(Color.steam_blue)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.importDataButton")
    }

    private var backupToICloudRow: some View {
        Button {
            performICloudBackup()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "icloud.and.arrow.up")
                    .font(.body)
                    .foregroundStyle(Color.steam_blue)
                    .frame(width: 22)
                Text("Back up to iCloud")
                    .foregroundStyle(Color.steam_blue)
                Spacer()
                if let date = lastICloudBackupDate {
                    Text(formattedBackupDate(date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.backupToICloudButton")
    }

    private var restoreFromICloudRow: some View {
        let hasBackup = lastICloudBackupDate != nil
        return Button {
            performICloudRestore()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.body)
                    .foregroundStyle(hasBackup ? Color.steam_blue : .secondary)
                    .frame(width: 22)
                Text("Restore from iCloud")
                    .foregroundStyle(hasBackup ? Color.steam_blue : .secondary)
                Spacer()
                if hasBackup {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                } else {
                    Text("No backup")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!hasBackup)
        .accessibilityIdentifier("settings.restoreFromICloudButton")
    }

    private var showPreviousVersionsRow: some View {
        Button {
            showPreviousICloudVersions()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.body)
                    .foregroundStyle(Color.steam_blue)
                    .frame(width: 22)
                Text("Show previous backups…")
                    .foregroundStyle(Color.steam_blue)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.showPreviousBackupsButton")
    }

    // MARK: - TMDB API key rows

    private var apiKeyStatusRow: some View {
        // swiftlint:disable:next large_tuple
        let (icon, iconColor, label, labelColor): (String, Color, String, Color) = {
            switch currentAPIKeySource {
            case .userProvided:
                return ("checkmark.seal.fill", .steam_gold, "Using your key", .primary)
            case .bundled:
                return ("checkmark.seal", .steam_blue, "Using the bundled key", .primary)
            case .missing:
                return ("exclamationmark.triangle.fill", .steam_rust,
                        "No API key configured — TMDB requests will fail", .steam_rust)
            }
        }()

        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(iconColor)
                .frame(width: 22)
            Text(label)
                .foregroundStyle(labelColor)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityIdentifier("settings.tmdb.statusLabel")
    }

    private var apiKeyEntryRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.body)
                .foregroundStyle(Color.steam_blue)
                .frame(width: 22)
            SecureField("Paste your TMDB API key", text: $userAPIKeyDraft)
                .textFieldStyle(.plain)
                .focused($isUserAPIKeyFocused)
                .submitLabel(.done)
                .onSubmit { saveUserAPIKey() }
                .accessibilityIdentifier("settings.tmdb.apiKeyField")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var apiKeyActionsRow: some View {
        HStack(spacing: 8) {
            Link(destination: URL(string: "https://www.themoviedb.org/settings/api")!) {
                Label("Get a TMDB API key", systemImage: "arrow.up.right.square")
                    .font(.callout)
                    .foregroundStyle(Color.steam_blue)
            }
            .accessibilityIdentifier("settings.tmdb.getKeyLink")

            Spacer()

            if hasUserAPIKey {
                Button("Clear", role: .destructive) {
                    clearUserAPIKey()
                }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.steam_rust)
                .accessibilityIdentifier("settings.tmdb.clearButton")
            }

            Button {
                saveUserAPIKey()
            } label: {
                Text("Save")
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(canSaveUserAPIKey ? Color.steam_gold : Color.secondary.opacity(0.25))
                    )
                    .foregroundStyle(canSaveUserAPIKey ? .black : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(!canSaveUserAPIKey)
            .accessibilityIdentifier("settings.tmdb.saveButton")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func comingSoonRow(title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text("Soon")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(Color.primary.opacity(0.10))
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func debugRow(title: String, info: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            Text(title)
            Spacer(minLength: 12)
            Text(info)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func screen(props: Props) -> some View {
        if showNavigationTitle {
            formContent(props: props)
                .navigationTitle("Settings")
                #if !os(macOS)
                .navigationBarTitleDisplayMode(.large)
                #endif
                .toolbar {
                    if isModalPresentation {
                        ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: cancelAction)
                    .padding(.horizontal, 6)
                                .accessibilityIdentifier("settings.cancelButton")
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                savePreferences(dispatch: props.dispatch)
                                close()
                            }
                            .padding(.horizontal, 6)
                            .accessibilityIdentifier("settings.saveButton")
                        }
                    }
                }
        } else {
            formContent(props: props)
        }
    }

    func body(props: Props) -> some View {
        Group {
            if embedInNavigationStack {
                NavigationStack {
                    screen(props: props)
                }
            } else {
                screen(props: props)
            }
        }
        .background(Color.steam_background.ignoresSafeArea())
        .confirmationDialog("Clear cached data?",
                            isPresented: $isClearCacheConfirmationPresented,
                            titleVisibility: .visible) {
            Button("Clear Cached Data", role: .destructive) {
                clearCachedData(props: props)
            }
            Button("Cancel", role: .cancel) {
            }
        } message: {
            Text("This removes cached movie and people data and clears downloaded image responses, but keeps your lists and preferences.")
        }
        .fileExporter(isPresented: $isExportPresented,
                      document: exportDocument,
                      contentType: .json,
                      defaultFilename: exportSuggestedFilename,
                      onCompletion: handleExportResult)
        .alert("Export failed",
               isPresented: Binding(
                get: { exportErrorMessage != nil },
                set: { if !$0 { exportErrorMessage = nil } }
               ),
               presenting: exportErrorMessage) { _ in
            Button("OK", role: .cancel) { exportErrorMessage = nil }
        } message: { message in
            Text(message)
        }
        .fileImporter(isPresented: $isImportPickerPresented,
                      allowedContentTypes: [.json],
                      allowsMultipleSelection: false,
                      onCompletion: handleImportSelection)
        .alert("Import data?",
               isPresented: Binding(
                get: { pendingImportEnvelope != nil },
                set: { if !$0 { cancelPendingImport() } }
               ),
               presenting: pendingImportCounts) { _ in
            Button("Import", action: { confirmImport(props: props) })
                .accessibilityIdentifier("settings.import.confirmButton")
            Button("Cancel", role: .cancel, action: cancelPendingImport)
        } message: { counts in
            Text(importPreviewMessage(counts))
        }
        .alert("Import failed",
               isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { if !$0 { importErrorMessage = nil } }
               ),
               presenting: importErrorMessage) { _ in
            Button("OK", role: .cancel) { importErrorMessage = nil }
        } message: { message in
            Text(message)
        }
        .alert("Import complete",
               isPresented: Binding(
                get: { importSuccessCounts != nil },
                set: { if !$0 { importSuccessCounts = nil } }
               ),
               presenting: importSuccessCounts) { _ in
            Button("OK", role: .cancel) { importSuccessCounts = nil }
        } message: { counts in
            Text(importSuccessMessage(counts))
        }
        .alert("Backed up to iCloud",
               isPresented: Binding(
                get: { backupSuccessDate != nil },
                set: { if !$0 { backupSuccessDate = nil } }
               ),
               presenting: backupSuccessDate) { _ in
            Button("OK", role: .cancel) { backupSuccessDate = nil }
        } message: { date in
            Text(backupSuccessMessage(date))
        }
        .alert("iCloud backup",
               isPresented: Binding(
                get: { backupErrorMessage != nil },
                set: { if !$0 { backupErrorMessage = nil } }
               ),
               presenting: backupErrorMessage) { _ in
            Button("OK", role: .cancel) { backupErrorMessage = nil }
        } message: { message in
            Text(message)
        }
        .confirmationDialog("Show onboarding again?",
                            isPresented: $isOnboardingResetConfirmationPresented,
                            titleVisibility: .visible) {
            Button("Show onboarding") {
                AppUserDefaults.hasCompletedOnboarding = false
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The onboarding wizard will appear next time you launch MovieSwift.")
        }
        .sheet(isPresented: $isPreviousVersionsSheetPresented) {
            PreviousICloudBackupsSheet(
                versions: availableICloudVersions,
                onRestore: restoreFromICloudVersion,
                onDismiss: { isPreviousVersionsSheetPresented = false }
            )
        }
        .sheet(isPresented: $isCrashReportsSheetPresented) {
            CrashReportsSheet(
                reports: crashReportFiles,
                onDismiss: { isCrashReportsSheetPresented = false }
            )
        }
    }
}

/// Picker sheet for restoring an older iCloud backup. Each row
/// shows the version's date, the originating device when iCloud has
/// it, and a Restore action. Conflict versions are flagged so the
/// user knows why two backups exist for the same minute.
private struct PreviousICloudBackupsSheet: View {
    let versions: [AppDataICloudBackup.BackupVersionInfo]
    let onRestore: (AppDataICloudBackup.BackupVersionInfo) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Previous iCloud backups")
                    .font(.FjallaOne(size: 22))
                Spacer()
                Button("Close", action: onDismiss)
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.steam_blue)
                    .accessibilityIdentifier("previousBackupsSheet.closeButton")
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 10)

            if versions.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No previous backups available")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 18)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(versions) { info in
                            row(info: info)
                            if info.id != versions.last?.id {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
        }
        .frame(minWidth: 460, idealWidth: 520, minHeight: 320, idealHeight: 380)
        .background(Color.steam_background.ignoresSafeArea())
    }

    private func row(info: AppDataICloudBackup.BackupVersionInfo) -> some View {
        HStack(spacing: 12) {
            Image(systemName: info.isUnresolvedConflict ? "exclamationmark.icloud" : "icloud")
                .font(.title3)
                .foregroundStyle(info.isUnresolvedConflict ? Color.steam_rust : Color.steam_blue)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(formattedDate(info.modificationDate))
                        .font(.callout.weight(.semibold))
                    if info.isCurrent {
                        Text("Latest")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.steam_gold.opacity(0.25)))
                            .foregroundStyle(.primary)
                    }
                    if info.isUnresolvedConflict {
                        Text("Conflict")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.steam_rust.opacity(0.25)))
                            .foregroundStyle(Color.steam_rust)
                    }
                }
                if let device = info.computerName {
                    Text(device)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Restore") {
                onRestore(info)
            }
            .buttonStyle(.plain)
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.steam_gold.opacity(0.25)))
            .accessibilityIdentifier("previousBackupsSheet.restore.\(info.id)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    SettingsForm()
        .environmentObject(sampleStore)
}
