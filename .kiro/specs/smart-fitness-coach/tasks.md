# Implementation Plan: Smart Fitness Coach

## Overview

Refactor the HealthKit scoring system into a competition-grade fitness scoring engine with separated Recovery/Activity scores, HRV support, percentage-based HR scoring, weighted sleep quality, real HealthKit authorization, proper absent-data handling via `HealthDataStatus`, explainable `ScoreBreakdown`, user-goal normalization via `FitnessConfig`, and WorkoutEngine/AICoach integration. All scoring logic is implemented as static pure functions for testability.

## Tasks

- [x] 1. Create new model types and enums
  - [x] 1.1 Create `HealthDataStatus` enum in `Super Fitness Coach App/Models/HealthDataStatus.swift`
    - Implement generic enum with cases `.available(T)`, `.unavailable`, `.loading`
    - Add computed properties `value: T?` and `isAvailable: Bool`
    - _Requirements: 7.1, 7.2_

  - [x] 1.2 Create `AuthorizationStatus` enum in `Super Fitness Coach App/Models/AuthorizationStatus.swift`
    - Implement enum with cases `.notDetermined`, `.authorized`, `.denied`, `.unavailable`
    - Conform to `String, Codable`
    - _Requirements: 6.1_

  - [x] 1.3 Create `FitnessLevel` enum and `FitnessConfig` struct in `Super Fitness Coach App/Models/FitnessConfig.swift`
    - `FitnessLevel`: enum with `beginner`, `intermediate`, `advanced`, conforming to `String, Codable, CaseIterable`
    - `FitnessConfig`: struct with `sleepGoalHours`, `stepsGoal`, `calorieGoal`, `baselineRestingHR`, `fitnessLevel`
    - Add `static let default` with standard health values (8.0, 10000, 500, 70, .beginner)
    - Add `isValid` computed property with range validation
    - _Requirements: 1.1, 1.2, 1.4_

  - [x] 1.4 Create `ScoreBreakdown` struct in `Super Fitness Coach App/Models/ScoreBreakdown.swift`
    - Implement `ScoreBreakdown` with `components: [ScoreComponent]` and `finalScore: Int`
    - Implement nested `ScoreComponent` with `name`, `rawValue`, `rawUnit`, `normalizedScore`, `weight`, `contribution`, `description`, `status`
    - Implement `ComponentStatus` enum with `.normal`, `.warning` (< 40), `.good` (>= 70)
    - _Requirements: 8.1, 8.4, 8.5_

  - [x] 1.5 Extend `UserProfile` with `fitnessConfig` property
    - Add `var fitnessConfig: FitnessConfig?` to `UserProfile`
    - Add `var effectiveFitnessConfig: FitnessConfig` computed property returning `fitnessConfig ?? .default`
    - Existing profiles with `nil` use defaults — no migration needed
    - _Requirements: 1.1, 1.2_

- [x] 2. Checkpoint — Verify model types compile
  - Ensure all new model files compile, ask the user if questions arise.

- [ ] 3. Refactor HealthKitManager static scoring functions
  - [x] 3.1 Add normalization static functions to `HealthKitManager`
    - Implement `normalizeSteps(actual:goal:) -> Double` — `clamp(0, 100, actual/goal × 100)`
    - Implement `normalizeCalories(actual:goal:) -> Double` — same formula
    - Implement `normalizeSleepDuration(actual:goal:) -> Double` — same formula
    - Implement `normalizeRestingHR(actual:baseline:) -> Double` — percentage-based with factor 2.5
    - Implement `normalizeHRV(milliseconds:) -> Double` — linear 20ms→0, 100ms→100
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 10.1, 10.2, 10.3, 10.4, 10.5, 10.6_

  - [x] 3.2 Add sleep quality scoring static function
    - Implement `calculateSleepQualityScore(totalHours:deepHours:remHours:sleepGoal:) -> Double`
    - Duration weight 0.50, deep 0.25, REM 0.25; fallback to duration-only when deep/REM are nil
    - Expected deep % = 0.175, expected REM % = 0.225
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_

  - [x] 3.3 Add separated score calculation static functions
    - Implement `calculateRecoveryScore(sleepQualityScore:restingHRScore:hrvScore:) -> Int` — weights 0.45/0.25/0.30, fallback 0.60/0.40 when HRV nil
    - Implement `calculateActivityScore(stepsScore:caloriesScore:) -> Int` — weights 0.50/0.50
    - Implement `redistributeWeights(availableComponents:originalWeights:) -> [String: Double]`
    - _Requirements: 2.1, 2.2, 2.6, 2.7, 3.4, 7.4, 7.6_

  - [x] 3.4 Add ScoreBreakdown builder static functions
    - Implement `buildRecoveryBreakdown(...)` with sleep, HR, HRV components
    - Implement `buildActivityBreakdown(...)` with steps, calories components
    - Set `ComponentStatus` based on normalizedScore thresholds
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

  - [ ]* 3.5 Write property tests for normalization functions (NormalizationPropertyTests.swift)
    - **Property 12: Normalization bounded to [0, 100]** — for all positive actual/goal, normalizeSteps/Calories/SleepDuration return Double in [0, 100]
    - **Validates: Requirements 10.1, 10.2, 10.3, 10.4, 10.5**

  - [ ]* 3.6 Write property test for normalization identity at goal
    - **Property 13: Identity at goal** — for all positive goal, normalize(goal, goal) == 100.0
    - **Validates: Requirements 10.6**

  - [ ]* 3.7 Write property test for FitnessConfig validation
    - **Property 1: FitnessConfig validation** — isValid iff all fields in valid ranges
    - **Validates: Requirements 1.4**

  - [ ]* 3.8 Write property test for HRV normalization
    - **Property 4: HRV normalization** — linear interpolation 20ms→0, 100ms→100, clamped [0, 100]
    - **Validates: Requirements 3.3**

  - [ ]* 3.9 Write property test for resting HR normalization
    - **Property 6: HR vs baseline** — percentage-based formula with factor 2.5, clamped [0, 100]
    - **Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5**

  - [ ]* 3.10 Write property test for sleep quality score
    - **Property 7: Sleep quality weighted formula** — duration 0.50 + deep 0.25 + REM 0.25, bounded [0, 100]
    - **Validates: Requirements 5.1, 5.2, 5.3, 5.4, 5.6**

  - [ ]* 3.11 Write property test for sleep quality without phases
    - **Property 8: Sleep quality without phases** — falls back to duration-only score
    - **Validates: Requirements 5.5**

  - [ ]* 3.12 Write property test for recovery score formula
    - **Property 2: Recovery score bounded** — weighted sum with 0.45/0.25/0.30, result in [0, 100]
    - **Validates: Requirements 2.1, 2.6**

  - [ ]* 3.13 Write property test for activity score formula
    - **Property 3: Activity score bounded** — weighted sum with 0.50/0.50, result in [0, 100]
    - **Validates: Requirements 2.2, 2.7**

  - [ ]* 3.14 Write property test for recovery score without HRV
    - **Property 5: Recovery without HRV** — fallback weights 0.60/0.40, result in [0, 100]
    - **Validates: Requirements 3.4**

  - [ ]* 3.15 Write property test for weight redistribution
    - **Property 9: Redistributed weights sum to 1.0** — for all non-empty subsets, sum == 1.0 (ε = 0.0001)
    - **Validates: Requirements 7.4, 7.6**

  - [ ]* 3.16 Write property test for ScoreBreakdown contributions
    - **Property 10: Breakdown contributions sum to finalScore** — and status thresholds correct
    - **Validates: Requirements 8.1, 8.4, 8.5**

- [x] 4. Checkpoint — Verify scoring functions compile and tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Refactor HealthKitManager instance methods
  - [x] 5.1 Replace observable properties with `HealthDataStatus` and `AuthorizationStatus`
    - Replace `recoveryScore: Int` with `recoveryScore: HealthDataStatus<Int>`
    - Replace `activityScore` (new), `sleepHours`, `deepSleepHours` (new), `remSleepHours` (new), `restingHR`, `hrv` (new), `stepCount`, `activeEnergy` with `HealthDataStatus<Double>`
    - Replace `isAuthorized: Bool` with `authorizationStatus: AuthorizationStatus`
    - Add `recoveryBreakdown: ScoreBreakdown?` and `activityBreakdown: ScoreBreakdown?`
    - _Requirements: 6.1, 7.1_

  - [x] 5.2 Implement real authorization flow
    - Add `verifyAuthorization() async` that performs a test query to stepCount
    - Update `requestAuthorization()` to include `heartRateVariabilitySDNN` in read types
    - Remove `checkExistingAuthorization()` method
    - Set `.authorized`, `.denied`, or `.unavailable` based on test query result
    - _Requirements: 6.2, 6.3, 6.4, 6.5, 6.6, 3.1_

  - [x] 5.3 Implement `refreshHealthData(config: FitnessConfig) async`
    - Query sleep (total + deep + REM phases separately), resting HR, HRV, steps, calories
    - Map each query result to `HealthDataStatus.available(value)` or `.unavailable`
    - Calculate recovery and activity scores using static functions and config goals
    - Build breakdowns via `buildRecoveryBreakdown` / `buildActivityBreakdown`
    - Handle all-unavailable case: set score to `.unavailable`
    - _Requirements: 2.4, 2.5, 3.2, 7.2, 7.3, 7.4, 7.5_

- [ ] 6. Update WorkoutEngine for FitnessLevel
  - [x] 6.1 Add `adjustedForFitnessLevel(baseSets:baseReps:level:) -> (sets: Int, reps: Int)` static function
    - `beginner` reduces intensity, `intermediate` keeps base, `advanced` increases intensity
    - All returned values >= 1
    - _Requirements: 1.5_

  - [ ]* 6.2 Write property test for fitness level adjustment
    - **Property 14: FitnessLevel adjusts intensity** — beginner < base, intermediate == base, advanced > base, all >= 1
    - **Validates: Requirements 1.5**

  - [ ]* 6.3 Write property test for workout adjustment thresholds
    - **Property 11: Workout adjustment by recovery score** — < 40 replaceWithLight, 40-69 reduceSets, >= 70 noChange (strength only)
    - **Validates: Requirements 9.2, 9.3, 9.4**

- [ ] 7. Update AICoach signature
  - [x] 7.1 Update `AICoach.generateMessage` to accept both `recoveryScore` and `activityScore`
    - Add `activityScore: Int` parameter
    - Update message logic to reference both scores where appropriate
    - _Requirements: 9.5_

- [x] 8. Checkpoint — Verify core logic compiles and tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 9. Update ViewModels
  - [x] 9.1 Refactor `HomeViewModel` for separated scores
    - Expose `recoveryScore` and `activityScore` as `HealthDataStatus<Int>`
    - Expose `recoveryBreakdown` and `activityBreakdown` as `ScoreBreakdown?`
    - Read `FitnessConfig` from `UserProfile` via `UserProfileRepository` and pass to `refreshHealthData(config:)`
    - Update `StatusIndicator` to use recovery score value
    - Update `AICoach.generateMessage` call with both scores
    - Pass `recoveryScore` (extracted from HealthDataStatus) to `WorkoutEngine.adjustmentAction`
    - _Requirements: 2.3, 2.4, 2.5, 9.1_

  - [x] 9.2 Refactor `ProfileViewModel` for FitnessConfig editing
    - Add editable fields: `sleepGoalHours`, `stepsGoal`, `calorieGoal`, `baselineRestingHR`, `fitnessLevel`
    - Load from `UserProfile.effectiveFitnessConfig` on init
    - Validate with `FitnessConfig.isValid` before saving
    - Persist to `UserProfile.fitnessConfig` via repository
    - Trigger score recalculation after save
    - Replace `isHealthKitAuthorized: Bool` with `AuthorizationStatus` usage
    - _Requirements: 1.3, 1.4, 6.7_

- [x] 10. Update Views
  - [x] 10.1 Update `HomeView` for separated scores and HealthDataStatus
    - Show Recovery Score and Activity Score as two separate sections
    - Handle `.loading` (show ProgressView), `.unavailable` (show "--"), `.available` (show value)
    - Display `ScoreBreakdown` components with warning/good indicators
    - Show authorization banner when `.denied` or `.unavailable`
    - _Requirements: 2.3, 6.7, 7.3, 8.2, 8.3, 8.4_

  - [x] 10.2 Update `ProfileView` with FitnessConfig editing section
    - Add "Fitness Goals" section with fields for sleep goal, steps goal, calorie goal, baseline HR, fitness level
    - Show validation errors for out-of-range values
    - Add save/cancel flow similar to body metrics editing
    - _Requirements: 1.3, 1.4_

  - [x] 10.3 Update `ContentView` to pass `UserProfileRepository` to `HomeViewModel`
    - Ensure `HomeViewModel` can read `FitnessConfig` for score calculation
    - Update `WorkoutViewModel` creation to extract recovery score from `HealthDataStatus`
    - _Requirements: 2.4, 2.5_

- [x] 11. Update existing unit tests
  - [x] 11.1 Update `HealthKitManagerTests.swift` for new static function signatures
    - Replace old `calculateRecoveryScore(sleepHours:restingHR:stepCount:activeEnergy:)` tests
    - Add tests for new `calculateRecoveryScore`, `calculateActivityScore`, `calculateSleepQualityScore`
    - Add tests for `normalizeRestingHR`, `normalizeHRV`, `normalizeSteps`, `normalizeCalories`
    - Add edge case tests: all unavailable, boundary values, perfect scores
    - _Requirements: 2.1, 2.2, 4.1, 5.1, 10.1_

  - [ ]* 11.2 Create `FitnessConfigTests.swift` with unit tests
    - Test `isValid` with valid and invalid configs
    - Test `effectiveFitnessConfig` returns default when nil
    - Test boundary values for each field
    - _Requirements: 1.1, 1.2, 1.4_

  - [ ]* 11.3 Create `ScoreBreakdownTests.swift` with unit tests
    - Test `buildRecoveryBreakdown` produces correct component count and values
    - Test `ComponentStatus` thresholds (< 40 warning, >= 70 good)
    - _Requirements: 8.1, 8.4, 8.5_

  - [ ]* 11.4 Create `WorkoutAdjustmentTests.swift` with unit tests
    - Test `adjustedForFitnessLevel` for each level
    - Test `adjustmentAction` thresholds with recovery score
    - _Requirements: 1.5, 9.2, 9.3, 9.4_

- [x] 12. Final checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document (14 properties total)
- Unit tests validate specific examples and edge cases
- All scoring logic is in static pure functions — testable without HealthKit or SwiftData
- SwiftCheck is used for property-based tests with minimum 100 iterations each
