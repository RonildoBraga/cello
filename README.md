# Cello

A native iPhone practice companion for beginners learning music while preparing to play the cello. Built with SwiftUI, AVFoundation and a local Swift pitch-detection package.

## Practice

**Music** is one path of levels, from first sounds to melodies. Each level lists its steps in order and counts the ones you have passed; the first step not yet passed is marked **Continue**. One two-star score passes a step; three 3-star scores among the last five earn its gold mark. Nothing is locked: any level and any step can be opened. Choosing a step opens its screen inside Music, with Back returning to the path. **Recordings** keeps the local history.

| Level | Steps |
| --- | --- |
| 1 · First sounds | Steady hum → Listen & match → Pulse → Two taps per beat |
| 2 · Hot Cross Buns | Listen → Tap it → Meet the notes → Hum it → Whole melody |
| 3 · Ode to Joy | Listen → Tap it → Meet the notes → Hum it → Whole melody |

Below the path, **Cello · open strings** holds Meet your cello and the four open-string lessons for when you have an instrument, and **More practice** holds Mixed rhythm and Listen & Echo. A short note names Bach’s Cello Suite No. 1 as the long-term goal. See [the path design](https://github.com/RonildoBraga/cello/issues/53).

The lessons include:

| Area | Lesson | Exercise | Focus |
| --- | --- | --- | --- |
| Humming | 1 | Steady hum | Sustain one gentle note for three seconds. |
| Humming | 2 | Listen & match | Hear a human example, then hum the same note. |
| Rhythm | 3 | Pulse | Tap one steady beat each second. |
| Rhythm | 4 | Two taps per beat | Count `1 & 2 &`, adding a tap halfway between beats. |
| Rhythm | 5 | Mixed rhythm | Alternate one and two taps per beat: `1, 2-and, 3, 4-and`. |

**Music → More practice → Listen & Echo** adds ear training with fresh two-note and three-note patterns. Tap Hear pattern, listen to the complete recorded-human reference, then Record after 3–2–1. During recording, the live tuning bar follows each target note and shows measured pitch, cents and a higher/lower cue. Stars and the performance chart appear after saving. Two notes last four seconds; three last six. Each level earns separate progress across patterns, with three three-star takes among the last five rated takes completing that level. Both levels remain available. This activity has its own ledger and keeps the original numbered foundation lessons unchanged. See [the Echo practice design and assessment](docs/listen-and-echo.md).

Open **Music → Cello · open strings → Meet your cello** for an original labelled diagram, the four recorded string-pitch examples from low to high, and the route into playing. Hear is manual and needs no microphone/camera capture. Reading and listening leave performance scores and completion unchanged. The introduction returns to the existing playing lessons; setup, first-position instruction and cello melody assessment remain in [issue #6](https://github.com/RonildoBraga/cello/issues/6). See [the introductory sources and draft practical lesson plan](docs/first-cello-lessons.md).

The cello lessons have separate C/G/D/A open-string targets. Lesson pages show instructions, best/latest scores and earned completion; every exercise stays available. Original IDs, lesson numbers and earned progress are retained.

The first melody is Hot Cross Buns. **Meet the notes** plays each of its notes for you to hum back, one at a time, before you hum phrases. Open **Music → Hot Cross Buns → Hum it** to hear, record and review four short phrases, then join them in the **Whole melody** step. The voice reference uses G2–B2 at 60 BPM. Record starts a three-second countdown, then captures four seconds for a phrase or sixteen for the whole tune. Results show separate **Notes**, **Timing** and **Clarity** stars, a moving-reference pitch chart and one next suggestion. Three three-star takes among the last five rated attempts earn completion for that exact phrase and reference. Every phrase stays available.

**Music → Hot Cross Buns → Tap it** applies the same score to tapping: four phrases, then the whole tune. Visible note lengths and recorded-hum playback help you learn the pattern before Start. A four-beat count-in leads into each round with automatic whole-beat haptics. Tap at each note start, then count through longer notes without tapping again. Results show **Pattern**, **Timing** and **Consistency** stars and a timing chart. Each phrase earns separate progress at its own tempo; humming and foundation scores do not complete it. Every phrase remains available.

**Ode to Joy** adds a second melody level: our five-note arrangement of the opening four bars of Beethoven’s theme. It uses the same Listen, Tap it and Hum it screens, four short phrases and a sixteen-second opening. The voice reference spans G2–D3; the cello reference spans D3–A3. The final phrase introduces a dotted quarter note followed by a half-beat note, with visible tap-count guidance. Stars and completion are separate from Hot Cross Buns. See [the opening score and reference provenance](docs/ode-to-joy-reference.md).

**Listen** also offers manual playback in the cello register (D3–F♯3). All audible references use recorded sound: edited human humming for the voice registers and recorded bowed cello samples for cello notes. The foundation human example keeps its original pitch; melody examples adjust the recordings to the selected notes and timing. Cello playing exercises are future work. See the [melody rhythm assessment](docs/melody-rhythm.md), [humming assessment](docs/melody-humming.md), [learning-path design](docs/music-learning-path.md) and [delivery issues](https://github.com/RonildoBraga/cello/issues/1).

- **Hear hum** plays the recorded human example. **Record** starts a three-second countdown, then records a three-second humming take. Cello takes finish when you tap Stop, with a 90-second limit.
- Humming recordings hold microphone audio and pitch observations only; no camera is used or asked for. Cello recordings add synchronized video, so posture and bowing can be reviewed. A tuning bar and end-of-take pitch chart show distance from the fixed target.
- Rhythm lessons use four count-in beats at 60 BPM, automatic whole-beat haptics, saved tap timing and a performance chart. Lesson 4 has sixteen tap positions over eight beats; Lesson 5 has twelve over eight beats.
- Voice stars measure Match, Steady and Hold. Rhythm stars measure coverage, Timing and Evenness; Mixed rhythm's Pattern goal requires at least nine of its twelve expected taps and no more than one extra tap outside the pattern.
- Three three-star attempts among the last five scored attempts earn completion, which remains earned after later attempts.
- **Recordings** provides local playback and one-tap ZIP export for review. Tapping rounds have no recording; each rhythm lesson page lists its recent rounds.

Ratings are beginner practice feedback, not a complete assessment of musical ability. The app does not provide a live AI coach. A teacher remains useful for cello setup, posture and bow technique; pitch estimates can miss notes or choose the wrong octave.

## Build and run

Requirements: macOS with Xcode and an iOS 18-or-later SDK; the app targets iOS 17 and later. The project is developed with Xcode 27.1. Dependencies are Apple frameworks and the local `Packages/CelloPitch` package; no external packages or API keys are required.

1. Open `CelloPractice.xcodeproj` and select the **Cello** scheme.
2. Select an available iPhone Simulator and run, or choose your connected iPhone.
3. For a physical device, select your own Apple development team in **Signing & Capabilities**, use a bundle identifier you can provision, and enable Developer Mode on the phone. Microphone access is requested when starting a recording; camera access only when starting a cello recording. Reference playback works without capture permissions.

The optional install script builds, installs and launches a signed Release app on a connected phone:

```sh
xcrun devicectl list devices
CELLO_DEVELOPMENT_TEAM=YOUR_TEAM_ID bash scripts/run-on-iphone.sh DEVICE_ID
```

Signing credentials and device-specific settings belong in local configuration and must stay out of commits.

For updates without a cable, upload a Release archive to App Store Connect for internal TestFlight testing using the same bundle identifier and team. Back up existing recordings and progress, then install the beta over the existing app without uninstalling it. Account holders complete Apple sign-in and two-factor prompts themselves; export options, distribution archives and backups stay outside Git. TestFlight distribution does not publish the app on the App Store.

## Tests

One script runs the same tests locally and in CI:

```sh
bash scripts/test.sh          # pitch package + app unit tests
bash scripts/test.sh package  # pitch detector only; no Simulator needed
bash scripts/test.sh ui       # real-clock UI tests
bash scripts/test.sh all
```

App and UI tests use the first available iPhone Simulator. To choose one, list them with `xcrun simctl list devices available` and set `CELLO_SIMULATOR_ID=YOUR_SIMULATOR_UUID` before the command. Pull requests run the package and unit tests automatically through [GitHub Actions](.github/workflows/tests.yml); the UI tests stay a local step before a release. Project conventions are in [CONTRIBUTING.md](CONTRIBUTING.md).

Tests cover pitch detection, versioned scoring, recording save/reload/export, progress persistence and recovery, lesson routing, rhythm timing and charts. UI rhythm rounds use the real clock. Optional archived-recording UI checks skip explicitly when their external fixtures are absent; personal recordings are not bundled with the repository. Simulator checks do not establish physical microphone, speaker or haptic behavior.

## Data and privacy

Practice data stays on the device. The app has no account, analytics, automatic uploads or server connection. Sharing happens only through the export action you choose.

The bundled [privacy manifest](CelloPractice/Resources/PrivacyInfo.xcprivacy) declares no tracking or collected data. Countdown and rhythm timers use system uptime to measure elapsed intervals under Apple's approved reason `35F9.1`; raw boot times are not exported. The build also declares that it uses no non-exempt encryption; progress keys use Apple's SHA256 hashing.

- Takes (sound only for humming, sound and video for cello) and metadata: `Documents/PracticeSessions`.
- Unfinished or failed-save takes retained for recovery: `Documents/PendingTakes`.
- Voice completion milestones: `Documents/PracticeProgress.json`.
- Separate rhythm history files: `PulsePractice.json`, `TwoTapsPractice.json` and `MixedRhythmPractice.json`.
- Piece rhythm rounds and completion milestones: `Documents/MelodyRhythmPractice.json`, separate from foundation histories.
- Listen & Echo completion milestones: `Documents/EchoProgress.json`; frozen patterns and ratings stay with the recordings.
- Separate melody completion milestones: `Documents/MelodyProgress.json`; attempt ratings and frozen phrase references stay with each recording.
- A session ZIP contains the recording, metadata, pitch CSV, a review summary and, for takes with video, up to four timestamped JPEG frames.

Deleting the app removes its local data, so export important recordings first. Repository ignore rules exclude local builds, signing material, personal practice media and review artifacts. The bundled reference hum below is a licensed public recording, not a learner's practice take.

## Media attribution

Hot Cross Buns uses an original three-note teaching arrangement of the traditional melody. Its shared score contains 17 note events over 16 beats; recorded-sound playback preserves phrase lengths and leaves short quiet gaps between notes. No publisher score or scan is bundled. See [score and reference provenance](docs/hot-cross-buns-reference.md).

Ode to Joy uses an independently encoded monophonic opening excerpt: 15 note starts, five distinct pitches and 16 beats. Beethoven’s historical composition is public domain; no modern score edition, accompaniment or third-party melody performance is bundled. The existing licensed voice/cello recordings are edited to its frozen score. See [the arrangement details and verification sources](docs/ode-to-joy-reference.md).

The bundled human-hum example is a three-second excerpt of **[Deep Humming Noise](https://freesound.org/people/retropttam/sounds/177276/)** by **retropttam**, licensed under **[Creative Commons Attribution 3.0 Unported](https://creativecommons.org/licenses/by/3.0/)**. It was shortened, converted to mono PCM, volume adjusted and faded at the ends; its original pitch and timing are preserved. Full provenance and checksums are in [HUMMING-LICENSE.txt](CelloPractice/Resources/HUMMING-LICENSE.txt). Copyright remains with the original author.

Melody humming is an adaptation of that same recorded voice: notes are retuned and arranged to the score. These are edited human-voice references, rather than a continuous melody performance by the original recorder. Credits and processing details are included in the same licence file.

Cello references use recorded bowed cello-section samples from **[VSCO 2 Community Edition](https://github.com/sgossner/VSCO-2-CE)**, dedicated under **[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)**. Credits: Versilian Studios / Sam Gossner, Ivy Audio / Simon Dalzell, and sample cutting by Elan Hickler / Soundemote. The excerpts are downmixed, faded, volume adjusted and retuned for the explicit target. They demonstrate cello pitch/timbre, not a solo player's open-string technique. Pinned sources, hashes and edits are in [CELLO-LICENSE.txt](CelloPractice/Resources/CELLO-LICENSE.txt).

Synthetic oscillator signals remain only in the test target as independent grading/decoder controls. Missing recorded resources produce an error instead of substituting a generated tone. Changing reference timbre does not regrade history or reset existing progress.

Rhythm progression draws on MacEwan University's [Clapping and Counting Basic Rhythms](https://openbooks.macewan.ca/introtoeartraining/chapter/clapping-and-counting-basic-rhythms/) and [More Rhythms](https://openbooks.macewan.ca/introtoeartraining/chapter/more-rhythms/). No media from those pages is bundled.
