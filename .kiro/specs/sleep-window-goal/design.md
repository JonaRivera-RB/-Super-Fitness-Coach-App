# Design Document: Sleep Window Goal

## Overview

This feature introduces a user-defined sleep window (`SleepGoal`) that anchors HealthKit sleep detection to the user's personal schedule. Instead of accepting any sleep session HealthKit returns, the system builds a concrete `ExpectedSleepWindow` from the user's configured bedtime and wake time, then filters, merges, and ranks raw HealthKit samples against that window before computing the RecoveryScore.

The change is additive: existing users without a configured `SleepGoal` receive a sensible Fallback Window (20:00–10:00), so behavior degrades gracefully. Users who configure a schedule get more accurate session detection and a `sleepConfidence` score that weights the sleep contribution to recovery.

Key goals:
- Reduce false positives from naps and fragmented recordings
- Provide a `sleepConfidence` signal so the RecoveryScore reflects detection quality
- Expose a `sleepConsistencyScore` for future coaching features
- Keep all changes backward-compatible with the existing `FitnessConfig` / `UserProfile` / `HealthKitManager` stack

---

## Architecture

The feature introduces three new pure-logic components (`SleepGoal`, `SleepWindowBuilder`, `SleepSessionFilter`) and one new output type (`SleepDetectionResult`). These slot into the existing `refreshHealthData(config:)` pipeline without changing its public signature.

```mermaid
flowchart TD
    A[refreshHealthData(config:)] --> B[SleepWindowBuilder]
    B --> C[HealthKit querySleepPhases]
    C --> D[SleepSessionFilter]
    D --> E[SleepDetectionResult]
    E --> F[RecoveryScore calculation]
    E --> G[HRV / RHR window validation]

    subgraph Persistence
        H[FitnessConfig + SleepGoal] --> B
        H --> I[UserProfileRepository]
    end

    subgraph UI
        J[ProfileView — Sleep Schedule section] --> H
        K[OnboardingView — optional sleep step] --> H
    end
```

### Data flow inside `refreshHealthData`

1. `SleepWindowBuilder.build(goal:referenceDate:bufferMinutes:)` → `ExpectedSleepWindow`
2. `querySleepPhases(store:adjustedStart:adjustedEnd:)` → raw `[HKCategorySample]`
3. `SleepSessionFilter.process(samples:window:)` → `SleepDetectionResult`
4. `SleepDetectionResult` feeds sleep hours, `sessionStart`/`sessionEnd`, and `sleepConfidence` into the existing score calculation

---

## Components and Interfaces

### SleepGoal

```swift
struct SleepGoal: Codable, Equatable {
    var targetSleepTime: DateComponents  // hour + minute only
    var targetWakeTime: DateComponents   // hour + minute only

    /// Duration in hours between targetSleepTime and targetWakeTime (crosses midnight if needed).
    var durationHours: Double { ... }

    /// Returns true when the goal is valid (duration ≥ 4h, times differ).
    var isValid: Bool { durationHours >= 4 }
}
```

Custom `Codable` encodes each `DateComponents` as `{ "hour": Int, "minute": Int }`. Missing fields throw a descriptive `DecodingError`.

### FitnessConfig (extended)

```swift
struct FitnessConfig: Codable, Equatable {
    // existing fields …
    var sleepGoal: SleepGoal?       // nil → use Fallback Window
    var bufferMinutes: Int           // default 60, range [0, 180]
}
```

`bufferMinutes` is clamped on init: `max(0, min(180, value))`.

### SleepWindowBuilder

Pure static struct — no stored state.

```swift
struct SleepWindowBuilder {
    struct ExpectedSleepWindow {
        let expectedStart: Date   // before buffer
        let expectedEnd: Date     // before buffer
        let adjustedStart: Date   // expectedStart − bufferMinutes
        let adjustedEnd: Date     // expectedEnd + bufferMinutes
        let isFallback: Bool
    }

    static func build(
        goal: SleepGoal?,
        referenceDate: Date,
        bufferMinutes: Int,
        calendar: Calendar = .current
    ) -> ExpectedSleepWindow
}
```

**Window construction rules:**
- If `goal == nil` → Fallback Window: `targetSleepTime = 20:00`, `targetWakeTime = 10:00`
- `expectedStart` = `targetSleepTime` applied to the calendar day **preceding** `referenceDate` when `targetSleepTime.hour >= targetWakeTime.hour` (normal overnight case, e.g. 23:00→07:00)
- `expectedStart` = `targetSleepTime` applied to `referenceDate` itself when `targetSleepTime.hour < targetWakeTime.hour` (post-midnight case, e.g. 01:00→08:00)
- `expectedEnd` = `targetWakeTime` applied to `referenceDate`
- `adjustedStart = expectedStart − bufferMinutes`
- `adjustedEnd = expectedEnd + bufferMinutes`
- Invariant: `adjustedStart < adjustedEnd` always holds for valid goals

### SleepSessionFilter

Pure static struct.

```swift
struct SleepSessionFilter {
    static func process(
        samples: [HKCategorySample],
        window: SleepWindowBuilder.ExpectedSleepWindow
    ) -> SleepDetectionResult
}
```

**Processing pipeline:**
1. Sort by `startDate` ascending
2. Merge overlapping/adjacent intervals (gap ≤ 10 min)
3. Filter: keep sessions where `session.start < adjustedEnd && session.end > adjustedStart`
4. Discard naps: duration < 90 min OR overlap with window < 20% of session duration
5. Allow late-start sessions: if `session.start > expectedStart` but overlap > 50% of session duration, keep
6. Select session with greatest total asleep duration (core + deep + REM)
7. Compute `sleepConfidence` and `sleepConsistencyScore`

### SleepDetectionResult

```swift
struct SleepDetectionResult {
    let sleepDetected: Bool
    let sessionStart: Date?
    let sessionEnd: Date?
    let totalSleepHours: Double?
    let deepSleepHours: Double?
    let remSleepHours: Double?
    let sleepConfidence: Double        // [0.0, 1.0]
    let sleepConsistencyScore: Int     // [0, 100]
}
```

**Confidence rules:**
- Full overlap (session entirely within window) → `1.0`
- Partial overlap → `overlapDuration / sessionDuration`, clamped to `[0.0, 1.0]`
- No session detected → `0.2`
- Fallback Window used → cap at `0.8`

**Consistency score:**
```
deviationMinutes = (|actualStart − expectedStart| + |actualEnd − expectedEnd|) / 2
sleepConsistencyScore = 100 − min(100, deviationMinutes / 120 * 100)
```
When `sleepDetected == false` → `sleepConsistencyScore = 0`.

### HealthKitManager (modified)

`refreshHealthData(config:)` updated execution order:
1. Build `ExpectedSleepWindow` via `SleepWindowBuilder`
2. Query HealthKit using `adjustedStart`–`adjustedEnd` as predicate range
3. Pass raw samples to `SleepSessionFilter.process(samples:window:)`
4. Use `SleepDetectionResult` for sleep hours, HRV/RHR window, and confidence weighting

New log fields added (Req 6.4):
- `expectedStart`, `expectedEnd`, `adjustedStart`, `adjustedEnd`
- raw session count, merged session count, selected session duration, `sleepConfidence`

### ProfileViewModel / ProfileView (modified)

New editing state added to `ProfileViewModel`:
```swift
var sleepGoalBedtime: Date        // bound to DatePicker
var sleepGoalWakeTime: Date       // bound to DatePicker
var bufferMinutes: Int            // bound to Stepper/Picker
var isEditingSleepSchedule: Bool
var sleepScheduleValidationError: String?
```

`ProfileView` gains a new "Sleep Schedule" section in the "Fitness Goals" list group, with two `DatePicker` controls (`.hourAndMinute` style) and a save/cancel flow matching the existing body-metrics editing pattern.

### OnboardingViewModel / OnboardingView (modified)

A new `OnboardingStep.sleepSchedule` case is inserted as the last optional step before "Get Started". The step is skippable — tapping "Skip" leaves `sleepGoal = nil` in `FitnessConfig`.

---

## Data Models

### SleepGoal encoding

```json
{
  "targetSleepTime": { "hour": 23, "minute": 0 },
  "targetWakeTime":  { "hour": 7,  "minute": 0 }
}
```

Missing `hour` or `minute` → `DecodingError.keyNotFound` with a descriptive message.

### FitnessConfig (extended JSON)

```json
{
  "sleepGoalHours": 8.0,
  "stepsGoal": 10000,
  "calorieGoal": 500,
  "baselineRestingHR": 70,
  "fitnessLevel": "beginner",
  "sleepGoal": { "targetSleepTime": { "hour": 23, "minute": 0 }, "targetWakeTime": { "hour": 7, "minute": 0 } },
  "bufferMinutes": 60
}
```

`sleepGoal` is optional — absent key decodes as `nil`. `bufferMinutes` defaults to `60` if absent (backward-compatible).

### SwiftData persistence

`FitnessConfig` is already stored as a `Codable` property on `UserProfile`. The new fields are additive and backward-compatible: old stored JSON without `sleepGoal`/`bufferMinutes` decodes cleanly because both fields have defaults.

`UserProfileRepository.updateFitnessConfig(_:)` already handles the delete-and-reinsert workaround for SwiftData change detection — no changes needed there.

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: SleepGoal round-trip serialization

*For any* valid `SleepGoal`, encoding it to JSON and then decoding the result SHALL produce a `SleepGoal` equal to the original.

**Validates: Requirements 2.2, 10.2**

---

### Property 2: SleepWindowBuilder ordering invariant

*For any* valid `SleepGoal`, reference date, and `bufferMinutes` in [0, 180], `SleepWindowBuilder.build` SHALL produce a window where `adjustedStart < adjustedEnd`.

**Validates: Requirements 3.8**

---

### Property 3: Buffer application correctness

*For any* valid `SleepGoal`, reference date, and `bufferMinutes` in [0, 180], the produced window SHALL satisfy `adjustedStart = expectedStart − bufferMinutes` and `adjustedEnd = expectedEnd + bufferMinutes`.

**Validates: Requirements 3.7**

---

### Property 4: Nap exclusion

*For any* set of sleep sessions where every session is shorter than 90 minutes, `SleepSessionFilter.process` SHALL return `sleepDetected = false`.

**Validates: Requirements 4.6**

---

### Property 5: Session merge idempotence

*For any* list of sleep sessions, applying the sort-and-merge step twice SHALL produce the same result as applying it once.

**Validates: Requirements 4.1, 4.2**

---

### Property 6: Session selection by maximum asleep duration

*For any* set of two or more sessions that survive filtering, `SleepSessionFilter.process` SHALL select the session whose total asleep duration (core + deep + REM) is the greatest.

**Validates: Requirements 4.8**

---

### Property 7: Confidence bounds

*For any* valid input to `SleepSessionFilter.process`, the returned `sleepConfidence` SHALL always be in the range [0.0, 1.0].

**Validates: Requirements 5.1, 5.3**

---

### Property 8: Fallback window confidence cap

*For any* sleep session detected using the Fallback Window (no user-configured `SleepGoal`), `sleepConfidence` SHALL be ≤ 0.8.

**Validates: Requirements 5.5**

---

### Property 9: Confidence weighting of sleep score

*For any* `sleepQualityScore` in [0, 100] and `sleepConfidence` in [0.0, 1.0], the effective sleep score used in the RecoveryScore calculation SHALL equal `sleepQualityScore × sleepConfidence`.

**Validates: Requirements 7.1**

---

### Property 10: No-sleep neutral recovery

*For any* call to `refreshHealthData` where `sleepDetected = false` and neither HRV nor RHR data is available, the resulting `recoveryScore` SHALL be 50.

**Validates: Requirements 7.3**

---

### Property 11: Consistency score formula and bounds

*For any* detected sleep session with known actual start and end times and a configured `SleepGoal`, `sleepConsistencyScore` SHALL equal `100 − min(100, deviationMinutes / 120 × 100)` and SHALL always be in the range [0, 100].

**Validates: Requirements 9.1, 9.2**

---

### Property 12: SleepGoal validation rejects short windows

*For any* `SleepGoal` where the duration between `targetSleepTime` and `targetWakeTime` is less than 4 hours, `SleepGoal.isValid` SHALL return `false`.

**Validates: Requirements 1.4**

---

### Property 13: FitnessConfig round-trip serialization

*For any* valid `FitnessConfig` (with or without a `SleepGoal`), encoding then decoding SHALL produce a `FitnessConfig` equal to the original.

**Validates: Requirements 2.1, 2.3**

---

### Property 14: User-defined SleepGoal is never overridden by Fallback

*For any* `FitnessConfig` where `sleepGoal` is non-nil, `SleepWindowBuilder.build` SHALL use the user-defined goal and SHALL NOT produce a window equal to the Fallback Window (20:00–10:00).

**Validates: Requirements 8.2**

---

## Error Handling

| Scenario | Behavior |
|---|---|
| `SleepGoal` JSON missing `hour` or `minute` | `DecodingError.keyNotFound` thrown; app logs error and falls back to `nil` sleepGoal |
| HealthKit returns zero sleep samples | `SleepDetectionResult.sleepDetected = false`; recovery uses HRV/RHR or neutral 50 |
| All sessions filtered as naps | Same as zero samples |
| `bufferMinutes` out of range on decode | Clamped to [0, 180] silently |
| `SleepGoal` with equal times submitted via UI | Validation error shown; config not saved |
| `SleepGoal` with duration < 4h submitted via UI | Validation error shown; config not saved |
| DST transition during sleep window | `Calendar.current` handles automatically; no special case needed |

---

## Testing Strategy

### Unit tests

Focus on specific examples, edge cases, and integration points:

- `SleepWindowBuilder` with overnight goal (23:00→07:00): verify `expectedStart` is on the previous day
- `SleepWindowBuilder` with post-midnight goal (01:00→08:00): verify both dates are on `referenceDate`
- `SleepWindowBuilder` with Fallback Window: verify `isFallback = true` and confidence cap applies
- `SleepSessionFilter` with a single session fully inside the window: `sleepConfidence = 1.0`
- `SleepSessionFilter` with two adjacent sessions (gap = 9 min): merged into one
- `SleepSessionFilter` with two sessions (gap = 11 min): kept separate
- `SleepSessionFilter` with only nap-length sessions: `sleepDetected = false`
- `SleepGoal` decoding with missing `minute` field: throws `DecodingError`
- `FitnessConfig` backward-compat decode (no `sleepGoal` key): `sleepGoal == nil`, `bufferMinutes == 60`
- `HealthKitManager` with `sleepDetected = false` and no HRV/RHR: `recoveryScore == 50`

### Property-based tests

Use [SwiftCheck](https://github.com/typelift/SwiftCheck) (or swift-testing with custom generators). Each test runs a minimum of 100 iterations.

Each test is tagged with a comment in the format:
`// Feature: sleep-window-goal, Property N: <property text>`

| Test | Property | Library tag |
|---|---|---|
| `SleepGoal` encode→decode identity | Property 1 | `Property 1: SleepGoal round-trip serialization` |
| `adjustedStart < adjustedEnd` for all valid goals | Property 2 | `Property 2: SleepWindowBuilder ordering invariant` |
| Buffer offsets match `bufferMinutes` exactly | Property 3 | `Property 3: Buffer application correctness` |
| All-nap sessions → `sleepDetected = false` | Property 4 | `Property 4: Nap exclusion` |
| Merge idempotence | Property 5 | `Property 5: Session merge idempotence` |
| Selected session has max asleep duration | Property 6 | `Property 6: Session selection by maximum asleep duration` |
| `sleepConfidence` ∈ [0.0, 1.0] | Property 7 | `Property 7: Confidence bounds` |
| Fallback confidence ≤ 0.8 | Property 8 | `Property 8: Fallback window confidence cap` |
| `effectiveSleepScore = sleepQualityScore × sleepConfidence` | Property 9 | `Property 9: Confidence weighting of sleep score` |
| No-sleep neutral recovery = 50 | Property 10 | `Property 10: No-sleep neutral recovery` |
| Consistency score formula and bounds | Property 11 | `Property 11: Consistency score formula and bounds` |
| Short-window goal → `isValid = false` | Property 12 | `Property 12: SleepGoal validation rejects short windows` |
| `FitnessConfig` encode→decode identity | Property 13 | `Property 13: FitnessConfig round-trip serialization` |
| Non-nil `SleepGoal` not overridden by Fallback | Property 14 | `Property 14: User-defined SleepGoal is never overridden by Fallback` |

Generators needed:
- `Arbitrary SleepGoal`: random `hour` ∈ [0, 23], `minute` ∈ [0, 59], both times
- `Arbitrary FitnessConfig`: extend existing generator with optional `SleepGoal` and `bufferMinutes` ∈ [0, 180]
- `Arbitrary [HKCategorySample]` (mock): random start/end dates within a 24h window, random sleep stage values
- `Arbitrary Date` (referenceDate): random date within a reasonable range (e.g. ±1 year from now)
