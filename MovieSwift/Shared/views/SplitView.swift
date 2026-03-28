//
//  SplitView.swift
//  MovieSwift
//

import SwiftUI

// MARK: - MacOS implementation
struct SplitView: View {
    let isRunningUISmokeTests: Bool
    @State private var selectedMenu: OutlineMenu? = .popular

    @ViewBuilder
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedMenu) {
                ForEach(OutlineMenu.allCases, id: \.self) { menu in
                    OutlineRow(item: menu, isSelected: selectedMenu == menu)
                        .frame(height: 50)
                        .tag(menu)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedMenu = menu
                        }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Movies")
            .frame(minWidth: 260, idealWidth: 300)
        } detail: {
            if let selectedMenu {
                selectedMenu.contentView(isRunningUISmokeTests: isRunningUISmokeTests)
                    .padding(.leading, selectedMenu == .settings ? 0 : 12)
            } else {
                Text("Select a section")
                    .foregroundColor(.secondary)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
