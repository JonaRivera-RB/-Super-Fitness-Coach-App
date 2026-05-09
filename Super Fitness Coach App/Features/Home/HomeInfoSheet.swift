//
//  HomeInfoSheet.swift
//  Super Fitness Coach App
//

import SwiftUI

struct HomeInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var lang

    let title: String
    let message: String

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(message)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(DesignTokens.Spacing.screenH)
            }
            .background(DesignTokens.Color.surfaceSheet)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(lang.close) { dismiss() }
                }
            }
        }
    }
}

