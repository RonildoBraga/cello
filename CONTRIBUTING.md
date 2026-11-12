# Contributing

House rules for changing Cello, whether you are a person or an AI assistant. They describe what the code already does; keep it that way unless an issue says otherwise.

## Words

One vocabulary, on screen, in code, in tests and in docs:

- **Level**: a numbered stage of the path (First sounds, Hot Cross Buns, Ode to Joy, Twinkle, Twinkle, Lightly Row, Old MacDonald, Yankee Doodle, G major scale, Prelude chords, Prelude opening).
- **Lesson**: one item in a level, shown as "Lesson 1 of 6". Not "step", "exercise" or "activity".
- **Part**: a piece of a lesson that has several, such as a phrase or a single note.
- **Take**: one recording. **Round**: one tapping attempt.
- **Passed**: one scored take or round with two stars or more. **Gold**: three 3-star takes or rounds among the last five.

A lesson's number is its place in its level. Saved data keeps its own stable IDs and never shows them.

## Before you open a pull request

```sh
bash scripts/test.sh        # pitch package + app unit tests (CI runs the rendered melody examples as a job of their own)
bash scripts/test.sh smoke  # nine UI tests across every area, about 6 minutes; run for each change to a screen
bash scripts/test.sh ui     # every real-clock UI test, about 30 minutes; run before a release
```

Simulator checks do not establish microphone, speaker, camera or haptic behaviour. Say in the pull request what was and was not checked on a physical iPhone.

## Learner data is a contract

- **Saved formats are frozen.** Session folders, progress ledgers and rhythm histories written by an older build must load unchanged. Add optional fields; never rename, repurpose or rewrite existing ones.
- **Scoring versions are frozen.** A saved rating keeps the grade it was given. A changed rubric or threshold needs a new version, not an edit to the old one.
- **Unreadable files are preserved.** If a user file cannot be decoded, keep it, show a message and do not overwrite it.
- **Earned completion stays earned.** Later attempts, deleted recordings or a failed write must not remove a milestone.
- **Lesson IDs are stable.** They key saved progress. A lesson's number on screen is only its place in its level.
- **Nothing leaves the device.** No accounts, analytics or network calls. New files in `Documents` are listed under "Data and privacy" in the README.

## Code

- **Less is more.** Every screen element and every line needs a reason to exist. Leave out effects that only decorate, such as celebration animations. When something stops being used, delete it in the same change: the property, the helper, its tests and its docs.
- **No third-party dependencies** without discussing it in an issue first. Apple frameworks and the local `Packages/CelloPitch` package are enough today.
- **Listening and judging live in `Packages/CelloPitch`.** Pitch detection, the melody scores, the melody rater and the teacher's note are plain Swift with no screens, so the app, the tests and a command-line tool share one copy. Screens, storage and lesson wording stay in the app. Before changing how takes are scored, run the tool on real recordings and say in the pull request what gained and lost stars:

  ```sh
  swift run --package-path Packages/CelloPitch -c release cello-rescore FOLDER_OF_SAVED_TAKES
  ```

  `FOLDER_OF_SAVED_TAKES` is any folder holding takes as the app saves them, such as a copy of the app's Documents. Keep such copies out of the repository: they are personal recordings.
- **Reuse before you copy.** A new activity should configure the existing practice screen, rhythm round, result card, chart and progress ledger. If one of them does not fit, extend it; do not add a parallel version.
- **Shared look.** Use the components in `DesignSystem.swift` for cards, buttons, headers and rows instead of inline radii, paddings and font sizes.
- **Text scales.** Use text styles (`.headline`, `.caption2`, …) or `@ScaledMetric`; a literal point size belongs only in `DesignSystem.swift`. Small text needs a contrast ratio of at least 4.5:1: on the dark cards use white at 70% opacity or more, and use `Palette.goldText`, not `Palette.gold`, for gold text.
- **Light appearance only, for now.** The app forces light mode and uses a fixed palette. This is a deliberate choice (issue #30), not an oversight; adding a dark appearance means giving `Palette` dark variants and replacing the literal `.white` in `DesignSystem.swift`.
- **Drawing a screen reads; it does not work things out.** A view's `body` runs many times a second while a take records. Anything derived from the saved takes or rounds (progress, best scores, what is passed) is indexed by its store when the takes change and looked up when drawn. Never scan, decode or hash saved data from a view.
- **Observe only what you show.** The capture controller ticks about twenty times a second while it records or plays. A view that shows nothing of a take in progress holds it with `let`, not `@ObservedObject`; a view that needs one of its states subscribes to that state (see `PracticeMethodSwitch`). The path screen must never redraw on a capture tick.
- **Models decide, views show.** Rules such as "either method passes a lesson" live in the model (`PathProgress`, `LessonProgress`, the ledgers), where a unit test can reach them.
- **Content lives in the models.** Per-lesson and per-piece text belongs with `PracticeLesson`, `MelodyPiece` and friends, not in `if piece == …` branches inside views.
- **Accessibility identifiers are a test contract.** The UI tests find controls by identifier. Keep existing identifiers when you restructure a view, and give new interactive controls one.
- **Keep it small.** Prefer deleting or simplifying to adding an abstraction. One file per screen or type, named after what it contains.
- **Sources are grouped by feature** under `CelloPractice/`: `App`, `Library`, `VoicePractice`, `Rhythm`, `Melody`, `Recordings`, `Capture` and `Shared`. Put a new file in its feature's folder and add it to the matching group in the Xcode project.

## Media and wording

- Bundled audio needs a licence, attribution and provenance recorded next to it (see `CelloPractice/Resources`) and in the README.
- Ratings are beginner practice feedback. Do not describe them as a full assessment, and do not imply a live coach.

## Pull requests

- One issue per pull request where possible; link it.
- Refactors change structure, not behaviour. If a refactor has to change behaviour, call it out.
- Include before/after screenshots for anything visible.
