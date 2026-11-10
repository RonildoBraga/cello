# Music learning path

Status: Music organisation, first-melody reference playback, humming phrase recording/feedback and melody rhythm practice delivered. A five-note Ode to Joy opening now reuses the same phrase and whole-selection practice. Cello playing remains planned in [the delivery epic](https://github.com/RonildoBraga/cello/issues/1).

## Problem and goal

Voice and rhythm exercises currently share a Humming section, while the library offers no connection between isolated skills and music to play. A beginner needs to find the right practice, keep earned progress and understand how each skill contributes to a first melody and later repertoire.

The first delivery separates Humming, Rhythm and Cello inside a Music library. It adds a first-piece path for Hot Cross Buns and a longer-term path toward Bach’s Cello Suite No. 1 Prelude, BWV 1007. These are learning goals; a completed tap exercise is not evidence of performing a new melody.

## Navigation

```text
Music (the path)
  Level 1 · First sounds      Steady hum → Listen & match → Pulse → Two taps per beat
  Level 2 · Hot Cross Buns    Listen → Tap it → Meet the notes → Hum it → Whole melody
  Level 3 · Ode to Joy        Listen → Tap it → Meet the notes → Hum it → Whole melody
  Where this is heading       a note naming Bach's Suite No. 1 as the long-term goal
  Cello · open strings        Meet your cello; Open C/G/D/A strings
  More practice               Mixed rhythm; Listen & Echo
Recordings → existing local audio/video history
```

The path replaced separate Foundations and Pieces libraries ([issue #49](https://github.com/RonildoBraga/cello/issues/49), design note [#53](https://github.com/RonildoBraga/cello/issues/53)). A `Level` is a title and an ordered list of `PathStep`s, and each step opens a screen that already existed: a lesson page, Listen (the reference player), Tap it (melody rhythm), Meet the notes, and Hum it or Whole melody (melody humming opened at phrase 1 or at the whole melody). Adding a melody adds one level with the same steps.

The level holding the first unfinished step opens when the path appears, and that step is marked Continue. It is a suggestion only: every level can be opened and every step tapped. Cello and More practice are not counted and never become the next step.

### Primers

Level 1 starts from zero ([issue #52](https://github.com/RonildoBraga/cello/issues/52)). Each of its four lessons introduces one idea, and opens the first time with a one-screen primer: **A note** (with pitch and cents, which the tuning bar uses), **Higher and lower**, **A beat** and **Two taps per beat**. A primer is a few plain sentences, one button to hear or feel the idea, and Continue into the lesson. The sound primers reuse the recorded hum; the beat primers count on screen with a vibration on each beat. Nothing is recorded or scored.

The content is `PracticeLesson.primer`; the screen is `PrimerView`. Reading a primer is remembered as a preference, and the lesson page offers it again under "New to this?". A unit test checks that no Level 1 lesson's own copy uses pitch, beat, cents, register, BPM or pulse before a primer has explained it.

### Meet the notes

Each melody level introduces its notes before asking for whole phrases ([issue #51](https://github.com/RonildoBraga/cello/issues/51)): three for Hot Cross Buns (G2, A2, B2), five for Ode to Joy (G2 to D3). For each note the learner hears the recorded hum and hums it back for three seconds with the live tuning bar. Two pairs follow, the lowest then the highest note and the reverse, to hear and feel "higher" and "lower".

A `NoteDrill` is a one- or two-event `MelodyPracticeContext` with its own piece ID (`hotCrossBuns.notes`), so the recorder, the melody rater, the result card, the chart and the melody ledger are the ones phrases use. Takes appear in Recordings as "Hot Cross Buns · Meet the notes · G2". The step is passed when every note has a passing take; the pairs are extra practice. Notes are shown as names and tiles; staff notation is out of scope.

### Passed and gold

Progress has two tiers ([issue #50](https://github.com/RonildoBraga/cello/issues/50)), both defined once in `CompletionRule` and both computed from attempts that are already saved:

- **Passed** moves the path on: one scored attempt with two stars or more. It is read from the saved takes and rounds, so deleting the only passing take un-passes it.
- **Gold** is the earlier completion rule, unchanged: three 3-star attempts among five consecutive scored attempts. It is kept in the existing ledgers, survives later takes and always counts as passed.

A lesson or the whole melody is one part. Tap it and Hum it roll up four phrases: the step shows "2 of 4 phrases passed", is passed when all four are, and is gold when all four are gold. Listen is passed once the whole melody has played to its end. A level shows how many of its steps are passed; when the last one passes, the path shows a completion card once and points at the next step.

No saved format changed. Two small preferences hold what no take records: the melodies heard to the end and the levels already celebrated.

Music and Recordings are the two iPhone tabs. Practice is a screen, not a tab: every activity — a lesson, a melody's Listen, Tap it or Hum it step, Listen & Echo — is pushed inside Music and left with Back ([issue #33](https://github.com/RonildoBraga/cello/issues/33)). Starting a foundation lesson pushes a fresh, ready practice screen above that lesson's page; "Try lesson N" replaces it with the next lesson's page and practice screen, so Back always matches what is on screen.

An earlier release had a separate Practice tab with its own area and lesson pickers. It was removed because it duplicated the Music tab's lists, could fall out of step with the Music tab, and could not host piece or Echo practice.

This is a design choice informed by [Apple’s sidebar guidance](https://developer.apple.com/design/human-interface-guidelines/sidebars): a tab bar is worth considering where sidebar space is limited. A custom hidden drawer is unnecessary for this small iPhone library. A larger-screen sidebar can be considered if the catalogue grows.

## First-release requirements

- Each existing lesson appears exactly once, on the path or below it.
- Original lesson IDs and lesson numbers stay stable: Humming 1–2, Rhythm 3–5 and Cello 1–4. The path shows a step's place in its level; lesson pages keep the lesson number. Saved ratings, raw media, references and earned completion are unchanged.
- The path and next actions share the same lesson-opening action. Humming Lesson 2 can still recommend Rhythm Lesson 3.
- A navigation area never supplies a recording pitch target. Existing voice/cello target rules stay separate from the new `LearningArea` model.
- Leaving practice cancels unfinished rounds/count-ins. A take already finishing saves under its original exercise and reference.
- A melody level shows only steps that work today. It has no inactive control and no fabricated readiness percentage.
- Choosing an already selected lesson from the path starts a fresh ready screen; it does not reveal a stale result.

Success is verified through navigation tests, saved-history compatibility checks, screen inspection and physical-device installation. No analytics service or new learner-data collection is required.

## Progression

Hot Cross Buns is the first proposed three-note melody. A beginner method’s published contents place open-string work, D-string notes, bowing and fingering before that tune; this supports preparation before whole-piece performance. See [Mel Bay’s method contents](https://www.melbay.com/Products/21499BCDEB/modern-cello-method-grade-1.aspx). The app will use its own arrangement and references, with provenance verified before distribution.

Each piece will develop through hearing/humming, tapping its actual rhythm and playing on cello. A comfortable vocal register may differ from the cello register; the selected reference must be explicit. Existing foundation achievements are reusable preparation, while phrase and piece performances earn their own results.

Bach is a longer-term destination through easier repertoire, note reading, scales/arpeggios, bow control, string crossings and phrasing. The [ABRSM cello syllabus from 2024](https://www.abrsm.org/sites/default/files/2023-10/Practical%20syllabus%20Bowed%20Strings%202024%20%283%20Cello%29%2020230901.pdf) provides context for the full Prelude’s advanced level. The app does not claim exam equivalence or predict how quickly a learner will be ready.

## Dependent deliveries

| Issue | Delivery | Depends on |
| --- | --- | --- |
| [#2](https://github.com/RonildoBraga/cello/issues/2) | Music library, separate Rhythm, foundation scores and piece-roadmap pages | Existing exercises |
| [#3](https://github.com/RonildoBraga/cello/issues/3) | Original first-melody score/event model and manual reference playback | #2 |
| [#4](https://github.com/RonildoBraga/cello/issues/4) | Phrase listening/humming and melody-aware assessment | #3 |
| [#5](https://github.com/RonildoBraga/cello/issues/5) | Piece rhythm, durations and spaces | #3 |
| [#6](https://github.com/RonildoBraga/cello/issues/6) | Cello prerequisites and a complete first-melody performance | #3–5 and physical cello validation |
| [#7](https://github.com/RonildoBraga/cello/issues/7) | Intermediate repertoire and teacher-reviewed milestones toward Bach | First complete melody |

The first-melody reference uses one versioned score, selectable whole/phrase contexts, three explicitly named registers and manual playback. Humming offers one voice, the low one ([issue #48](https://github.com/RonildoBraga/cello/issues/48)); the cello register remains in reference playback. The optional immutable `MelodyPracticeContext` freezes piece, score version, key/register, tuning, expected events, tempo, section and grading version. Reference-only selections from the first release have a nil grading version; new humming takes use melody grading version 1 and a separate frozen `MelodyRating`. Existing sessions remain compatible. A melody context suppresses the fixed-note foundation grader and chart. Melody completion uses its own durable ledger keyed to the complete frozen context. Foundation stars cannot complete piece lessons. Hearing an example is always separate from Record's countdown.

Melody rhythm uses that same immutable reference timeline with a separate rhythm grading version and store. The progress key includes piece, score version, section, tempo, note/rest onsets and durations; voice register and pitch do not split rhythm progress. Four count-in beats precede each full-length round, and the pad remains active through the final held note. The current arrangement has no notated rests: a longer note continues sounding while the learner counts without another tap. Tap-only feedback measures note starts and timing, not sustained-note duration. See [the rhythm assessment](melody-rhythm.md).

## Second melody: Ode to Joy opening

[Issue #14](https://github.com/RonildoBraga/cello/issues/14) adds our independently encoded five-note opening excerpt while the learner waits for a cello. It introduces upward and downward steps across five notes and a dotted-quarter/eighth-note ending. Four bar-sized practice selections build to the sixteen-beat opening; these are practice divisions, not a claim to contain the complete symphonic theme. Both melodies use the same Humming, Rhythm and manual reference pages, charts, fixed grading versions and progress rules.

`MelodyPiece` selects the built-in score before recording. The existing frozen context format is unchanged; each piece keeps a distinct ID and achievements. Hot Cross Buns factory output remains identical, preserving its prior progress keys and ratings. References reuse the existing licensed recorded sources. See [score and recording provenance](ode-to-joy-reference.md). Cello technique and acoustic validation remain in #6.

## Cello orientation

[Issue #17](https://github.com/RonildoBraga/cello/issues/17) delivers the first bounded part of #6: Meet your cello, reached from the Cello foundation list. An original SwiftUI illustration labels eight main parts; manual recorded examples identify C2, G2, D3 and A3 from low to high. Native Back/tab/background cancellation uses the existing shared audio controller. The page never starts capture or saves an attempt. It adds no foundation lesson ID, number, score or completion milestone; all four existing playing lessons retain their history and counts.

The page shows the proposed route into teacher-supported setup, open strings, first notes, short phrases and the complete first melody. [The practical sequence and acoustic validation plan](first-cello-lessons.md) remain drafts for review. This introduction does not complete #6’s setup, technique, cello-performance assessment or real acoustic validation requirements.

## Listen & Echo

[Issue #19](https://github.com/RonildoBraga/cello/issues/19) adds a separate Humming ear-training activity with original two-note and three-note catalogues. Manual, complete Hear playback unlocks Record for that exact frozen pattern. The usual countdown starts capture; [issue #23](https://github.com/RonildoBraga/cello/issues/23) adds the shared live tuning bar during recording, following each note in that frozen pattern. Both levels and voice registers remain selectable between attempts.

The shared melody rater/feedback/chart and audio/video save path are reused. Progress spans eligible patterns within a level and voice register, with a separate EchoProgress.json ledger; Echo achievements do not enter song or foundation ledgers. Existing lesson IDs/numbers and song contexts are unchanged. Stars describe the recorded notes, timing and clarity, not a direct measurement of musical memory. See [the design, sources and validation boundaries](listen-and-echo.md).

## Capture

[Issue #35](https://github.com/RonildoBraga/cello/issues/35) decided what each activity records. Humming lessons, piece humming and Listen & Echo record the microphone only: they ask for no camera permission, save a sound-only take and export no video frames. Open-string cello lessons record microphone and camera together, because video is what lets a learner or teacher review posture and bowing. Recordings made by earlier builds keep their video. Tapping rounds record nothing.
