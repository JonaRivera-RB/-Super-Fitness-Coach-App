//
//  OnboardingView.swift
//  Super Fitness Coach App
//

import SwiftUI

struct OnboardingView: View {
    @Bindable var viewModel: OnboardingViewModel
    var onComplete: @MainActor () -> Void

    var body: some View {
        VStack {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                    Capsule()
                        .fill(step.rawValue <= viewModel.currentStep.rawValue ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal)
            .padding(.top)

            Spacer()

            switch viewModel.currentStep {
            case .health:
                healthStepView
            case .name:
                nameStepView
            case .goal:
                goalStepView
            case .bodyMetrics:
                bodyMetricsStepView
            case .sleepSchedule:
                sleepScheduleStepView
            }

            Spacer()
        }
        .animation(.easeInOut, value: viewModel.currentStep)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }

    // MARK: - Screen 1: Name Entry

    private var nameStepView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)

            Text("What's your name?")
                .font(.title)
                .fontWeight(.bold)

            TextField("Enter your name", text: $viewModel.userName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 40)
                .textContentType(.givenName)
                .submitLabel(.next)
                .onSubmit {
                    if viewModel.canProceedFromName {
                        viewModel.nextStep()
                    }
                }

            HStack(spacing: 16) {
                Button {
                    viewModel.previousStep()
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    viewModel.nextStep()
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.canProceedFromName)
            }
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Screen 2: Fitness Goal Selection

    private var goalStepView: some View {
        VStack(spacing: 24) {
            Image(systemName: "target")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)

            Text("What's your goal?")
                .font(.title)
                .fontWeight(.bold)

            VStack(spacing: 12) {
                ForEach(FitnessGoal.allCases, id: \.rawValue) { goal in
                    Button {
                        viewModel.selectedGoal = goal
                    } label: {
                        HStack {
                            Image(systemName: iconName(for: goal))
                            Text(goal.rawValue)
                                .fontWeight(.medium)
                            Spacer()
                            if viewModel.selectedGoal == goal {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(viewModel.selectedGoal == goal ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(viewModel.selectedGoal == goal ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(goal.rawValue)\(viewModel.selectedGoal == goal ? ", selected" : "")")
                }
            }
            .padding(.horizontal, 40)

            HStack(spacing: 16) {
                Button {
                    viewModel.previousStep()
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    viewModel.nextStep()
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Screen 3: Body Metrics

    private var bodyMetricsStepView: some View {
        ScrollView {
            VStack(spacing: 24) {
            Image(systemName: "scalemass.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)

            Text("Your Body Metrics")
                .font(.title)
                .fontWeight(.bold)

            Text("We use your weight and height to personalize workout intensity and recommendations.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Picker("Unit", selection: Binding(
                get: { viewModel.unitPreference },
                set: { viewModel.switchUnitPreference($0) }
            )) {
                Text("Metric").tag(UnitPreference.metric)
                Text("Imperial").tag(UnitPreference.imperial)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 40)

            VStack(spacing: 12) {
                TextField(
                    viewModel.unitPreference == .metric ? "Weight (kg)" : "Weight (lbs)",
                    text: $viewModel.weightInput
                )
                .textFieldStyle(.roundedBorder)
                .keyboardType(.decimalPad)
                .accessibilityLabel(viewModel.unitPreference == .metric ? "Weight in kilograms" : "Weight in pounds")

                if viewModel.unitPreference == .metric {
                    TextField("Height (cm)", text: $viewModel.heightInput)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Height in centimeters")
                } else {
                    HStack(spacing: 12) {
                        TextField("Feet", text: $viewModel.heightFeetInput)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .accessibilityLabel("Height feet")
                        TextField("Inches", text: $viewModel.heightInchesInput)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.decimalPad)
                            .accessibilityLabel("Height inches")
                    }
                }
            }
            .padding(.horizontal, 40)

            if let label = viewModel.healthKitMetricsLabel {
                Label(label, systemImage: "heart.fill")
                    .foregroundStyle(.pink)
            }

            HStack(spacing: 16) {
                Button {
                    viewModel.previousStep()
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    viewModel.nextStep()
                } label: {
                    HStack {
                        Text("Continue")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.canProceedFromBodyMetrics)
            }
            .padding(.horizontal, 40)
            }
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .task {
            await viewModel.loadHealthKitMetrics()
        }
    }

    // MARK: - Screen 4: Apple Health Connection

    private var healthStepView: some View {
        VStack(spacing: 24) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.pink)

            Text("Connect Apple Health")
                .font(.title)
                .fontWeight(.bold)

            Text("We use your sleep, heart rate, steps, and activity data to calculate your daily recovery score.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if let result = viewModel.healthConnectionResult {
                Label(
                    result == "connected" ? "Health data connected" : "Using default recovery score",
                    systemImage: result == "connected" ? "checkmark.circle.fill" : "info.circle.fill"
                )
                .foregroundStyle(result == "connected" ? .green : .orange)
            }

            VStack(spacing: 12) {
                if viewModel.healthConnectionResult == nil {
                    Button {
                        Task {
                            await viewModel.connectHealthKit()
                        }
                    } label: {
                        HStack {
                            if viewModel.isRequestingHealth {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("Connect Health")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(viewModel.isRequestingHealth)

                    Button {
                        viewModel.healthConnectionResult = "denied"
                    } label: {
                        Text("Skip for now")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                if viewModel.healthConnectionResult != nil {
                    Button {
                        viewModel.nextStep()
                    } label: {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Screen 5: Sleep Schedule (Optional)

    private var sleepScheduleStepView: some View {
        VStack(spacing: 18) {
            Image(systemName: "bed.double.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)

            Text("Sleep Schedule (Optional)")
                .font(.title)
                .fontWeight(.bold)

            Text("Set your usual bedtime and wake time so we can pick the right sleep session and improve recovery accuracy.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Toggle("Enable sleep schedule", isOn: $viewModel.sleepScheduleEnabled)
                .padding(.horizontal, 40)

            if viewModel.sleepScheduleEnabled {
                VStack(spacing: 12) {
                    HStack {
                        Text("Bedtime")
                        Spacer()
                        DatePicker("", selection: $viewModel.sleepBedtime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    HStack {
                        Text("Wake")
                        Spacer()
                        DatePicker("", selection: $viewModel.sleepWakeTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    HStack {
                        Text("Buffer")
                        Spacer()
                        Stepper("\(viewModel.sleepBufferMinutes) min", value: $viewModel.sleepBufferMinutes, in: 0...180, step: 5)
                            .labelsHidden()
                        Text("\(viewModel.sleepBufferMinutes) min")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 40)
            }

            HStack(spacing: 16) {
                Button {
                    viewModel.previousStep()
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    Task {
                        await viewModel.completeOnboarding()
                        if viewModel.completionError == nil {
                            await MainActor.run {
                                onComplete()
                            }
                        }
                    }
                } label: {
                    HStack {
                        if viewModel.isCompleting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Get Started")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.isCompleting)
            }
            .padding(.horizontal, 40)

            Button {
                // Skip: disable schedule and finish onboarding.
                viewModel.sleepScheduleEnabled = false
                Task {
                    await viewModel.completeOnboarding()
                    if viewModel.completionError == nil {
                        await MainActor.run {
                            onComplete()
                        }
                    }
                }
            } label: {
                Text("Skip for now")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 6)

            if let err = viewModel.completionError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Helpers

    private func iconName(for goal: FitnessGoal) -> String {
        switch goal {
        case .loseWeight: return "flame.fill"
        case .gainMuscle: return "dumbbell.fill"
        case .beHealthy: return "heart.fill"
        }
    }
}
