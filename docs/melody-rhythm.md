# Melody rhythm

Open **Music → Hot Cross Buns → Tap it**. Choose any of four phrases or the whole melody, hear the recorded human-voice reference if needed, then press Start. Playback is manual and never part of Start. The round uses four count-in beats at 60 BPM, whole-beat haptics and the complete score duration: four seconds per phrase or sixteen for the melody.

Tap once at each note's start. Proportional tiles show note lengths in beats; the active tile follows the score clock. A two-beat note needs one tap, followed by counting while it continues. The current arrangement has no notated rests. The model also supports rests and gaps, which do not create expected taps. This exercise assesses starts, not how long a note is sustained.

## How a round is shown and measured

These apply to every tapping lesson, the Level 1 rhythm lessons included. They came from reading 51 real rounds in which taps looked late every time, first notes were missed and the feedback did not say why.

- **A tap is timed when the finger lands.** The pad reads the touch's own timestamp. It used to be a button, which reports when the finger lifts and only after the scroll view lets the touch through; that added roughly a tenth of a second to every tap.
- **The count-in counts up, 1 2 3 4**, and the first tap falls on the next 1. A lane under the count shows each tap as a dot travelling towards a fixed line, with the count-in travelling the same lane, so a tap can be met rather than reacted to. Dots turn gold when hit and hollow when missed.
- **The first note may be tapped a touch early**, like every other note. The pad used to open at the exact instant of the first note, so a tap a few hundredths early did nothing.
- **Feedback names the mistake** (`TapDiagnosis`): starting a beat late, a missed first tap, taps where no note starts, extra taps in Mixed rhythm's gaps, missed taps, taps late or early and by how much, or the taps between beats drifting. It names the first that explains the lost star and says how to fix it.

The star rules below are unchanged. Rounds saved before this change keep the offsets and stars they were given.

## Version-one stars

Each completed round freezes its score, taps and rating in `Documents/MelodyRhythmPractice.json`.

| Goal | Rule |
| --- | --- |
| Pattern | Match at least 80% of note starts, rounded up, with zero extra taps. |
| Timing | At least 75% of matched taps fall within 150 ms of their expected start. |
| Consistency | The 10th-to-90th percentile range of timing offsets is at most 200 ms. |

At least three actual taps are needed to rate the current phrases. Timing and Consistency also require three matched starts. A shorter future phrase uses its number of expected starts instead. Clearly misplaced taps can earn zero stars; insufficient taps remain unrated. Consistency uses offsets from the score, so an intentional short interval is not penalized as uneven spacing.

Touches are measured with monotonic uptime against absolute score times. Matching windows are at most 450 ms and shrink to 45% of the closest note interval, leaving a gap between quick-note windows. Callbacks within 50 ms of the previous accepted touch are ignored as duplicates; later separate presses are counted. Count-in taps are ignored. Taps remain observable through the exclusive phrase end, including the extra beat of a long final note. Extra taps prevent the Pattern star.

The chart places matched offsets at their expected score times, includes missing-note markers and spans the full phrase. Negative offsets are early, positive offsets late; a shaded band marks ±150 ms. Extras are reported separately because an unmatched touch has no defensible offset from a particular note.

## Progress and cancellation

Three three-star rounds among the last five rated rounds complete that phrase and tempo. Unrated rounds do not move the five-round window, and earned completion survives later misses. Every phrase stays selectable. Best and latest scores are visible on return.

Progress keys include piece ID, score version, section, tempo, rhythm grading version, event onsets, durations and rests. Voice register, pitch and tuning do not split rhythm progress. Humming and foundation files are neither read as achievements nor modified. Saved version-one ratings are validated against the fixed version-one rules; changed grading requires a new version. Corrupt history is preserved and saves fail visibly without publishing invented progress.

Stop, leaving the screen, switching tabs, or backgrounding cancels an unfinished round without saving it. The shared audio controller stops playback on exit. A completed round saves once, using a fixed attempt ID. No microphone or camera permission is required for rhythm practice.

## Verification

Unit tests cover score-derived tap positions, half-beat notes, rests/gaps, phrase ends, debouncing, missing/extra taps, grading, versioned persistence, failed saves and isolated progress. UI tests exercise the actual clock, manual playback, navigation, completed rounds and cancellation. Simulator checks do not verify physical haptic or speaker quality.

## Ode to Joy opening

The second piece reuses these rounds and fixed version-one rules. Its first three selections have four one-beat notes. The last has lengths `1.5, 0.5, 2` beats, so its starts are at `0, 1.5, 2` seconds at 60 BPM: tap on 1, the “and” after 2, and 3, then count through 4. The full opening has fifteen note starts in sixteen beats. Progress uses its own piece ID; Hot Cross Buns achievements stay separate. See [the opening arrangement](ode-to-joy-reference.md).

## Twinkle, Twinkle opening

The third piece adds no new rhythm. Selections 1 and 3 have four one-beat notes; selections 2 and 4 have two one-beat notes and a two-beat note, the pattern of Hot Cross Buns' first phrase. The hint shown before Start is chosen from the lengths of a selection's notes, so each of these reads as it does in the earlier pieces. The opening has fourteen note starts in sixteen beats. See [the opening arrangement](twinkle-reference.md).

## Lightly Row opening

The fourth piece adds no new rhythm either. Selections 1, 2 and 4 have two one-beat notes and a two-beat note; selection 3 has four one-beat notes. The opening has thirteen note starts in sixteen beats. See [the opening arrangement](lightly-row-reference.md).

## Old MacDonald first line

Selections 1 and 3 have four one-beat notes and selection 2 two one-beat notes and a two-beat note. Selection 4 is new: one note held for all four beats. It asks for a single tap, and the hint says to count 2, 3 and 4 while the note continues; a tap in those beats is an extra tap and costs the Pattern star. One tap is enough for the other two goals: the round is scored once it has as many taps as notes, up to three. The line has twelve note starts in sixteen beats. See [the arrangement](old-macdonald-reference.md).

## Yankee Doodle first strain

Selections 1 and 3 have eight half-beat notes, the rhythm of Hot Cross Buns' third selection. Selections 2 and 4 are new: four half-beat notes, then two one-beat notes. The hint says to tap two short notes per beat on 1 and 2, then tap on 3 and on 4. The strain has 28 note starts in sixteen beats, the most of any melody. See [the arrangement](yankee-doodle-reference.md).

## G major scale

Every selection has four one-beat notes, so every hint is to tap on each beat. The scale has sixteen note starts in sixteen beats. See [the scale](g-major-scale-reference.md).

## Prelude chords

Every selection has four one-beat notes, like the scale. See [the excerpt](prelude-chords-reference.md).

## Prelude opening

Every selection has eight half-beat notes: two short notes per beat, the rhythm of Hot Cross Buns' third selection. The opening has 32 note starts in sixteen beats. See [the excerpt](prelude-opening-reference.md).
