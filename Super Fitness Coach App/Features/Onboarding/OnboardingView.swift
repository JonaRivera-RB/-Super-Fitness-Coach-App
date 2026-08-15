//
//  OnboardingView.swift
//  Super Fitness Coach App
//
//  Onboarding simplificado en 3 pasos (dirección 1b):
//    1. Tú        — nombre + objetivo
//    2. Tu cuerpo — Apple Health + medidas (fusiona los antiguos pasos health y bodyMetrics)
//    3. Listo     — resumen editable + sueño opcional
//
//  Estructura común a los tres pasos: fila de progreso con chevron, contenido
//  scrollable alineado a la izquierda, y una barra inferior fija con el CTA que
//  nunca se mueve entre pasos.
//

import SwiftUI

struct OnboardingView: View {
    @Bindable var viewModel: OnboardingViewModel
    var onComplete: @MainActor () -> Void

    @Environment(\.appLanguage) private var lang
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            progressRow

            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.blockGap) {
                    switch viewModel.currentStep {
                    case .you:  youStepContent
                    case .body: bodyStepContent
                    case .done: doneStepContent
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignTokens.Spacing.screenH)
                .padding(.top, DesignTokens.Spacing.xl)
                .padding(.bottom, DesignTokens.Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)

            bottomBar
        }
        .background(DesignTokens.Color.backgroundPrimary.ignoresSafeArea())
        .animation(.easeInOut, value: viewModel.currentStep)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(lang.onboardingKeyboardDone) {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }

    // MARK: - Barra de progreso

    private var progressRow: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.previousStep()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .regular))
                    .frame(width: Metrics.chevronSlot, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .disabled(viewModel.currentStep == .you)
            .foregroundStyle(viewModel.currentStep == .you
                             ? DesignTokens.Color.textTertiary
                             : Color.accentColor)
            .accessibilityLabel(lang.onboardingBack)

            HStack(spacing: 6) {
                ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                    Capsule()
                        .fill(step.rawValue <= viewModel.currentStep.rawValue
                              ? Color.accentColor
                              : Color(.systemGray).opacity(0.25))
                        .frame(height: 3)
                }
            }

            // Contrapeso del chevron para que las cápsulas queden centradas.
            Color.clear.frame(width: Metrics.chevronSlot, height: 1)
        }
        .padding(.horizontal, DesignTokens.Spacing.screenH)
        .padding(.top, 6)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Barra inferior (fuera del scroll)

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 10) {
            switch viewModel.currentStep {
            case .you:
                primaryButton(lang.onboardingContinue, isEnabled: viewModel.canProceed) {
                    isNameFocused = false
                    viewModel.nextStep()
                }

            case .body:
                primaryButton(lang.onboardingContinue) {
                    viewModel.nextStep()
                }
                Button {
                    viewModel.skipBodyMetrics()
                } label: {
                    Text(lang.onboardingLater)
                        .font(.subheadline)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

            case .done:
                if let error = viewModel.completionError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(DesignTokens.Color.destructive)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                primaryButton(
                    lang.onboardingStart,
                    tint: DesignTokens.Color.positive,
                    isLoading: viewModel.isCompleting
                ) {
                    Task {
                        await viewModel.completeOnboarding()
                        if viewModel.completionError == nil {
                            onComplete()
                        }
                    }
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.screenH)
        .padding(.top, DesignTokens.Spacing.md)
        .padding(.bottom, 30)
    }

    // MARK: - Paso 1: Tú

    private var youStepContent: some View {
        Group {
            stepHeader(step: 1, title: lang.onboardingYouTitle)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                sectionCaption(lang.onboardingNameCaption)

                TextField(lang.onboardingNamePlaceholder, text: $viewModel.userName)
                    .font(.system(size: 20))
                    .textContentType(.givenName)
                    .submitLabel(.next)
                    .focused($isNameFocused)
                    .onSubmit {
                        if viewModel.canProceed { viewModel.nextStep() }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: Metrics.rowRadius, style: .continuous)
                            .fill(DesignTokens.Color.surfaceCard)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Metrics.rowRadius, style: .continuous)
                            .stroke(isNameFocused ? Color.accentColor : Color.clear, lineWidth: 1.5)
                    )
                    .animation(DesignTokens.Motion.quick, value: isNameFocused)
                    .task {
                        // El foco inmediato al aparecer no se aplica de forma
                        // fiable en SwiftUI; un ciclo corto después del render sí.
                        try? await Task.sleep(for: .milliseconds(350))
                        isNameFocused = true
                    }
            }

            VStack(alignment: .leading, spacing: 10) {
                sectionCaption(lang.onboardingGoalCaption)

                VStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(FitnessGoal.allCases, id: \.rawValue) { goal in
                        goalRow(goal)
                    }
                }
            }
        }
    }

    private func goalRow(_ goal: FitnessGoal) -> some View {
        let isSelected = viewModel.selectedGoal == goal

        return Button {
            viewModel.selectedGoal = goal
        } label: {
            HStack(spacing: 12) {
                Image(systemName: iconName(for: goal))
                    .frame(width: 22)
                    .foregroundStyle(isSelected ? Color.accentColor : DesignTokens.Color.textSecondary)

                Text(goal.onboardingLabel(lang))
                    .font(.system(size: 17, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(DesignTokens.Color.textPrimary)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 19))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: Metrics.rowRadius, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.10) : DesignTokens.Color.surfaceCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.rowRadius, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel(goal.onboardingLabel(lang))
    }

    // MARK: - Paso 2: Tu cuerpo

    private var bodyStepContent: some View {
        Group {
            stepHeader(step: 2, title: lang.onboardingBodyTitle, subtitle: lang.onboardingBodySubtitle)

            healthSection

            labeledSeparator(lang.onboardingOrTypeIt)

            VStack(alignment: .leading, spacing: 12) {
                if viewModel.isHealthKitMetricsLoaded {
                    Label(lang.onboardingHealthImported, systemImage: "heart.fill")
                        .font(.footnote)
                        .foregroundStyle(Color(.systemPink))
                }

                HStack(spacing: 12) {
                    weightField
                    heightField
                }

                Picker("", selection: Binding(
                    get: { viewModel.unitPreference },
                    set: { viewModel.switchUnitPreference($0) }
                )) {
                    Text("kg · cm").tag(UnitPreference.metric)
                    Text("lb · ft").tag(UnitPreference.imperial)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }
        }
    }

    @ViewBuilder
    private var healthSection: some View {
        if viewModel.isHealthConnected {
            // Colapsada: el permiso ya está resuelto, solo confirma el estado.
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(DesignTokens.Color.positive)
                Text(lang.onboardingHealthConnected)
                    .font(.headline)
                Spacer(minLength: 0)
            }
            .padding(DesignTokens.Spacing.md)
            .background(cardBackground(radius: DesignTokens.Radius.card))
        } else if viewModel.isHealthDenied {
            // Denegado: la tarjeta desaparece y quedan los campos manuales.
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(.systemPink))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color(.systemPink).opacity(0.12)))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(lang.onboardingHealthCardTitle)
                            .font(.headline)
                        Text(lang.onboardingHealthCardSubtitle)
                            .font(.footnote)
                            .foregroundStyle(DesignTokens.Color.textSecondary)
                    }

                    Spacer(minLength: 0)
                }

                primaryButton(
                    lang.onboardingHealthConnect,
                    isLoading: viewModel.isRequestingHealth
                ) {
                    Task {
                        await viewModel.connectHealthKit()
                        // Solo tras conceder el permiso: antes fallaba en silencio.
                        if viewModel.isHealthConnected {
                            await viewModel.loadHealthKitMetrics()
                        }
                    }
                }
            }
            .padding(18)
            .background(cardBackground(radius: DesignTokens.Radius.card))
        }
    }

    private var weightField: some View {
        metricCard(caption: lang.onboardingWeightCaption) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("0", text: $viewModel.weightInput)
                    .font(.system(size: 24, weight: .semibold))
                    .monospacedDigit()
                    .keyboardType(.decimalPad)
                    .accessibilityLabel(lang.onboardingWeightCaption)
                Text(viewModel.unitPreference == .metric ? "kg" : "lb")
                    .font(.system(size: 15))
                    .foregroundStyle(DesignTokens.Color.textSecondary)
            }
        }
    }

    private var heightField: some View {
        metricCard(caption: lang.onboardingHeightCaption) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                switch viewModel.unitPreference {
                case .metric:
                    TextField("0", text: $viewModel.heightInput)
                        .font(.system(size: 24, weight: .semibold))
                        .monospacedDigit()
                        .keyboardType(.decimalPad)
                        .accessibilityLabel(lang.onboardingHeightCaption)
                    Text("cm")
                        .font(.system(size: 15))
                        .foregroundStyle(DesignTokens.Color.textSecondary)

                case .imperial:
                    TextField("0", text: $viewModel.heightFeetInput)
                        .font(.system(size: 24, weight: .semibold))
                        .monospacedDigit()
                        .keyboardType(.numberPad)
                        .accessibilityLabel("\(lang.onboardingHeightCaption) ft")
                    Text("ft")
                        .font(.system(size: 15))
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                    TextField("0", text: $viewModel.heightInchesInput)
                        .font(.system(size: 24, weight: .semibold))
                        .monospacedDigit()
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("\(lang.onboardingHeightCaption) in")
                    Text("in")
                        .font(.system(size: 15))
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                }
            }
        }
    }

    // MARK: - Paso 3: Listo

    private var doneStepContent: some View {
        Group {
            stepHeader(
                step: 3,
                title: lang.onboardingDoneTitle(viewModel.userName.trimmingCharacters(in: .whitespacesAndNewlines)),
                subtitle: lang.onboardingDoneSubtitle
            )

            VStack(spacing: 0) {
                summaryRow(
                    icon: iconName(for: viewModel.selectedGoal),
                    text: viewModel.selectedGoal.onboardingLabel(lang)
                ) {
                    changeButton(to: .you)
                }

                Divider()

                summaryRow(
                    icon: "scalemass.fill",
                    text: viewModel.bodyMetricsSummary ?? lang.onboardingNoMetrics
                ) {
                    changeButton(to: .body)
                }

                Divider()

                summaryRow(
                    icon: "heart.fill",
                    text: viewModel.isHealthConnected ? lang.onboardingHealthConnected : lang.onboardingHealthNotConnected
                ) {
                    if viewModel.isHealthConnected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 19))
                            .foregroundStyle(DesignTokens.Color.positive)
                    } else {
                        changeButton(to: .body)
                    }
                }
            }
            .background(cardBackground(radius: DesignTokens.Radius.card))

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Toggle(isOn: $viewModel.sleepScheduleEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lang.onboardingSleepTitle)
                            .font(.headline)
                        Text("\(timeLabel(viewModel.sleepBedtime)) – \(timeLabel(viewModel.sleepWakeTime)) · \(lang.onboardingSleepAccuracy)")
                            .font(.footnote)
                            .foregroundStyle(DesignTokens.Color.textSecondary)
                    }
                }
                .padding(DesignTokens.Spacing.md)
                .background(cardBackground(radius: DesignTokens.Radius.card))

                Text(lang.onboardingSleepNote)
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.Color.textTertiary)
            }
        }
    }

    private func summaryRow<Trailing: View>(
        icon: String,
        text: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(DesignTokens.Color.textSecondary)
            Text(text)
                .font(.body)
                .foregroundStyle(DesignTokens.Color.textPrimary)
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, 14)
    }

    private func changeButton(to step: OnboardingStep) -> some View {
        Button {
            viewModel.currentStep = step
        } label: {
            Text(lang.onboardingChange)
                .font(.subheadline)
                .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Piezas compartidas

    private func stepHeader(step: Int, title: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            sectionCaption(lang.onboardingStepCaption(step))

            Text(title)
                .font(.largeTitle.bold())
                .foregroundStyle(DesignTokens.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionCaption(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .textCase(.uppercase)
            .kerning(0.6)
            .foregroundStyle(DesignTokens.Color.textTertiary)
    }

    private func labeledSeparator(_ text: String) -> some View {
        HStack(spacing: 12) {
            Rectangle().fill(Color(.separator)).frame(height: 1)
            sectionCaption(text).layoutPriority(1)
            Rectangle().fill(Color(.separator)).frame(height: 1)
        }
        .accessibilityHidden(true)
    }

    private func metricCard<Content: View>(
        caption: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            sectionCaption(caption)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(cardBackground(radius: Metrics.rowRadius))
    }

    private func cardBackground(radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(DesignTokens.Color.surfaceCard)
            .tokenShadow(.subtle)
    }

    private func primaryButton(
        _ title: String,
        tint: Color = .accentColor,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if isLoading {
                    ProgressView().tint(.white)
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(isEnabled ? Color.white : DesignTokens.Color.textTertiary)
            .background(
                RoundedRectangle(cornerRadius: Metrics.rowRadius, style: .continuous)
                    .fill(isEnabled ? tint : Color(.tertiarySystemFill))
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
    }

    // MARK: - Helpers

    private func iconName(for goal: FitnessGoal) -> String {
        switch goal {
        case .loseWeight: return "flame.fill"
        case .gainMuscle: return "dumbbell.fill"
        case .beHealthy:  return "heart.fill"
        }
    }

    private func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = .current
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private enum Metrics {
        /// Ancho del contenedor del chevron; se replica vacío a la derecha
        /// para que la barra de progreso quede centrada.
        static let chevronSlot: CGFloat = 30
        /// Radio de botones, campos y filas de opción.
        static let rowRadius: CGFloat = 12
        /// Separación entre bloques de una pantalla.
        static let blockGap: CGFloat = 26
    }
}
