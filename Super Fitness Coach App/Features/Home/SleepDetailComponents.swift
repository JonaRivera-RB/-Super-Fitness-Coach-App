//
//  SleepDetailComponents.swift
//  Super Fitness Coach App
//

import SwiftUI

// MARK: - Status band (0–100)

enum SleepDetailPresentationBand {
    case attention, normal, excellent

    static func fromScore(_ s: Int) -> SleepDetailPresentationBand {
        if s < 60 { return .attention }
        if s <= 85 { return .normal }
        return .excellent
    }

    func statusLabel(_ lang: AppLanguage) -> String {
        switch self {
        case .attention: return lang.sleepDetailStatusAttention
        case .normal: return lang.sleepDetailStatusNormal
        case .excellent: return lang.sleepDetailStatusExcellent
        }
    }

    func color(_: ColorScheme) -> Color {
        switch self {
        case .attention: return DesignTokens.Color.caution
        case .normal: return DesignTokens.Color.info
        case .excellent: return DesignTokens.Color.positive
        }
    }
}

// MARK: - Segmented (MVP: only Day tappable)

struct SleepDetailSegmentedHeader: View {
    @Environment(\.appLanguage) private var lang
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selected: Int

    var body: some View {
        HStack(spacing: 0) {
            segment(0, title: lang.sleepDetailSegmentDay, enabled: true)
            segment(1, title: lang.sleepDetailSegmentWeek, enabled: false)
            segment(2, title: lang.sleepDetailSegmentMonth, enabled: false)
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.pill, style: .continuous)
                .fill(DesignTokens.Color.surfaceElevated)
        )
        .accessibilityElement(children: .ignore)
    }

    private func segment(_ index: Int, title: String, enabled: Bool) -> some View {
        let on = selected == index && enabled
        return Button {
            guard enabled else { return }
            selected = index
        } label: {
            Text(title)
                .font(DesignTokens.Typography.caption)
                .fontWeight(on ? .semibold : .regular)
                .foregroundStyle(enabled ? (on ? DesignTokens.Color.textPrimary : DesignTokens.Color.textSecondary) : DesignTokens.Color.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.pill, style: .continuous)
                        .fill(on ? DesignTokens.Color.surfaceCard : .clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(enabled ? title : "\(title), \(lang.sleepDetailTabSoon)")
    }
}

// MARK: - Mini bar

struct SleepDetailProgressBar: View {
    @Environment(\.colorScheme) private var colorScheme
    var progress: CGFloat
    var tint: Color

    var body: some View {
        GeometryReader { g in
            let w = max(0, min(1, progress)) * g.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(DesignTokens.Color.stroke(colorScheme).opacity(0.35))
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(tint)
                    .frame(width: w)
            }
        }
        .frame(height: 5)
        .accessibilityValue("\(Int((max(0, min(1, progress))) * 100))%")
    }
}

// MARK: - Tri-color legend

struct SleepDetailTriScale: View {
    @Environment(\.appLanguage) private var lang
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            triCell(fill: DesignTokens.Color.caution, label: lang.sleepDetailStatusAttention, sub: lang.sleepDetailScaleAttention)
            triCell(fill: DesignTokens.Color.info, label: lang.sleepDetailStatusNormal, sub: lang.sleepDetailScaleNormal)
            triCell(fill: DesignTokens.Color.positive, label: lang.sleepDetailStatusExcellent, sub: lang.sleepDetailScaleExcellent)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(DesignTokens.Color.stroke(colorScheme), lineWidth: 0.5)
        )
    }

    private func triCell(fill: Color, label: String, sub: String) -> some View {
        VStack(spacing: 4) {
            Capsule()
                .fill(fill.opacity(0.5))
                .frame(height: 6)
            Text(label)
                .font(DesignTokens.Typography.micro)
                .foregroundStyle(DesignTokens.Color.textSecondary)
            Text(sub)
                .font(DesignTokens.Typography.micro)
                .foregroundStyle(DesignTokens.Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Phase strip (% of time in bed)

struct SleepDetailPhaseStrip: View {
    @Environment(\.appLanguage) private var lang

    let awake: Double
    let rem: Double
    let core: Double
    let deep: Double

    var body: some View {
        let t = max(0.0001, awake + rem + core + deep)
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            GeometryReader { g in
                HStack(spacing: 0) {
                    seg(g.size.width * awake / t, DesignTokens.Color.sleepPhaseAwake)
                    seg(g.size.width * rem / t, DesignTokens.Color.sleepPhaseREM)
                    seg(g.size.width * core / t, DesignTokens.Color.sleepPhaseCore)
                    seg(g.size.width * deep / t, DesignTokens.Color.sleepPhaseDeep)
                }
            }
            .frame(height: 12)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                phaseLine(lang.sleepDetailPhaseAwake, awake / t, DesignTokens.Color.sleepPhaseAwake)
                phaseLine(lang.sleepDetailPhaseREM, rem / t, DesignTokens.Color.sleepPhaseREM)
                phaseLine(lang.sleepDetailPhaseCore, core / t, DesignTokens.Color.sleepPhaseCore)
                phaseLine(lang.sleepDetailPhaseDeep, deep / t, DesignTokens.Color.sleepPhaseDeep)
            }
        }
    }

    private func seg(_ w: CGFloat, _ c: Color) -> some View {
        Group {
            if w > 0.5 {
                Rectangle()
                    .fill(c)
                    .frame(width: w)
            }
        }
    }

    private func phaseLine(_ name: String, _ frac: Double, _ dot: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Circle().fill(dot).frame(width: 6, height: 6)
                Text(name)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.textPrimary)
            }
            Text("\(Int(frac * 100))%")
                .font(DesignTokens.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(DesignTokens.Color.textSecondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Sheet

enum SleepDetailSheetKind: String, Identifiable {
    case total, restorative, continuity, efficiency, regularity
    var id: String { rawValue }
}

struct SleepDetailMetricSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var lang
    @Environment(\.colorScheme) private var colorScheme

    let kind: SleepDetailSheetKind
    let scoreForScale: Int

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    Text("\(max(0, min(100, scoreForScale))) / 100")
                        .font(DesignTokens.Typography.displayTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(DesignTokens.Color.textPrimary)
                        .frame(maxWidth: .infinity)
                    SleepDetailProgressBar(
                        progress: CGFloat(max(0, min(100, scoreForScale))) / 100,
                        tint: DesignTokens.Color.info
                    )
                    .frame(height: 8)
                    Text(sheetCopy)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    SleepDetailTriScale()
                }
                .padding(DesignTokens.Spacing.lg)
            }
            .background(DesignTokens.Color.surfaceSheet)
            .navigationTitle(sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
    }

    private var sheetTitle: String {
        switch kind {
        case .total: return lang.sleepDetailSheetTotalTitle
        case .restorative: return lang.sleepDetailSheetRestorativeTitle
        case .continuity: return lang.sleepDetailSheetContinuityTitle
        case .efficiency: return lang.sleepDetailSheetEfficiencyTitle
        case .regularity: return lang.sleepDetailSheetRegularityTitle
        }
    }

    private var sheetCopy: String {
        switch kind {
        case .total: return lang.sleepDetailSheetTotalBody
        case .restorative: return lang.sleepDetailSheetRestorativeBody
        case .continuity: return lang.sleepDetailSheetContinuityBody
        case .efficiency: return lang.sleepDetailSheetEfficiencyBody
        case .regularity: return lang.sleepDetailSheetRegularityBody
        }
    }
}
