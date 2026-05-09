# Requirements Document

## Introduction

HU-C2S2-021 — Sleep Window Goal Definition introduces a user-defined expected sleep window to complement HealthKit's automatic sleep detection. Instead of relying exclusively on raw HealthKit data (which can include naps, fragmented sessions, or misdetected intervals), the app will use a user-configured bedtime and wake time as a reference frame for filtering sleep sessions and calculating the daily RecoveryScore. This reduces detection errors and improves the accuracy of recovery metrics in `HealthKitManager`, `RecoveryAdapter`, and `ProgressTracker`.

## Glossary

- **SleepGoal**: A Codable struct containing `targetSleepTime` and `targetWakeTime` as `DateComponents` (hour + minute only), representing the user's intended sleep schedule.
- **SleepWindowBuilder**: The component responsible for constructing a concrete `(expectedStart, expectedEnd)` date range from a `SleepGoal` for a given reference date. Always uses `Calendar.current` to respect the user's local timezone.
- **ExpectedSleepWindow**: The concrete `(adjustedStart: Date, adjustedEnd: Date)` range derived from `SleepGoal` after applying the configurable tolerance buffer (default `bufferMinutes = 60`, range [0, 180]).
- **SleepSessionFilter**: The component that sorts, merges, filters, and selects HealthKit `HKCategorySample` sessions using the `ExpectedSleepWindow`.
- **SleepDetectionResult**: The output of session filtering, containing the selected main session, `sleepDetected: Bool`, `sleepConfidence: Double` (0.0–1.0), and `sleepConsistencyScore: Int` (0–100).
- **sleepConfidence**: A score representing the quality of the detected sleep session relative to the `ExpectedSleepWindow`. Full overlap → 1.0, partial overlap → proportional value, fallback/no session → 0.2. Used to weight the sleep contribution in RecoveryScore.
- **Adjacent sessions**: Two sleep sessions are considered adjacent if the gap between `session1.endDate` and `session2.startDate` is ≤ 10 minutes.
- **Nap**: Any sleep session that is shorter than 90 minutes OR whose overlap with the `ExpectedSleepWindow` is less than 20% of the session's total duration.
- **referenceDate**: The current calendar day at the time `refreshHealthData` is executed (`Date()` at call time).
- **UserProfile**: The existing SwiftData `@Model` that stores the user's persistent configuration, including `fitnessConfig: FitnessConfig?`.
- **FitnessConfig**: The existing `Codable` struct stored inside `UserProfile`, extended to hold the optional `SleepGoal` and `bufferMinutes`.
- **HealthKitManager**: The existing `@Observable` class that orchestrates all HealthKit queries via `refreshHealthData(config:)`.
- **RecoveryAdapter**: The existing struct that translates a `recoveryScore` into training adjustments.
- **Fallback Window**: The default `ExpectedSleepWindow` used when the user has not configured a `SleepGoal`, spanning 20:00 to 10:00 the following morning.
- **Sleep Consistency Score**: A metric (0–100) representing how closely the user's actual sleep aligns with their configured `SleepGoal` over time.

---

## Requirements

### Requirement 1: Sleep Goal Configuration

**User Story:** As a user, I want to define my expected bedtime and wake time, so that the app uses my personal schedule as a reference when detecting my sleep session.

#### Acceptance Criteria

1. THE Settings SHALL expose a sleep schedule section containing a `targetSleepTime` picker (bedtime) and a `targetWakeTime` picker (wake time).
2. WHEN the user completes onboarding, THE Onboarding SHALL present the sleep schedule section as an optional step that can be skipped.
3. WHEN the user submits a `SleepGoal` where `targetSleepTime` equals `targetWakeTime`, THE Settings SHALL display a validation error and SHALL NOT save the configuration.
4. WHEN the user submits a `SleepGoal` where the duration between `targetSleepTime` and `targetWakeTime` is less than 4 hours, THE Settings SHALL display a validation error and SHALL NOT save the configuration.
5. WHEN the user submits a valid `SleepGoal`, THE Settings SHALL save the configuration and dismiss the validation error if one was previously shown.

---

### Requirement 2: SleepGoal Persistence

**User Story:** As a user, I want my sleep schedule to be remembered across app launches, so that I do not have to re-enter it every time I open the app.

#### Acceptance Criteria

1. THE FitnessConfig SHALL contain an optional `sleepGoal: SleepGoal?` property and an integer `bufferMinutes: Int` property (default 60, constrained to the range [0, 180]) persisted as part of the existing SwiftData `UserProfile` model.
2. THE SleepGoal SHALL be defined as `struct SleepGoal: Codable, Equatable` with properties `targetSleepTime: DateComponents` and `targetWakeTime: DateComponents`, each storing only `hour` and `minute` components.
3. WHEN the app restarts, THE UserProfile SHALL restore the previously saved `SleepGoal` and `bufferMinutes` from SwiftData without requiring user re-entry.
4. WHEN the user has never configured a `SleepGoal`, THE FitnessConfig SHALL return `nil` for `sleepGoal`, and the system SHALL apply the Fallback Window.

---

### Requirement 3: Expected Sleep Window Construction

**User Story:** As a developer, I want the system to build a concrete date range from the user's SleepGoal, so that HealthKit sessions can be filtered against a precise time window.

#### Acceptance Criteria

1. THE `referenceDate` used by `SleepWindowBuilder` SHALL be `Date()` at the time `refreshHealthData` is executed — i.e., the current calendar day.
2. THE SleepWindowBuilder SHALL construct all dates using `Calendar.current` to respect the user's local timezone, including DST transitions.
3. WHEN `SleepWindowBuilder` is given a `SleepGoal` and a `referenceDate`, THE SleepWindowBuilder SHALL compute `expectedStart` by applying `targetSleepTime` (hour + minute) to the calendar day preceding `referenceDate`.
4. WHEN `SleepWindowBuilder` is given a `SleepGoal` and a `referenceDate`, THE SleepWindowBuilder SHALL compute `expectedEnd` by applying `targetWakeTime` (hour + minute) to `referenceDate`.
5. WHEN `targetSleepTime` is later in the day than `targetWakeTime` (e.g., 23:00 → 07:00), THE SleepWindowBuilder SHALL automatically assign `expectedStart` to the previous calendar day so that `expectedStart` is always before `expectedEnd`.
6. WHEN `targetSleepTime` is earlier in the day than `targetWakeTime` (e.g., 01:00 → 08:00, representing a post-midnight bedtime), THE SleepWindowBuilder SHALL assign both `expectedStart` and `expectedEnd` to the same calendar day as `referenceDate`, ensuring `expectedStart < expectedEnd`.
7. THE SleepWindowBuilder SHALL produce `adjustedStart = expectedStart − bufferMinutes` and `adjustedEnd = expectedEnd + bufferMinutes` as the final `ExpectedSleepWindow`, where `bufferMinutes` comes from `FitnessConfig.bufferMinutes` (default 60).
8. FOR ALL valid `SleepGoal` values, THE SleepWindowBuilder SHALL guarantee `adjustedStart < adjustedEnd`.

---

### Requirement 4: Sleep Session Filtering and Merging

**User Story:** As a developer, I want HealthKit sleep sessions to be merged, filtered, and ranked against the expected window, so that fragmented recordings and naps do not corrupt the recovery calculation.

#### Acceptance Criteria

1. BEFORE applying any window filter, THE SleepSessionFilter SHALL sort sessions by `startDate` ascending to guarantee deterministic merge behavior regardless of the order HealthKit returns samples.
2. AFTER sorting, THE SleepSessionFilter SHALL merge overlapping or adjacent sessions into a single continuous interval. Two sessions are considered adjacent if the gap between `session1.endDate` and `session2.startDate` is ≤ 10 minutes.
3. THE system SHALL allow sessions spanning across multiple calendar days as long as they overlap with the `ExpectedSleepWindow`. A session starting on day N and ending on day N+1 is valid if it satisfies the overlap condition.
4. AFTER merging, THE SleepSessionFilter SHALL retain only sessions where `session.startDate < adjustedEnd AND session.endDate > adjustedStart`.
5. THE SleepSessionFilter SHALL discard all sessions that do not satisfy the overlap condition in criterion 4.
6. A session SHALL be classified as a nap — and discarded — if it meets either of the following conditions:
   - Its total duration is shorter than 90 minutes, OR
   - Its overlap with the `ExpectedSleepWindow` is less than 20% of the session's total duration.
   This ensures that long sessions with minimal window overlap (e.g., a 2-hour nap entirely outside the nocturnal range) are also excluded.
7. THE SleepSessionFilter SHALL allow sessions that start after `expectedStart` if the session's overlap with the `ExpectedSleepWindow` exceeds 50% of the session's total duration. This handles users who fall asleep significantly later than their configured bedtime (e.g., configured 23:00 but actually slept 01:45 → 07:00).
8. WHEN multiple sessions remain after filtering, THE SleepSessionFilter SHALL select the session with the greatest total asleep duration (sum of `asleepCore`, `asleepDeep`, and `asleepREM` intervals) as the main session.
9. WHEN no sessions remain after filtering, THE SleepSessionFilter SHALL set `sleepDetected = false` in the returned `SleepDetectionResult`.

---

### Requirement 5: Sleep Detection Confidence Score

**User Story:** As a developer, I want the detection result to include a confidence score, so that downstream components can weight the recovery calculation appropriately based on detection quality.

#### Acceptance Criteria

1. THE `SleepDetectionResult` SHALL include a `sleepConfidence: Double` property in the range [0.0, 1.0].
2. WHEN the selected session falls entirely within the `ExpectedSleepWindow`, THE SleepSessionFilter SHALL assign `sleepConfidence = 1.0`.
3. WHEN the selected session partially overlaps the `ExpectedSleepWindow`, THE SleepSessionFilter SHALL assign `sleepConfidence` proportional to the overlap fraction: `overlapDuration / sessionDuration`, clamped to [0.0, 1.0].
4. WHEN `sleepDetected = false` (no session found), THE SleepSessionFilter SHALL assign `sleepConfidence = 0.2`.
5. WHEN the Fallback Window is used (no user-configured `SleepGoal`), THE SleepSessionFilter SHALL cap `sleepConfidence` at 0.8 to reflect reduced certainty.
6. THE HealthKitManager SHALL log `sleepConfidence` alongside other sleep metrics for debugging purposes.

---

### Requirement 6: HealthKitManager Integration

**User Story:** As a developer, I want the sleep window logic to execute inside the existing `refreshHealthData` pipeline, so that all downstream metrics benefit from the improved session detection.

#### Acceptance Criteria

1. WHEN `HealthKitManager.refreshHealthData(config:)` is called, THE execution order SHALL be:
   1. `SleepWindowBuilder` — build `ExpectedSleepWindow` from `config.sleepGoal` (or Fallback Window if `nil`)
   2. HealthKit query — fetch raw sleep samples using the `adjustedStart`–`adjustedEnd` range as the predicate
   3. Session sort — sort raw sessions by `startDate` ascending
   4. Session merge — merge overlapping/adjacent sessions (gap ≤ 10 min)
   5. Session filter — apply window overlap and nap exclusion rules
   6. Main session selection — pick session with greatest asleep duration
   7. `sleepConfidence` calculation — compute confidence score for the selected session
   8. HRV/RHR validation — use `sessionStart`/`sessionEnd` from the selected session
2. THE HealthKitManager SHALL pass the resulting `ExpectedSleepWindow` to `querySleepPhases` so that the HealthKit predicate covers at minimum the full `adjustedStart` to `adjustedEnd` range.
3. THE HealthKitManager SHALL apply `SleepSessionFilter` to select the main session before computing sleep duration, HRV window, and RHR window.
4. THE HealthKitManager SHALL log the following structured fields at each execution for debugging:
   - `expectedStart` and `expectedEnd` (before buffer)
   - `adjustedStart` and `adjustedEnd` (after buffer)
   - number of raw sessions returned by HealthKit
   - number of sessions after merging
   - selected session duration (minutes)
   - `sleepConfidence` value

---

### Requirement 7: RecoveryScore Fallback and Confidence Weighting

**User Story:** As a user, I want the app to still provide a recovery score even when no sleep session is detected in my expected window, and I want the recovery score to reflect the quality of sleep detection so I always receive accurate feedback.

#### Acceptance Criteria

1. THE RecoveryScore calculation SHALL weight the sleep contribution by `sleepConfidence`: `effectiveSleepScore = sleepQualityScore * sleepConfidence`. This prevents a poorly detected session from inflating the recovery score.
2. WHEN `SleepDetectionResult.sleepDetected` is `false` AND HRV or RHR data is available, THE HealthKitManager SHALL calculate a partial recovery score using only the available HRV and RHR components with redistributed weights, consistent with the existing `redistributeWeights` logic.
3. WHEN `SleepDetectionResult.sleepDetected` is `false` AND neither HRV nor RHR data is available, THE HealthKitManager SHALL assign a neutral recovery score of 50.
4. WHEN `SleepDetectionResult.sleepDetected` is `false`, THE HealthKitManager SHALL set `sleepHours`, `deepSleepHours`, and `remSleepHours` to `.unavailable`.

---

### Requirement 8: Fallback Window

**User Story:** As a user who has not configured a sleep schedule, I want the app to use a sensible default window, so that sleep detection still works without requiring manual setup.

#### Acceptance Criteria

1. WHEN `FitnessConfig.sleepGoal` is `nil`, THE SleepWindowBuilder SHALL construct the `ExpectedSleepWindow` using a default `targetSleepTime` of 20:00 and a default `targetWakeTime` of 10:00 the following morning.
2. THE Fallback Window SHALL be used only when no user-defined `SleepGoal` exists; it SHALL NOT override a saved `SleepGoal`.
3. WHEN the user later saves a `SleepGoal`, THE HealthKitManager SHALL use the user-defined window on the next call to `refreshHealthData(config:)`, replacing the Fallback Window.

---

### Requirement 9: Sleep Consistency Tracking

**User Story:** As a user, I want to see how consistently I follow my sleep schedule, so that I can understand patterns and improve my sleep habits over time.

#### Acceptance Criteria

1. THE system SHALL compute a `sleepConsistencyScore: Int` (0–100) representing the deviation between the user's actual sleep session and their configured `SleepGoal` for a given day.
2. THE `sleepConsistencyScore` SHALL be calculated as: `100 - min(100, deviationMinutes / 120 * 100)`, where `deviationMinutes` is the average of `|actualSleepStart - expectedStart|` and `|actualWakeTime - expectedEnd|` in minutes. A deviation of 2 hours or more results in a score of 0.
3. WHEN `sleepDetected = false`, THE system SHALL assign `sleepConsistencyScore = 0` for that day.
4. THE system SHALL expose `sleepConsistencyScore` as part of `SleepDetectionResult` for use by the dashboard and future coaching features.
5. THE system SHALL NOT block recovery calculation on consistency score availability — it is supplementary data only.

---

### Requirement 10: Round-Trip Serialization of SleepGoal

**User Story:** As a developer, I want SleepGoal to serialize and deserialize correctly, so that persisted sleep schedules are never corrupted across app versions.

#### Acceptance Criteria

1. THE SleepGoal SHALL conform to `Codable` and encode `targetSleepTime` and `targetWakeTime` as objects containing integer `hour` and `minute` fields.
2. FOR ALL valid `SleepGoal` values, encoding then decoding SHALL produce a `SleepGoal` equal to the original (round-trip property).
3. WHEN a stored `SleepGoal` JSON is missing the `hour` or `minute` field, THE Decoder SHALL throw a descriptive decoding error rather than silently substituting zero.
