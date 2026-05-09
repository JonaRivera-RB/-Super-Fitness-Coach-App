# Requirements Document

## Introduction

This feature adds body metrics collection (weight and height) to the onboarding flow of the Super Fitness Coach App, persists them in the UserProfile SwiftData model, allows editing from the Profile screen, and uses the derived BMI to personalize workout intensity and recommendations. It also supports reading weight/height from HealthKit when available and respects the user's preferred unit system (metric vs imperial) with locale-based auto-detection.

## Glossary

- **Onboarding_Flow**: The multi-step screen sequence presented to first-time users to collect their profile information before accessing the main app.
- **Body_Metrics_Step**: The new onboarding step inserted between the fitness goal selection step and the Apple Health connection step, where the user enters weight and height.
- **UserProfile**: The SwiftData `@Model` entity that stores the user's name, fitness goal, onboarding status, and (with this feature) weight, height, and unit preference.
- **Unit_Preference**: The user's chosen measurement system — metric (kg / cm) or imperial (lbs / ft-in). Stored in UserProfile.
- **BMI**: Body Mass Index, calculated as weight (kg) / height (m)². Used to adjust workout intensity.
- **Workout_Engine**: The service (`WorkoutEngine`) responsible for generating weekly plans and adjusting daily workouts based on fitness goal, recovery score, and (with this feature) body metrics.
- **HealthKit_Manager**: The service (`HealthKitManager`) responsible for querying Apple Health data. Extended in this feature to optionally read weight and height.
- **Profile_Screen**: The existing Profile tab where users can view and edit their settings, extended to support weight and height editing.
- **Locale_Detection**: The mechanism that reads `Locale.current` to determine the user's region and auto-select metric or imperial units.

## Requirements

### Requirement 1: Body Metrics Onboarding Step

**User Story:** As a new user, I want to enter my weight and height during onboarding, so that the app can personalize my workout recommendations from the start.

#### Acceptance Criteria

1. WHEN the user completes the fitness goal selection step, THE Onboarding_Flow SHALL navigate to the Body_Metrics_Step before the Apple Health connection step.
2. THE Body_Metrics_Step SHALL display input fields for weight and height with the currently selected Unit_Preference.
3. THE Body_Metrics_Step SHALL display a segmented control allowing the user to switch between metric (kg / cm) and imperial (lbs / ft-in) units.
4. WHEN the user switches Unit_Preference on the Body_Metrics_Step, THE Onboarding_Flow SHALL convert and display the previously entered values in the newly selected unit system.
5. THE Body_Metrics_Step SHALL allow the user to proceed only when both weight and height contain valid numeric values greater than zero.
6. WHEN the Body_Metrics_Step is first displayed, THE Onboarding_Flow SHALL auto-select the Unit_Preference based on Locale_Detection.
7. THE Onboarding_Flow SHALL update the progress indicator to reflect four steps instead of three.

### Requirement 2: Persist Body Metrics in UserProfile

**User Story:** As a user, I want my weight, height, and unit preference saved locally, so that the app remembers my body metrics across sessions.

#### Acceptance Criteria

1. THE UserProfile SHALL store weight in kilograms as a Double, regardless of the display Unit_Preference.
2. THE UserProfile SHALL store height in centimeters as a Double, regardless of the display Unit_Preference.
3. THE UserProfile SHALL store the selected Unit_Preference as a persisted enum value (metric or imperial).
4. WHEN the user completes onboarding, THE Onboarding_Flow SHALL save weight, height, and Unit_Preference to the UserProfile via SwiftData.
5. WHEN weight or height is stored, THE UserProfile SHALL convert imperial input values to metric (kg and cm) before persisting.

### Requirement 3: Edit Body Metrics in Profile Screen

**User Story:** As a returning user, I want to update my weight and height from the Profile screen, so that my workout recommendations stay accurate as my body changes.

#### Acceptance Criteria

1. THE Profile_Screen SHALL display the user's current weight and height in the selected Unit_Preference.
2. WHEN the user taps on the weight or height field, THE Profile_Screen SHALL present an editable input allowing the user to change the value.
3. WHEN the user saves updated body metrics, THE Profile_Screen SHALL persist the new values to the UserProfile via SwiftData.
4. WHEN the user saves updated body metrics, THE Profile_Screen SHALL trigger the Workout_Engine to re-evaluate workout intensity for the current weekly plan.
5. THE Profile_Screen SHALL allow the user to change the Unit_Preference, converting displayed values accordingly.
6. WHEN the user saves an invalid value (non-numeric, zero, or negative), THE Profile_Screen SHALL display a validation error and retain the previous valid value.

### Requirement 4: BMI-Based Workout Personalization

**User Story:** As a user, I want my workouts adjusted based on my body metrics, so that the exercise intensity matches my physical profile.

#### Acceptance Criteria

1. THE Workout_Engine SHALL calculate BMI from the UserProfile weight (kg) and height (cm) using the formula: weight / (height_in_meters)².
2. WHEN generating a weekly plan, THE Workout_Engine SHALL adjust the base number of sets and reps based on the calculated BMI category (underweight < 18.5, normal 18.5–24.9, overweight 25–29.9, obese >= 30).
3. WHEN the BMI category is underweight, THE Workout_Engine SHALL reduce cardio sessions and increase strength-focused sessions in the weekly distribution.
4. WHEN the BMI category is obese, THE Workout_Engine SHALL increase low-impact cardio sessions and reduce high-intensity strength sets.
5. WHEN the BMI category is normal or overweight, THE Workout_Engine SHALL use the existing distribution logic for the selected fitness goal without modification.
6. IF weight or height is missing from the UserProfile, THEN THE Workout_Engine SHALL fall back to the existing goal-only plan generation without BMI adjustments.

### Requirement 5: HealthKit Weight and Height Import

**User Story:** As a user who tracks my body metrics in Apple Health, I want the app to offer to import my weight and height, so that I don't have to enter them manually.

#### Acceptance Criteria

1. WHEN the user has granted HealthKit authorization, THE Body_Metrics_Step SHALL query HealthKit for the most recent weight and height samples.
2. WHEN HealthKit returns valid weight and height data, THE Body_Metrics_Step SHALL pre-fill the input fields with the retrieved values converted to the current Unit_Preference.
3. WHEN HealthKit returns valid data, THE Body_Metrics_Step SHALL display a label indicating the values were imported from Apple Health.
4. THE Body_Metrics_Step SHALL allow the user to override HealthKit-imported values by editing the input fields manually.
5. WHEN HealthKit does not return weight or height data, THE Body_Metrics_Step SHALL leave the corresponding input field empty for manual entry.
6. THE HealthKit_Manager SHALL request read access to `HKQuantityType(.bodyMass)` and `HKQuantityType(.height)` in addition to existing health data types.

### Requirement 6: Unit Preference with Locale Auto-Detection

**User Story:** As a user, I want the app to default to my region's measurement system, so that I see familiar units without manual configuration.

#### Acceptance Criteria

1. WHEN the Body_Metrics_Step is first displayed and no Unit_Preference has been set, THE Onboarding_Flow SHALL detect the user's locale using `Locale.current` and select metric for locales that use the metric system and imperial for locales that use the US customary system.
2. THE Onboarding_Flow SHALL display weight in kilograms for metric and pounds for imperial.
3. THE Onboarding_Flow SHALL display height in centimeters for metric and feet-inches for imperial.
4. WHEN the user manually selects a Unit_Preference, THE UserProfile SHALL persist the selection and use the manual selection for all future displays.
5. FOR ALL valid weight values, converting from metric to imperial and back to metric SHALL produce a value within 0.1 kg of the original (round-trip property).
6. FOR ALL valid height values, converting from metric to imperial and back to metric SHALL produce a value within 0.5 cm of the original (round-trip property).
