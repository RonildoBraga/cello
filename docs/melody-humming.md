# Hot Cross Buns humming

Open Music → Hot Cross Buns → Hum it. Choose any phrase, or join the whole tune. Hear is manual. Record prepares the microphone, counts in 1–2–3–4 at the tempo, and records the selected four-second phrase or sixteen-second melody at 60 BPM. The recording cue starts with the file-output delegate; the file output enforces the selected duration. Navigation and interruptions stop capture safely, while an already finishing take saves under its original reference.

The screen reuses the foundation recorder, shared audio-session controller, proportional note tiles and result-card presentation. Melody-specific assessment, charting and completion are separate from fixed-note and rhythm exercises. All audio/video and raw measurements remain local and export through the existing recoverable save path.

## Seeing when to change note

Saved takes showed the pitch was mostly right while the second note of a pattern started late or early in 19 of 26 takes: nothing said when to change. Every hummed take now shows the same lane the tapping lessons use (`BeatLane`):

- Each note is a bar travelling towards a fixed line. Its length is how long to hold, the gap before the next bar is the pause, and a higher note sits higher. Bars carry their note names.
- The count-in travels the same lane as 1 2 3 4, so the first note falls on the next 1. Between the count-in ending and the recorder starting, the first bar waits at the line; once recording starts the lane follows the recording's own clock.
- A single held note is one bar. Listen & Echo keeps its bars level and unnamed, so the count-in gives nothing away. Cello takes, which run until Stop, have no lane.
- When the Timing star is missed, the feedback names the first note that was off and by how much: "Note 2 (A2) started 0.3 s late. Change as its bar reaches the line." It also covers an early change, a late first note and a note cut short.

The rating rules below are unchanged.

## Choosing what the tuner listens for

Before a take, the live tuner compares the voice with one note. A take with several different notes (a pair in Meet the notes, a phrase, the whole melody) shows them under the meter as "Tune to" chips, in the order they first sound; the first is chosen to begin with. During the take the tuner follows the score by itself, so the chips are gone. A single note has nothing to choose, and Listen & Echo, whose tuner is hidden until the take, offers none.

## Assessment version 1

Saved media is decoded to 48 kHz mono PCM on the movie timeline. Leading silence is retained; missing media cannot be concatenated into an apparently continuous note. The grader uses the frozen expected interval without shifting the learner's start, transposing the hum or folding octaves onto the target. Codec/file-output sound after the expected end does not change the exercise result; the complete original media remains available.

Pitch windows and short RMS cells describe actual sound independently of the target. Silence, amplitude reattacks and sustained pitch changes identify note boundaries. Repeated-note phrases require separate articulations; one long held note cannot substitute for eight quick notes. Transition windows receive a small allowance rather than inventing a stable pitch across a change.

- Notes checks the independently detected sequence against the selected pitches. A note needs sufficient detected sound with at least 75% of its usable pitch within 70 cents; at least 80% of notes must match. Extra notes count against the sequence.
- Timing checks absolute note onsets within 200 ms (175 ms for half-beat notes at 60 BPM), sound coverage and completion of note lengths. A late correct sequence can earn Notes while losing Timing.
- Clarity checks enough confident, unambiguous voicing through each note. Insufficient sound, clipping, mostly unpitched noise or substantial competing-octave evidence remains unscored, with progress unchanged.

A clearly measured octave mismatch remains in its original octave and receives explicit feedback. The chart plots the frozen target and saved-audio observations; uncertain frames and silence break the observed trace. These are beginner practice goals, not a complete judgment of singing, tone or technique.

## Persistence and progression

Each session stores its immutable melody context, versioned result, per-note observations and saved-audio pitch points. Fixed-note `rating` stays nil for melody takes. Legacy recordings omit the new optional fields and remain readable.

Three three-star takes among the last five rated takes earn completion for the exact piece, score version, phrase, register/key, tuning, tempo, expected events and grading version. Unscored takes do not consume that window. A separate MelodyProgress.json ledger preserves completion after deletion and reload. An unreadable ledger or failed write preserves the evidence instead of silently discarding an earned milestone. All phrases remain available, with a next-phrase suggestion.

## Validation

Deterministic tests cover correct phrases in both registers, wrong notes/order, missing and extra notes, repeated-note articulation, late starts, shortened notes, fast performances, rests, clipping, noise, silence, competing octaves and post-roll. Storage tests cover real audio/video decoding, save/reload/export, context isolation and durable completion. Chart tests cover gaps, rests, invalid measurements and wrong octaves.

Local validation also uses controlled phrases assembled and transposed from the licensed human humming example, plus unchanged learner single-note recordings as negative controls. Assembled fixtures test human phonation under known conditions; they are not spontaneous performances or a substitute for checking new learner melody takes. Personal recordings and local verification outputs are excluded from Git. Physical microphone, speaker, camera and timing behavior still require an iPhone take.

## Other built-in melodies

Ode to Joy uses the same assessment and result presentation for its five-note opening. Select it from Music, then Humming. The existing frozen piece ID, events, register, tempo and grading version keep scores separate from Hot Cross Buns; adding the piece changes neither grading version nor old history. Each four-second selection leads to the sixteen-second opening. Reference playback remains a separate Hear action. See [the opening arrangement](ode-to-joy-reference.md).
