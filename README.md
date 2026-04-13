# FitScroll - Exercise to Unlock Screen Time

FitScroll is an iOS app that helps users manage their screen time by requiring physical exercise to unlock restricted apps. Selected social media and distracting apps are limited after a configured daily usage threshold, and users earn temporary access by completing real workout sessions tracked via on-device pose detection.

## How It Works

1. **Select Apps** - Choose which apps to restrict using Apple's FamilyControls picker
2. **Set Limits** - Configure daily usage limits (e.g., 30 minutes for social media)
3. **Apps Lock** - When the limit is reached, selected apps are shielded
4. **Exercise to Unlock** - Open FitScroll and choose an exercise
5. **Camera Tracks Reps** - The camera detects your movements and counts repetitions
6. **Earn Screen Time** - Each rep earns configurable minutes of unlocked access
7. **Auto Re-lock** - When earned time expires, apps are restricted again

## Apple Frameworks Used

| Framework | Purpose |
|-----------|---------|
| **SwiftUI** | All UI screens and navigation |
| **SwiftData** | Local persistence for sessions, settings, credits |
| **FamilyControls** | Authorization and app selection for Screen Time |
| **ManagedSettings** | Applying and removing app shields/restrictions |
| **DeviceActivity** | Monitoring daily app usage and triggering limits |
| **AVFoundation** | Camera capture session for workout tracking |
| **Vision** | `VNDetectHumanBodyPoseRequest` for body joint detection |
| **Combine** | Reactive data flow in coordinators |

## Architecture

The project follows a modular Clean Architecture pattern:

```
FitScroll/
├── App/                          # App entry point, root navigation
├── Domain/
│   ├── Entities/                 # Data models (ExerciseType, WorkoutSession, etc.)
│   └── UseCases/                 # Business logic (CalculateReward, ManageUnlock)
├── Features/                     # Feature modules (MVVM per screen)
│   ├── Onboarding/
│   ├── Permissions/
│   ├── AppSelection/
│   ├── Limits/
│   ├── Dashboard/
│   ├── UnlockSession/
│   ├── CameraWorkout/
│   ├── SessionSummary/
│   ├── History/
│   └── Settings/
├── Data/
│   ├── Persistence/              # SwiftData configuration
│   └── Repositories/             # Data access layer
├── Infrastructure/
│   ├── ScreenTime/               # FamilyControls/ManagedSettings services
│   ├── Camera/                   # AVFoundation camera service
│   ├── PoseDetection/            # Vision pose detection + rep counting
│   └── Logging/                  # os.Logger wrapper
└── Shared/
    ├── UI/                       # Reusable SwiftUI components
    ├── DesignSystem/             # Colors, spacing, typography tokens
    ├── Localization/             # Centralized strings
    ├── Utils/                    # Haptics, formatters
    └── Errors/                   # App-wide error types
```

### Pose Detection Pipeline

```
Camera Frame → Vision Body Pose Request → PoseFrame
    → JointAngleCalculator → RepDetectionEngine (state machine)
        → ExerciseRepCounter → WorkoutSessionCoordinator
```

Each exercise uses specific joint angles:
- **Squat**: Hip-Knee-Ankle angle
- **Push-up**: Shoulder-Elbow-Wrist angle
- **Dumbbell Curl**: Shoulder-Elbow-Wrist angle (different thresholds)
- **Sit-up**: Shoulder-Hip-Knee angle
- **Pull-up**: Shoulder-Elbow-Wrist angle
- **Jump Rope**: Hip-Ankle vertical distance (rhythmic detection)

### Rep Counting State Machine

```
IDLE → GOING_DOWN (angle < downThreshold)
     → DOWN (confirmed)
     → GOING_UP (angle > upThreshold)
     → UP (rep counted if passes debounce + min duration)
     → back to IDLE
```

## Known iOS Platform Constraints

### What Works Natively
- ✅ App selection via `FamilyActivityPicker`
- ✅ App shielding via `ManagedSettingsStore`
- ✅ Usage monitoring via `DeviceActivityCenter`
- ✅ On-device pose detection via `VNDetectHumanBodyPoseRequest`
- ✅ Real-time camera feed with `AVCaptureSession`

### Platform Limitations
1. **FamilyControls requires real device** - Screen Time APIs do not work in the iOS Simulator. You must test on a physical device.
2. **App Group required** - The main app and DeviceActivity extension share data via ManagedSettingsStore. Both must use the same App Group.
3. **Individual authorization only** - FamilyControls `.individual` authorization requires the user to authenticate. `.child` mode requires a parent's iCloud account.
4. **No precise per-app usage data** - Apple does not expose exact per-app usage minutes to third-party apps. DeviceActivity monitors threshold events, not continuous usage.
5. **Shield customization is limited** - ShieldConfigurationDataSource runs in an extension with limited UI options.
6. **Background pose detection not possible** - Camera and Vision processing require the app to be in the foreground.

### App Store Review Considerations
- FamilyControls entitlement requires [Apple approval](https://developer.apple.com/contact/request/family-controls-distribution)
- The app must clearly explain why Screen Time access is needed
- Camera usage must state on-device processing and no recording
- No external data transmission of pose/video data

## Exercise Reliability Tiers

### Stable (MVP)
| Exercise | Detection Method | Reliability |
|----------|-----------------|-------------|
| Squat | Knee angle tracking | High |
| Push-up | Elbow angle tracking | High |
| Dumbbell Curl | Elbow angle tracking | High |

### Experimental (v2)
| Exercise | Detection Method | Notes |
|----------|-----------------|-------|
| Sit-up | Torso angle | Requires side camera angle |
| Jump Rope | Vertical rhythmic motion | Distance-based, less precise |
| Pull-up | Shoulder-elbow position | Requires specific camera setup |

## Requirements

- **iOS 17.0+**
- **Xcode 15.0+**
- **Swift 6.0**
- **Physical device** for Screen Time and Camera features
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) for project generation

## Setup

```bash
# 1. Install XcodeGen if not installed
brew install xcodegen

# 2. Generate Xcode project
cd fitscroll
xcodegen generate

# 3. Open in Xcode
open FitScroll.xcodeproj

# 4. Select your team for code signing
# 5. Request FamilyControls entitlement from Apple Developer portal
# 6. Build and run on a physical device
```

## Running Tests

### Unit Tests
```bash
# Run via Xcode or command line
xcodebuild test -scheme FitScroll -destination 'platform=iOS Simulator,name=iPhone 16'
```

### UI Tests
```bash
xcodebuild test -scheme FitScrollUITests -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Maestro Tests
```bash
# Install Maestro
curl -Ls "https://get.maestro.mobile.dev" | bash

# Run all flows
maestro test MaestroTests/

# Run specific flow
maestro test MaestroTests/onboarding_flow.yaml
```

**Note:** Maestro tests for camera workout flows work best with debug mode enabled (uses MockPoseProvider in simulator). Real camera and pose detection must be tested on a physical device.

## Features Requiring Physical Device

| Feature | Simulator | Device |
|---------|-----------|--------|
| Onboarding UI | ✅ | ✅ |
| App Selection | ❌ | ✅ |
| Usage Monitoring | ❌ | ✅ |
| App Shielding | ❌ | ✅ |
| Camera Preview | ❌ | ✅ |
| Pose Detection | Mock only | ✅ |
| Rep Counting Logic | ✅ (unit tests) | ✅ |
| Temporary Unlock | ❌ | ✅ |
| SwiftData Persistence | ✅ | ✅ |
| Debug Mode | ✅ | ✅ |

## Simulator Testing Strategy

The architecture supports testing without a real device:
- `PoseProvider` protocol with `MockPoseProvider` for deterministic rep generation
- `ScreenTimeServiceProtocol` with mockable implementation
- Debug mode with simulated workouts and test unlocks
- SwiftData in-memory containers for unit tests

## Future Improvements

- [ ] Apple Watch companion app for wrist-based rep counting
- [ ] Weekly/monthly statistics and charts
- [ ] Custom exercise creation with configurable joint tracking
- [ ] Social features (challenges, leaderboards)
- [ ] Siri Shortcuts integration ("Start a squat session")
- [ ] Widget for dashboard stats
- [ ] Core ML model for improved exercise classification
- [ ] CloudKit sync for multi-device support
- [ ] Accessibility improvements (VoiceOver, Dynamic Type)
- [ ] Localization (Turkish, English, etc.)

## Privacy

- All pose detection processing happens **on-device** using Apple's Vision framework
- **No video is recorded or transmitted**
- App usage data stays local via SwiftData
- No third-party analytics or tracking SDKs
- Camera frames are processed in real-time and immediately discarded
