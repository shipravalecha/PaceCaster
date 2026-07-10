PaceCaster is a privacy-first, minimalist running metrics and predictive analytics utility for iOS. Unlike heavy social fitness networks (Strava) or strict coaching platforms (Runna), PaceCaster acts as a clean, local database that strips out non-running activities and uses historic aerobic data to dynamically project future race paces.

Core Features
1. The Pure Running Filter (HealthKit Sync): Automatic background syncing with Apple HealthKit. The system strictly isolates workouts matching HKWorkoutActivityType.running. All walks, hikes, swims, and strength sessions are entirely filtered out from the dataset.
2. Aerobic Efficiency Mapping: The app computes an efficiency index by evaluating the mathematical relationship between the runner’s sustained pace and average heart rate during steady-state runs.
3. Live Predictive "Casting" (The Slider Dashboard): An interactive UI component where adjusting a target distance slider (from 5K to a Half Marathon) calculates a personalized predicted finish time and target mile/kilometer split pace using an on-device regression formula.
4. Privacy-First Architecture: No backend server, no login, and no cloud-side tracking. Data is processed strictly on-device using native local storage frameworks.
