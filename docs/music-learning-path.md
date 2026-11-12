# Music learning path

Status: Music organisation, first-melody reference playback, humming phrase recording/feedback and melody rhythm practice delivered. A five-note Ode to Joy opening now reuses the same phrase and whole-selection practice. Cello playing remains planned in [the delivery epic](https://github.com/RonildoBraga/cello/issues/1).

## Problem and goal

Voice and rhythm exercises currently share a Humming section, while the library offers no connection between isolated skills and music to play. A beginner needs to find the right practice, keep earned progress and understand how each skill contributes to a first melody and later repertoire.

The first delivery separates Humming, Rhythm and Cello inside a Music library. It adds a first-piece path for Hot Cross Buns and a longer-term path toward Bach’s Cello Suite No. 1 Prelude, BWV 1007. These are learning goals; a completed tap exercise is not evidence of performing a new melody.

## Navigation

```text
Music (the path)
  Level 1 · First sounds      Steady note → Listen & match → Pulse → Two taps per beat → Mixed rhythm → Listen & Echo
  Level 2 · Hot Cross Buns    Listen → Tap it → Meet the notes → Hum it → Whole melody
  Level 3 · Ode to Joy        Listen → Tap it → Meet the notes → Hum it → Whole melody
  Level 4 · Twinkle, Twinkle  Listen → Tap it → Meet the notes → Hum it → Whole melody
  Level 5 · Lightly Row       Listen → Tap it → Meet the notes → Hum it → Whole melody
  Level 6 · Old MacDonald     Listen → Tap it → Meet the notes → Hum it → Whole melody
About → long-term goal, who built it, sound sources and licences, lesson references
Recordings → existing local audio/video history
```

The path replaced separate Foundations and Pieces libraries ([issue #49](https://github.com/RonildoBraga/cello/issues/49), design note [#53](https://github.com/RonildoBraga/cello/issues/53)). A `Level` is a title and an ordered list of `PathLesson`s, and each lesson opens a screen that already existed: a lesson page, Listen (the reference player), Tap it (melody rhythm), Meet the notes, and Hum it or Whole melody (melody humming opened at phrase 1 or at the whole melody). Adding a melody adds one level with the same lessons.

The level holding the first unfinished lesson opens when the path appears, and that lesson is marked Continue. It is a suggestion only: every level can be opened and every lesson tapped.

Everything belongs to a level. An earlier version kept the cello lessons, Mixed rhythm, Listen & Echo, a note about Bach and the credits below the levels; on the phone that read as clutter with no place in the journey. Mixed rhythm and Listen & Echo now close Level 1, the cello is the last level because it needs an instrument, and the Bach note and credits moved to an About tab beside Music and Recordings (an info button on Music was tried first and took too much room). Listen & Echo is passed by a passing two-note take; Meet your cello is passed by reading it.

Every lesson uses one compact row, whatever it opens: lesson number, title, progress in words and the best score out of three. A lesson made of phrases or notes shows the weakest best score across them, so three stars means every part reached three. Listen and Meet your cello are not scored and show no stars. A level's lessons share one card, so a whole level fits on a screen.

### Voice or cello

Humming and playing are two ways to do the same lesson, not two paths. Every lesson with a sound to hear or record (Steady note, Listen & match, Listen & Echo, Listen, Meet the notes, Hum it, Whole melody) carries the same Voice / Cello switch in its navigation bar (`PracticeMethod`, `PracticeMethodSwitch`). Listen used to have a picker of its own for the same choice. It sits apart from the chips and is drawn as a segmented control, because it is a different kind of choice: how to practise, not what to hear. The lesson, its goals and its place on the path stay the same; the reference sound, the wording, the tuner and what is recorded follow the choice. Tapping lessons have no switch. The switch is live except while a take is recording; changing it stops whatever is playing.

- **Single-note lessons** (Steady note, Listen & match): by voice, one hummed note; on the cello, the four open strings as chips (C, G, D, A), stepped through by the lesson bar as "String 1 of 4". Both lessons use the same four strings, so a string passed in one is passed in the other. This replaced a separate fourth level of open-string lessons.
- **Melody lessons and Listen & Echo**: the same notes, phrases and patterns in the cello register (D major on the D string, the register the Listen lesson already offered), each with its own progress.

Progress is kept for each method under its own exercise or register, so switching loses nothing. Either method passes the lesson, and the path row shows whichever has got further. The switch starts on the method of the most recent take and stays as chosen until the app is closed; no setting is stored. A cello take is filmed; a voice take is audio only, so switching releases the microphone and camera. Meet your cello is no longer a lesson: it opens from the information button in the bar while Cello is chosen.

Not yet settled: the cello plays the melodies in D major and the voice hums them in G major, which is usual in beginner cello books but worth a teacher's view; and scoring was tuned on humming and has not been checked against a real cello recording.

### How the path is drawn

`PathProgress` reads every lesson's progress from the stores once for each drawing of the path; the rows, Today's practice and the lesson bar share that one reading. The stores answer from an index of the takes and rounds that they rebuild only when a take is saved or deleted (`SessionProgressLedger.stars(in:)`, `MelodyRhythmStore`), so a lesson's progress is a lookup.

This matters because of how it once went wrong. The path screen observed the capture controller, which publishes about twenty times a second while a take records or a reference plays. Each tick redrew the path behind the lesson, and each drawing worked out every lesson's progress several times over, each time re-encoding and hashing every saved take. With 17 takes that was about 100 ms of work per tick in a debug build: the main thread had no time left and the moving lane fell to 6–8 frames a second. Today's practice and the voice/cello choice each added to the work per drawing until it showed. Now the app owns the capture controller unobserved, the path screen never redraws on a tick, and a full reading of the path takes about 3.5 ms.

### Today's practice

Above the levels, a "Today's practice" card answers what to do now. It lists the next lesson on the path, then up to two passed lessons with the lowest best score, earliest first (`Level.today`). Each row is the same row the path uses and opens the same screen. A lesson leaves the list once its best score reaches three stars, so the list changes as the practice is done; no dates or streaks are kept. Unscored lessons (Listen, Meet your cello) are never offered again, and the card disappears when nothing is left. The card replaced the sentence that explained the path.

### Inside a lesson

Every lesson's screen opens with the same header (`LessonHeader`): the level ("Level 1 · First sounds"), the lesson's title and one plain line about what to do. A lesson bar, "‹ Lesson 1 of 6 · Listen & match ›", is pinned at the bottom just above the main button, where the thumb already is; it was first tried under the title, where it pushed the practice area down. The shared bottom action bar adds it on any screen that belongs to a lesson, and holds it still while a take or round is in flight. The arrows move to the previous and next lesson of the level and fade at its first and last lesson. Moving with the bar replaces the screen, so Back always returns to Music. A lesson's page, with instructions and scores, is what a tap on the path opens; its Start button also leads to a practice screen directly above the path.

Under the practice area one line reports both tiers in words: "Passed · Gold: 2 of 3 three-star takes".

The lesson bar is the only control for moving on. A lesson with several parts (the four phrases of Hum it, the five parts of Tap it, the notes of Meet the notes) passes them to the bar as `LessonParts`: Next steps through the parts, then to the next lesson, then into the next level, and Previous goes back the same way. The bar shows "Lesson 2 of 5" with "Part 1 of 5" beneath it. A separate "Try Whole melody" link under the result used to offer the next part; it looked like a different lesson and was removed. For the same reason Tap it's last part is called "All phrases", and Hum it lists only its phrases: Whole melody is the next lesson.

A lesson's parts are shown side by side as chips (`PartStrip`): the one on show is filled, passed parts carry a tick and gold parts a star, and a tap switches. They replaced a drop-down menu, which hid the other parts and their progress behind a tap and looked like a setting. On Meet the notes the chips are the note names, so the separate note tile and the "3 seconds" label were removed.

A chip is also how a part is heard. Tapping a chip switches to it and plays it; the chip on show carries a speaker and plays again when tapped. The separate "Recorded hum · Hear note" row is gone from every lesson with chips, and a lesson with one thing to hum (Steady hum, Listen & match, an open string, Whole melody) shows one chip. On Listen & Echo the chips are the pattern lengths (Two notes, Three notes): the notes stay secret, and the chip plays the pattern. Moving with the lesson bar does not play anything, and neither does opening a lesson.

### Moving on

Once a lesson is passed, Next on the lesson bar becomes a solid button ("Next: Listen & match"). At the last lesson of a level it leads into the next level. There is no celebration animation and no level-complete card: fireworks and a star animation were tried and removed as decoration. The path's ticks, the gold mark and the highlighted Next say what happened.

### Primers

Level 1 starts from zero ([issue #52](https://github.com/RonildoBraga/cello/issues/52)). Each of its four lessons introduces one idea, and opens the first time with a one-screen primer: **A note** (with pitch and cents, which the tuning bar uses), **Higher and lower**, **A beat** and **Two taps per beat**. A primer is a few plain sentences, one button to hear or feel the idea, and Continue into the lesson. The sound primers reuse the recorded hum; the beat primers count on screen with a vibration on each beat. Nothing is recorded or scored.

The content is `PracticeLesson.primer`; the screen is `PrimerView`. Reading a primer is remembered as a preference, and the lesson page offers it again under "New to this?". A unit test checks that no Level 1 lesson's own copy uses pitch, beat, cents, register, BPM or pulse before a primer has explained it.

### Meet the notes

Each melody level introduces its notes before asking for whole phrases ([issue #51](https://github.com/RonildoBraga/cello/issues/51)): three for Hot Cross Buns (G2, A2, B2), five for Ode to Joy (G2 to D3), six for Twinkle, Twinkle (G2 to E3), five for Lightly Row (G2 to D3), five for Old MacDonald (G2 to E3). For each note the learner hears the recorded hum and hums it back for three seconds with the live tuning bar. Two pairs follow, to hear and feel "higher" and "lower": the melody's jump and its reverse, or, for a melody that moves only by step, its lowest then its highest note and the reverse. A jump is two notes in a row more than a whole tone apart. Twinkle's is G2 to D3, Lightly Row's a skip, D3 down to B2, and Old MacDonald's a leap of a sixth, G2 up to E3; Hot Cross Buns' only jump is between its lowest and highest notes, and Ode to Joy has none. Last come the notes the melody repeats quickly, each on its own (`NoteDrill.quickRepeats`): for Hot Cross Buns, eight quick G's and eight quick A's. Ode to Joy has none.

The quick notes are there because of what the takes showed. Hot Cross Buns' third phrase is four quick G's then four quick A's, and it asked for three new things at once: twice the speed, starting the same note afresh, and a change of note halfway. A learner who had passed phrases 1 and 2 scored nothing on it three times, although the first of those takes had every note within 0.07 s of its place. A closed-lip hum has nothing to restart a note with, the learner left long gaps to compensate, and the gaps cost the Timing and Clarity stars. So the repeat is now practised alone first, and wherever a take repeats a note quickly the screen says how (`VoicePracticeMode.quickNotesHint`): sing "doo", and keep each note going until the next one starts. Eight notes, not four, because each goal lets one note in five miss: eight leaves room for one slip.

A `NoteDrill` is a short `MelodyPracticeContext` with its own piece ID (`hotCrossBuns.notes`), so the recorder, the melody rater, the result card, the chart and the melody ledger are the ones phrases use. Takes appear in Recordings as "Hot Cross Buns · Meet the notes · G2". The lesson is passed when every note has a passing take; the pairs and the quick notes are extra practice. Notes are shown as names and tiles; staff notation is out of scope.

### Passed and gold

Progress has two tiers ([issue #50](https://github.com/RonildoBraga/cello/issues/50)), both defined once in `CompletionRule` and both computed from attempts that are already saved:

- **Passed** moves the path on: one scored attempt with two stars or more. Like gold it is an earned milestone, kept in the progress files, so deleting recordings to free space keeps it.
- **Gold** is the earlier completion rule, unchanged: three 3-star attempts among five consecutive scored attempts. It is kept in the existing ledgers, survives later takes and always counts as passed.

A lesson or the whole melody is one part. Tap it and Hum it roll up four phrases: the lesson shows "2 of 4 phrases passed", is passed when all four are, and is gold when all four are gold. Listen is passed once the whole melody has played to its end. A level shows how many of its lessons are passed; when the last one passes, the path shows a completion card once and points at the next lesson.

No saved format changed. Two small preferences hold what no take records: the melodies heard to the end, and the primers and introductions already read.

Music, Recordings and About are the three iPhone tabs. Practice is a screen, not a tab: every activity — a lesson, a melody's Listen, Tap it or Hum it lesson, Listen & Echo — is pushed inside Music and left with Back ([issue #33](https://github.com/RonildoBraga/cello/issues/33)). Starting a lesson pushes a fresh, ready practice screen directly above the path.

An earlier release had a separate Practice tab with its own area and lesson pickers. It was removed because it duplicated the Music tab's lists, could fall out of lesson with the Music tab, and could not host piece or Echo practice.

This is a design choice informed by [Apple’s sidebar guidance](https://developer.apple.com/design/human-interface-guidelines/sidebars): a tab bar is worth considering where sidebar space is limited. A custom hidden drawer is unnecessary for this small iPhone library. A larger-screen sidebar can be considered if the catalogue grows.

## First-release requirements

- Each existing lesson appears exactly once, on the path or below it.
- Original lesson IDs and lesson numbers stay stable: Humming 1–2 and Rhythm 3–5. The four open strings keep their exercise IDs as the cello's side of Steady note. The path shows a lesson's place in its level; lesson pages keep the lesson number. Saved ratings, raw media, references and earned completion are unchanged.
- The path, the lesson page and the lesson bar share the same lesson-opening action.
- A navigation area never supplies a recording pitch target. Voice and cello targets stay separate.
- Leaving practice cancels unfinished rounds/count-ins. A take already finishing saves under its original exercise and reference.
- A melody level shows only lessons that work today. It has no inactive control and no fabricated readiness percentage.
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

[Issue #14](https://github.com/RonildoBraga/cello/issues/14) adds our independently encoded five-note opening excerpt while the learner waits for a cello. It introduces upward and downward lessons across five notes and a dotted-quarter/eighth-note ending. Four bar-sized practice selections build to the sixteen-beat opening; these are practice divisions, not a claim to contain the complete symphonic theme. Both melodies use the same Humming, Rhythm and manual reference pages, charts, fixed grading versions and progress rules.

`MelodyPiece` selects the built-in score before recording. The existing frozen context format is unchanged; each piece keeps a distinct ID and achievements. Hot Cross Buns factory output remains identical, preserving its prior progress keys and ratings. References reuse the existing licensed recorded sources. See [score and recording provenance](ode-to-joy-reference.md). Cello technique and acoustic validation remain in #6.

## Third melody: Twinkle, Twinkle opening

Level 4 is the first two lines of *Twinkle, Twinkle, Little Star*. Each level so far has carried one new idea: three notes stepping down, then five notes stepping up and down. This one adds the first jump, five notes up in one go, which is also the move the Bach Prelude is built from: on the cello it crosses from the open D string to the open A string. Everything else is kept easy on purpose. The rhythm is one beat a note with a held note ending each line, and each register gains a single new note (E3 hummed, B3 on the cello).

It is a third `MelodyPiece` and nothing more: the level, its five lessons, the examples, the charts, the grading and the progress rules come from what the first two melodies use. Two things became general so that a new melody is data. A selection's tapping hint now follows the lengths of its notes (`MelodyPiece.rhythmHint`), so tunes that share a rhythm share its wording; and Meet the notes practises a melody's jump when it has one (`NoteDrill.drills`). The saved formats and grading versions are unchanged. See [score and provenance](twinkle-reference.md).

## Fourth melody: Lightly Row opening

Level 5 is the opening line of *Lightly Row*, the tune of the German song *Hänschen klein*, and the first level of the plan toward Bach's first Prelude ([issue #78](https://github.com/RonildoBraga/cello/issues/78)). It adds skips: from one note to the note after next, twice, before a climb back up by step. Twinkle's jump of a fifth came once; skips are smaller and far more common, and the Prelude's opening is full of larger ones. Its five notes are those of Ode to Joy and its rhythm is Twinkle's, so the skips are the only new thing.

It is a fourth `MelodyPiece` and nothing more, as the plan expected: the tapping hint, the Meet the notes pair, the examples, the grading and the progress rules all come from what is already there. See [score and provenance](lightly-row-reference.md).

## Fifth melody: Old MacDonald first line

Level 6 is the first line of *Old MacDonald Had a Farm*, the second level of the plan ([issue #78](https://github.com/RonildoBraga/cello/issues/78)). It adds bigger jumps: a drop of a fourth in phrase 1, then a leap of a sixth up into phrase 3. The sixth, D3 to B3 on the cello, is the second jump of the Bach Prelude's opening. Every note is one Twinkle already uses, and phrase 4 is a single note held for four beats.

It needed one new thing, as the plan said: a melody names its own key. Old MacDonald sits in G major on the cello and C major for the voice, where every earlier melody is in D major and G major. The key comes from the melody's home note on the cello (`MelodyPiece.keyName(for:)`); earlier melodies keep exactly the keys their saved takes, and so their saved progress, were made under. Two small changes to the teacher's note came with it: notes that share a name are named once ("Notes 8 and 9 (E3)"), and a note that missed while the Notes goal was still reached is mentioned after the praise. See [score and provenance](old-macdonald-reference.md).

## Cello orientation

[Issue #17](https://github.com/RonildoBraga/cello/issues/17) delivers the first bounded part of #6: Meet your cello, reached from the Cello foundation list. An original SwiftUI illustration labels eight main parts; manual recorded examples identify C2, G2, D3 and A3 from low to high. Native Back/tab/background cancellation uses the existing shared audio controller. The page never starts capture or saves an attempt. It adds no foundation lesson ID, number, score or completion milestone; all four existing playing lessons retain their history and counts.

The page shows the proposed route into teacher-supported setup, open strings, first notes, short phrases and the complete first melody. [The practical sequence and acoustic validation plan](first-cello-lessons.md) remain drafts for review. This introduction does not complete #6’s setup, technique, cello-performance assessment or real acoustic validation requirements.

## Listen & Echo

[Issue #19](https://github.com/RonildoBraga/cello/issues/19) adds a separate Humming ear-training activity with original two-note and three-note catalogues. Manual, complete Hear playback unlocks Record for that exact frozen pattern. The usual countdown starts capture; [issue #23](https://github.com/RonildoBraga/cello/issues/23) adds the shared live tuning bar during recording, following each note in that frozen pattern. Both levels and voice registers remain selectable between attempts.

The shared melody rater/feedback/chart and audio/video save path are reused. Progress spans eligible patterns within a level and voice register, with a separate EchoProgress.json ledger; Echo achievements do not enter song or foundation ledgers. Existing lesson IDs/numbers and song contexts are unchanged. Stars describe the recorded notes, timing and clarity, not a direct measurement of musical memory. See [the design, sources and validation boundaries](listen-and-echo.md).

## Capture

[Issue #35](https://github.com/RonildoBraga/cello/issues/35) decided what each activity records. Humming lessons, piece humming and Listen & Echo record the microphone only: they ask for no camera permission, save a sound-only take and export no video frames. Open-string cello lessons record microphone and camera together, because video is what lets a learner or teacher review posture and bowing. Recordings made by earlier builds keep their video. Tapping rounds record nothing.
