# Cello

A native iPhone practice companion for beginners learning music while preparing to play the cello. Built with SwiftUI, AVFoundation and a local Swift pitch-detection package.

## Practice

The **Humming** section includes voice and rhythm lessons that need no instrument:

| Lesson | Exercise | Focus |
| --- | --- | --- |
| 1 | Steady hum | Sustain one gentle note for three seconds. |
| 2 | Listen & match | Hear a human example, then hum the same note. |
| 3 | Pulse | Tap one steady beat each second. |
| 4 | Two taps per beat | Count `1 & 2 &`, adding a tap halfway between beats. |
| 5 | Mixed rhythm | Alternate one and two taps per beat: `1, 2-and, 3, 4-and`. |

The **Cello** section has separate C/G/D/A open-string targets. Each section remembers its lesson selection. **Lessons** shows instructions, best/latest scores and earned completion; every exercise stays available.

- **Hear hum** plays the recorded human example. **Record** starts a three-second countdown, then records a three-second humming take. Cello takes finish when you tap Stop, with a 90-second limit.
- Voice/instrument recordings include synchronized microphone audio, video and pitch observations. A tuning bar and end-of-take pitch chart show distance from the fixed target.
- Rhythm lessons use four count-in beats at 60 BPM, automatic whole-beat haptics, saved tap timing and a performance chart. Lesson 4 has sixteen tap positions over eight beats; Lesson 5 has twelve over eight beats.
- Voice stars measure Match, Steady and Hold. Rhythm stars measure coverage, Timing and Evenness; Mixed rhythm's Pattern goal requires at least nine of its twelve expected taps and no more than one extra tap outside the pattern.
- Three three-star attempts among the last five scored attempts earn completion, which remains earned after later attempts.
- **Recordings** provides local playback and manual ZIP export for review.

Ratings are beginner practice feedback, not a complete assessment of musical ability. The app does not provide a live AI coach. A teacher remains useful for cello setup, posture and bow technique; pitch estimates can miss notes or choose the wrong octave.

## Build and run

Requirements: macOS with Xcode and an iOS 18-or-later SDK; the app targets iOS 17 and later. The project is developed with Xcode 27.1. Dependencies are Apple frameworks and the local `Packages/CelloPitch` package; no external packages or API keys are required.

1. Open `CelloPractice.xcodeproj` and select the **Cello** scheme.
2. Select an available iPhone Simulator and run, or choose your connected iPhone.
3. For a physical device, select your own Apple development team in **Signing & Capabilities**, use a bundle identifier you can provision, and enable Developer Mode on the phone. Camera and microphone access are requested when starting a recording. Reference playback works without capture permissions.

The optional install script builds, installs and launches a signed Release app on a connected phone:

```sh
xcrun devicectl list devices
CELLO_DEVELOPMENT_TEAM=YOUR_TEAM_ID bash scripts/run-on-iphone.sh DEVICE_ID
```

Signing credentials and device-specific settings belong in local configuration and must stay out of commits.

## Tests

The pitch detector can be tested without the iPhone app:

```sh
swift test --package-path Packages/CelloPitch -c release
```

For app and UI tests, first find a Simulator installed on your Mac:

```sh
xcrun simctl list devices available
```

Use its UUID in the following commands:

```sh
CELLO_SIMULATOR_ID=YOUR_SIMULATOR_UUID

xcodebuild -project CelloPractice.xcodeproj -scheme Cello \
  -destination "platform=iOS Simulator,id=$CELLO_SIMULATOR_ID" \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -only-testing:CelloTests test

xcodebuild -project CelloPractice.xcodeproj -scheme Cello \
  -destination "platform=iOS Simulator,id=$CELLO_SIMULATOR_ID" \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -only-testing:CelloUITests test
```

Tests cover pitch detection, versioned scoring, recording save/reload/export, progress persistence and recovery, lesson routing, rhythm timing and charts. UI rhythm rounds use the real clock. Optional archived-recording UI checks skip explicitly when their external fixtures are absent; personal recordings are not bundled with the repository. Simulator checks do not establish physical microphone, speaker or haptic behavior.

## Data and privacy

Practice data stays on the device. The app has no account, analytics, automatic uploads or server connection. Sharing happens only through the export action you choose.

- Audio/video takes and metadata: `Documents/PracticeSessions`.
- Unfinished or failed-save takes retained for recovery: `Documents/PendingTakes`.
- Voice completion milestones: `Documents/PracticeProgress.json`.
- Separate rhythm history files: `PulsePractice.json`, `TwoTapsPractice.json` and `MixedRhythmPractice.json`.
- A session ZIP contains the movie, metadata, pitch CSV, a review summary and up to four timestamped JPEG frames.

Deleting the app removes its local data, so export important recordings first. Repository ignore rules exclude local builds, signing material, personal practice media and review artifacts. The bundled reference hum below is a licensed public recording, not a learner's practice take.

## Media attribution

The bundled human-hum example is a three-second excerpt of **[Deep Humming Noise](https://freesound.org/people/retropttam/sounds/177276/)** by **retropttam**, licensed under **[Creative Commons Attribution 3.0 Unported](https://creativecommons.org/licenses/by/3.0/)**. It was shortened, converted to mono PCM, volume adjusted and faded at the ends; its original pitch and timing are preserved. Full provenance and checksums are in [HUMMING-LICENSE.txt](CelloPractice/Resources/HUMMING-LICENSE.txt). Copyright remains with the original author.

Rhythm progression draws on MacEwan University's [Clapping and Counting Basic Rhythms](https://openbooks.macewan.ca/introtoeartraining/chapter/clapping-and-counting-basic-rhythms/) and [More Rhythms](https://openbooks.macewan.ca/introtoeartraining/chapter/more-rhythms/). No media from those pages is bundled.
