# Implementation Plan: Body Metrics Onboarding

## Overview

Incrementally add body metrics (weight/height) collection to the onboarding flow, persist them in UserProfile, expose editing in Profile, and use BMI to adjust workout generation. Each task builds on the previous, ending with full integration and wiring.

## Tasks

- [x] 1. Create foundational models and pure utility functions
  - [x] 1.1 Create `Models/UnitPreference.swift` with the `UnitPreference` enum (`metric`, `imperial`), conforming to `String, Codable, CaseIterable`
    - _Requirements: 2.3, 6.4_

  - [x] 1.2 Create `Core/UnitConverter.swift` with static pure functions: `kgToLbs`, `lbsToKg`, `cmToFeetInches`, `feetInchesToCm`, and `defaultPreference(for:)` using `Locale.current`
    - _Requirements: 6.1, 6.2, 6.3, 6.5, 6.6_

  - [x] 1.3 Add `weightKg: Double?`, `heightCm: Double?`, and `unitPreference: UnitPreference?` properties to `UserProfile` in `Models/UserProfile.swift`, with nil defaults and updated `init`
    - _Requirements: 2.1, 2.2, 2.3_

  - [x] 1.4 Add BMI static functions to `WorkoutEngine`: `calculateBMI(weightKg:heightCm:)`, `bmiCategory(bmi:)`, and `adjustedSetsReps(baseSets:baseReps:bmiCategory:)`. Add the `BMICategory` enum
    - _Requirements: 4.1, 4.2_

  - [ ]* 1.5 Write property test for weight conversion round-trip in `Tests/PropertyTests/UnitConversionPropertyTests.swift`
    - **Property 1: Weight conversion round-trip**
    - **Validates: Requirements 6.5, 1.4, 3.5**

  - [ ]* 1.6 Write property test for height conversion round-trip in `Tests/PropertyTests/UnitConversionPropertyTests.swift`
    - **Property 2: Height conversion round-trip**
    - **Validates: Requirements 6.6, 1.4, 3.5**

  - [ ]* 1.7 Write property test for BMI formula correctness in `Tests/PropertyTests/BMIPropertyTests.swift`
    - **Property 5: BMI formula correctness**
    - **Validates: Requirements 4.1**

  - [ ]* 1.8 Write unit tests for `UnitConverter` in `Tests/UnitTests/UnitConverterTests.swift`
    - Test locale detection (US → imperial, FR → metric, fallback → metric)
    - Test edge cases for conversion functions
    - _Requirements: 6.1, 6.5, 6.6_

  - [ ]* 1.9 Write unit tests for BMI calculation in `Tests/UnitTests/BMICalculationTests.swift`
    - Test height = 0 returns 0, boundary values for each BMI category, `adjustedSetsReps` output per category
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

- [x] 2. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 3. Implement HealthKit body metrics queries
  - [x] 3.1 Modify `Core/HealthKitManager.swift`: add `HKQuantityType(.bodyMass)` and `HKQuantityType(.height)` to the `readTypes` set in `requestAuthorization()`
    - _Requirements: 5.6_

  - [x] 3.2 Add `queryLatestWeight() async -> Double?` and `queryLatestHeight() async -> Double?` methods to `HealthKitManager`, returning values in kg and cm respectively
    - _Requirements: 5.1, 5.2, 5.5_

- [x] 4. Implement body metrics onboarding step
  - [x] 4.1 Update `OnboardingStep` enum in `OnboardingViewModel.swift`: add `.bodyMetrics` case with raw value 2, shift `.health` to raw value 3
    - _Requirements: 1.1, 1.7_

  - [x] 4.2 Add body metrics properties to `OnboardingViewModel`: `weightInput`, `heightInput`, `heightFeetInput`, `heightInchesInput`, `unitPreference`, `isHealthKitMetricsLoaded`, `healthKitMetricsLabel`, `canProceedFromBodyMetrics`
    - _Requirements: 1.2, 1.5_

  - [x] 4.3 Add `loadHealthKitMetrics()` and `switchUnitPreference(_:)` methods to `OnboardingViewModel`. Update `completeOnboarding()` to save weight, height, and unit preference to `UserProfile`
    - _Requirements: 1.4, 1.6, 2.4, 2.5, 5.1, 5.2, 5.3_

  - [x] 4.4 Add the `bodyMetricsStepView` to `OnboardingView.swift`: weight/height input fields, unit segmented control, HealthKit import label, back/continue buttons. Wire the new `.bodyMetrics` case in the view's switch statement
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 5.3, 5.4_

  - [ ]* 4.5 Write property test for body metrics validation rejects invalid inputs in `Tests/PropertyTests/UnitConversionPropertyTests.swift`
    - **Property 3: Body metrics validation rejects invalid inputs**
    - **Validates: Requirements 1.5, 3.6**

  - [ ]* 4.6 Write property test for imperial inputs stored as correct metric equivalents in `Tests/PropertyTests/UnitConversionPropertyTests.swift`
    - **Property 4: Imperial inputs stored as correct metric equivalents**
    - **Validates: Requirements 2.1, 2.2, 2.5**

  - [ ]* 4.7 Write unit tests for onboarding step ordering in `Tests/UnitTests/OnboardingStepTests.swift`
    - Verify `.bodyMetrics` is at index 2, `.health` at index 3, `allCases.count == 4`
    - _Requirements: 1.1, 1.7_

- [x] 5. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Implement BMI-based workout personalization
  - [x] 6.1 Add `generateWeeklyPlan(goal:weightKg:heightCm:)` overload to `WorkoutEngine` that calculates BMI and adjusts distribution and sets/reps. Preserve existing `generateWeeklyPlan(goal:)` as fallback for nil metrics
    - _Requirements: 4.2, 4.3, 4.4, 4.5, 4.6_

  - [x] 6.2 Update `adjustedWorkout(scheduledType:recoveryScore:exercises:)` in `WorkoutEngine` to accept optional `bmiCategory` parameter and apply sets/reps modifiers from the BMI adjustments table
    - _Requirements: 4.2, 4.3, 4.4_

  - [ ]* 6.3 Write property test for BMI category workout adjustments in `Tests/PropertyTests/BMIPropertyTests.swift`
    - **Property 6: BMI category determines correct workout adjustments**
    - **Validates: Requirements 4.2, 4.3, 4.4, 4.5**

- [x] 7. Implement body metrics editing in Profile screen
  - [x] 7.1 Add body metrics properties to `ProfileViewModel`: `weightDisplay`, `heightDisplay`, `unitPreference`, `isEditingBodyMetrics`, `bodyMetricsValidationError`. Add `updateBodyMetrics(...)` and `switchUnitPreference(_:)` methods. `updateBodyMetrics` must validate, convert, persist, and trigger `generateWeeklyPlan` re-evaluation
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

  - [x] 7.2 Add a body metrics section to `ProfileView.swift` with inline editing for weight and height, unit preference picker, validation error display, and save action
    - _Requirements: 3.1, 3.2, 3.5, 3.6_

  - [ ]* 7.3 Write property test for body metrics persistence round-trip in `Tests/PropertyTests/BodyMetricsPersistencePropertyTests.swift`
    - **Property 7: Body metrics persistence round-trip**
    - **Validates: Requirements 2.4, 3.3**

  - [ ]* 7.4 Write property test for unit preference persistence round-trip in `Tests/PropertyTests/BodyMetricsPersistencePropertyTests.swift`
    - **Property 8: Unit preference persistence round-trip**
    - **Validates: Requirements 6.4**

  - [ ]* 7.5 Write unit tests for body metrics validation in `Tests/UnitTests/BodyMetricsValidationTests.swift`
    - Test empty string, whitespace, negative numbers, zero, non-numeric strings all rejected; valid values accepted
    - _Requirements: 1.5, 3.6_

- [x] 8. Wire everything together in ContentView
  - [x] 8.1 Update `ContentView.swift`: pass `weightKg` and `heightCm` from `userProfile` to `WorkoutEngine.generateWeeklyPlan(goal:weightKg:heightCm:)` in `checkWeeklyPlanRegeneration()` and `checkOnboarding()`. Ensure `WorkoutViewModel` receives BMI context for `adjustedWorkout`
    - _Requirements: 4.1, 4.6_

  - [x] 8.2 Update `OnboardingView` instantiation in `ContentView` to pass any new dependencies needed by the body metrics step
    - _Requirements: 1.1, 5.1_

- [x] 9. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Property tests use SwiftCheck as specified in the design document
- Checkpoints ensure incremental validation
- All body metrics are stored internally in metric units (kg, cm); conversion happens only at the display boundary
