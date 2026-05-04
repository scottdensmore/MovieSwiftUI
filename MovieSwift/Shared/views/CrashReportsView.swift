//
//  CrashReportsView.swift
//  MovieSwift
//
//  In-app viewer for the crash + metric payloads MetricKit captured
//  to <Documents>/CrashReports/. Lets the user see what's there and
//  share an individual report off the device without needing Xcode
//  > Devices and Simulators > Download Container.
//
//  Two surfaces:
//   - CrashReportsSheet: list with date / kind / size / share
//     button per row. Empty-state when nothing's been captured.
//   - CrashReportDetailView: pretty-printed JSON for one report,
//     selectable for copy + a ShareLink in the toolbar.
//

import SwiftUI

struct CrashReportsSheet: View {
    let reports: [CrashReportStore.CrashReportFile]
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Crash reports")
                    .font(.FjallaOne(size: 22))
                Spacer()
                Button("Close", action: onDismiss)
                    .buttonStyle(.plain)
                    .foregroundColor(.steam_blue)
                    .accessibilityIdentifier("crashReportsSheet.closeButton")
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 10)

            if reports.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(reports) { report in
                            CrashReportRow(report: report)
                            if report.id != reports.last?.id {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 12)
                }
            }
        }
        .frame(minWidth: 460, idealWidth: 560, minHeight: 340, idealHeight: 460)
        .background(Color.steam_background.ignoresSafeArea())
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.shield")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No crash reports captured yet")
                .foregroundStyle(.secondary)
            Text("MetricKit delivers payloads up to once per ~24 hours, typically when you re-open the app after a crash.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 24)
    }
}

private struct CrashReportRow: View {
    let report: CrashReportStore.CrashReportFile
    @State private var isDetailPresented = false

    var body: some View {
        Button {
            isDetailPresented = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 3) {
                    Text(formattedDate(report.date))
                        .font(.callout.weight(.semibold))
                    Text("\(report.kind.rawValue.capitalized) · \(formattedSize(report.sizeBytes))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                #if !os(tvOS)
                // tvOS doesn't ship ShareLink — viewers there can
                // still tap into the detail view to read the
                // payload; sharing off the device requires another
                // mechanism.
                ShareLink(item: report.url) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.callout.weight(.semibold))
                        .foregroundColor(.steam_blue)
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("crashReportsSheet.share.\(report.id)")
                #endif
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("crashReportsSheet.row.\(report.id)")
        .sheet(isPresented: $isDetailPresented) {
            CrashReportDetailView(report: report,
                                  onDismiss: { isDetailPresented = false })
        }
    }

    private var iconName: String {
        switch report.kind {
        case .diagnostic: return "exclamationmark.triangle"
        case .metric:     return "chart.bar"
        }
    }

    private var iconColor: Color {
        switch report.kind {
        case .diagnostic: return .steam_rust
        case .metric:     return .steam_blue
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formattedSize(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

private struct CrashReportDetailView: View {
    let report: CrashReportStore.CrashReportFile
    let onDismiss: () -> Void

    @State private var prettyJSON: String = ""
    @State private var loadError: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(report.kind.rawValue.capitalized)
                        .font(.FjallaOne(size: 22))
                    Text(report.id)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                #if !os(tvOS)
                ShareLink(item: report.url) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.callout.weight(.semibold))
                        .foregroundColor(.steam_blue)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("crashReportDetail.shareButton")
                #endif
                Button("Close", action: onDismiss)
                    .buttonStyle(.plain)
                    .foregroundColor(.steam_blue)
                    .accessibilityIdentifier("crashReportDetail.closeButton")
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 10)

            ScrollView([.vertical, .horizontal]) {
                if let loadError {
                    Text(loadError)
                        .foregroundColor(.steam_rust)
                        .padding()
                } else {
                    let textBody = Text(prettyJSON)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    // textSelection is unavailable on tvOS; fall
                    // back to a non-selectable Text there.
                    #if os(tvOS)
                    textBody
                    #else
                    textBody.textSelection(.enabled)
                    #endif
                }
            }
            .background(Color.primary.opacity(0.03))
        }
        .frame(minWidth: 520, idealWidth: 720, minHeight: 420, idealHeight: 600)
        .background(Color.steam_background.ignoresSafeArea())
        .onAppear(perform: loadContents)
    }

    private func loadContents() {
        do {
            let raw = try Data(contentsOf: report.url)
            // Pretty-print so the JSON is actually readable; fall
            // back to the raw bytes as UTF-8 if it doesn't parse
            // as JSON (shouldn't happen for MetricKit payloads,
            // but be defensive).
            if let parsed = try? JSONSerialization.jsonObject(with: raw),
               let prettyData = try? JSONSerialization.data(withJSONObject: parsed,
                                                             options: [.prettyPrinted, .sortedKeys]),
               let pretty = String(data: prettyData, encoding: .utf8) {
                prettyJSON = pretty
            } else {
                prettyJSON = String(data: raw, encoding: .utf8) ?? ""
            }
        } catch {
            loadError = "Couldn't read this report: \(error.localizedDescription)"
        }
    }
}
