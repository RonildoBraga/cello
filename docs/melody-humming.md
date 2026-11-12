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

## The teacher's note

Under a take's stars the app says what a teacher would: the thing that mattered most with what to try, then at most one more thing, then a line when it is a habit (`TeacherNote`). A real take that used to get "The first note (B2) was a little too low" now reads:

> Notes 2 and 3 began about 0.4 s late, and before note 2 your voice slid up first. Move straight to the next note as its bar reaches the line.
>
> Also: B2 was a little low. Hear the start again and begin on its pitch. A2 and G2 were right.

Every word comes from what the rater measured and saved with the take, so the same take always gets the same note, it works offline, and it can be tested. Nothing is said that was not heard: no claims about breath, posture or bowing.

- **What it can say.** Notes not heard as notes of their own; notes that began late or early, and by how much; notes cut short; notes low or high, a little or a lot, and which were right; a note that wavered; notes not clear enough to hear; a slide or other stray sound before a change; a different octave; a take that could not be scored.
- **What leads.** Only goals that were missed are explained. The finding that touched the most notes comes first, and the next one follows as "Also:". Three things cost no star and come as an "Also:": a stray sound, unless it came before a late note, where it is said beside the lateness; a note off its pitch while the Notes goal was still reached, since one note in five may miss; and, for the same reason, a note not heard at all while the goals were still reached, most often two quick notes run together into one.
- **Names and numbers.** Notes go by name (B2) where the melody uses each name once, and by number where it repeats one, with the name when they share it ("Notes 8 and 9 (E3)"). A short phrase also hears what went right.
- **Voice or cello.** A slide is "your voice slid up first" for the voice and "a higher note sounded first" on the cello. A flat or sharp open string (C2, G2, D3, A3) is told to check its tuning, since it cannot be fingered higher.
- **A habit.** When the takes just before, on the same part and scored by the same rules, had the same main point twice or more in a row, the note ends "The same was true of your last 2 takes."

Listen & Echo keeps its own wording. A backend with a language model was considered for this and set aside: a model cannot measure cents or tenths of a second, the app promises that recordings stay on the phone, and the measurements were already there. What was missing was the step from measurements to teaching.

## The live tuner after a take

After a take the live tuner sits inside the take's chart card, under the chart: look at the take, then try the correction at once. It compares the voice with one note. A take with several different notes (a pair in Meet the notes, a phrase, the whole melody) shows them as "Tune to" chips, in the order they first sound; the first is chosen to begin with. If the microphone has been turned off, the row offers to turn it on. Before and during a take there is nothing to choose: the tuner follows the score by itself. Listen & Echo has no tuner after a take.

The tuner's bar and the take's chart both draw the band that counts: 70 cents either side of a melody's note (`MelodyRecordingRater.matchCents`), 25 for one held note (`RecordingRater.matchCents`). The bar used to mark only its centre and call a sound "close" within 10 cents, so it looked far stricter than the scoring is; "close" now means inside the band. Nothing about scoring changed.

In a noisy room the tuner shows a note only when the sound stands clear of the room, and the count-in and the result say that the room is noisy. See [background noise](background-noise.md).

## Assessment version 1

Saved media is decoded to 48 kHz mono PCM on the movie timeline. Leading silence is retained; missing media cannot be concatenated into an apparently continuous note. The grader uses the frozen expected interval without shifting the learner's start, transposing the hum or folding octaves onto the target. Codec/file-output sound after the expected end does not change the exercise result; the complete original media remains available.

Pitch windows and short RMS cells describe actual sound independently of the target. Silence, amplitude reattacks and sustained pitch changes identify note boundaries. Repeated-note phrases require separate articulations; one long held note cannot substitute for eight quick notes. Transition windows receive a small allowance rather than inventing a stable pitch across a change.

- Notes checks the independently detected sequence against the selected pitches. A note needs sufficient detected sound with at least 75% of its usable pitch within 70 cents; at least 80% of notes must match. Extra notes count against the sequence.
- Timing checks absolute note onsets within 200 ms (175 ms for half-beat notes at 60 BPM), sound coverage and completion of note lengths. A late correct sequence can earn Notes while losing Timing.
- Clarity checks enough confident, unambiguous voicing through each note. Insufficient sound, clipping, mostly unpitched noise or substantial competing-octave evidence remains unscored, with progress unchanged.

A clearly measured octave mismatch remains in its original octave and receives explicit feedback. The chart plots the frozen target and saved-audio observations; uncertain frames and silence break the observed trace. These are beginner practice goals, not a complete judgment of singing, tone or technique.

### Octave slips

As a hum fades, its first overtone can outlast it, and for a frame or two the detector reads the note an octave high. In 9 of 58 saved takes such a reading, 150 ms or shorter, sat next to the real note; in one it was counted as an extra note and turned a three-star take into none. A voice cannot leap an octave and back that fast, so frames that read an octave away from the sound beside them for 150 ms or less are marked ambiguous: they are not a note, not a point on the chart, and never folded onto the target. A note really held an octave away is unaffected. This corrects the measurement, not the rubric, so the grading version is unchanged and saved ratings keep the grade they were given.

## Assessment version 3: fresh starts, settled pitch, quick notes

A learner stuck on Hot Cross Buns' quick third phrase asked for a wider pitch tolerance. Measured against every saved take, the tolerance was not the obstacle: widening 70 cents to 100 would have rescued at most 10 of 41 takes that missed Notes, and at most 1 of 12 phrase takes. Three other things were.

- **A fresh start was only heard after near-silence.** In the take that prompted this, three of seven fresh starts dipped about 10 dB, plain to a listener, and the rater heard one long note: notes 6 to 8 "not heard", all three stars lost whatever the pitch. A dip now counts: the level (over 30 ms) falls under half the note's own level (the middle of its last 200 ms, so a starting burst is not the measure) for 30 ms and climbs back to 60% of it. The start is placed at the bottom of the dip. A held note's level wanders too, and believing every dip split real three-star takes in two, so a dip counts only within a start's timing allowance of a note the score has, and only if nothing has begun there yet. The sound must still show the start; the score only says where one is believable. One sustained note still cannot stand in for eight.
- **A slide into a note counted against it.** Pitch is now judged on the last three fifths of what was heard of a note. Where the note settles still has to be within 70 cents.
- **Quick notes were held to a long note's coverage.** Starting a note afresh costs about a tenth of a second whatever its length. A note shorter than 0.75 s needs half its interior voiced (not 70%) and 45% sounding (not 60%), and a take containing such notes may be 65% voiced overall (not 80%).

When some notes are not heard as notes of their own, the advice says so ("5 of the 8 notes were heard. Give each note a clear start of its own.") before any advice about pitch.

Re-scoring the 76 saved takes with these rules, 9 gain stars and none lose. The prompting take goes from no stars to Timing and Clarity, a pass, with Notes still missed for being 50 to 100 cents sharp. Its neighbours, a quarter of a second late throughout, earn one star. With the app's examples under added hiss, quick notes and the jump now keep three stars where they scored none, because a dip survives hiss that fills the silence. Rumble, a second voice and knocks are unchanged ([background noise](background-noise.md)).

Earlier takes keep the scores they were given. Progress is not reset: see below.

## Assessment version 4: each heard note is paired with the note it was

Versions up to 3 matched heard notes to asked notes strictly in order. One stray sound, such as the voice sliding up before stepping down, was taken for the next note, and every note after it was set against the wrong one. In the take quoted above that turned a fair "Clarity earned, two changes late" into no stars and advice about the first note's pitch.

The rater now pairs the two lists, each kept in order, at the least cost (`MelodyRecordingRater.pair`). Against an asked note, a heard note costs 1 for the wrong pitch and up to 1 more as its start moves from the timing allowance to a whole note's length away. Leaving an asked note unheard, or a heard note unasked, costs 1. So notes sung in time pair with their own places whatever their pitch, and the right notes sung late still pair note for note, leaving the lateness for Timing to judge.

A **stray** is a heard sound with a clear pitch for less than a quarter of a second (or 40% of the shortest asked note, if that is less): too short to be a note. Leaving a stray unasked costs a quarter, it costs no star, and it is saved with the take (`MelodyRating.strays`, an optional field) so the note can mention it and the chart can mark it "extra". A real extra note still counts against Notes and Timing. A missed note now leaves the notes around it their own.

Re-scoring 80 saved takes, 7 gain stars and 1 loses one (a take with nine sounds where eight were asked, 1 star to none). With the app's examples under noise, low rumble 13 to 18 dB below the hum and knocks as loud as the hum no longer cost held notes and simple phrases their stars: the bursts are strays, not extra notes.

## Persistence and progression

Each session stores its immutable melody context, versioned result, per-note observations and saved-audio pitch points. Fixed-note `rating` stays nil for melody takes. Legacy recordings omit the new optional fields and remain readable.

Three three-star takes among the last five rated takes earn completion for the exact piece, score version, phrase, register/key, tuning, tempo and expected events. Progress belongs to the lesson, not to the rules of the day: takes scored under versions 2 to 4 count towards the same pass and gold (`MelodyRating.progressVersions`), under the key version 2 wrote, so a new version resets nothing. Version 1 takes stay readable and count for nothing, as before. Unscored takes do not consume that window. A separate MelodyProgress.json ledger preserves completion after deletion and reload. An unreadable ledger or failed write preserves the evidence instead of silently discarding an earned milestone. All phrases remain available, with a next-phrase suggestion.

## Validation

Deterministic tests cover correct phrases in both registers, wrong notes/order, missing and extra notes, repeated-note articulation, late starts, shortened notes, fast performances, rests, clipping, noise, silence, competing octaves and post-roll. Storage tests cover real audio/video decoding, save/reload/export, context isolation and durable completion. Chart tests cover gaps, rests, invalid measurements and wrong octaves.

A scoring change is also checked on real takes: `cello-rescore` (in `Packages/CelloPitch`) re-scores every saved take in a folder with the checkout's rater and lists the takes whose stars change. The numbers quoted for versions 3 and 4 above come from it.

Local validation also uses controlled phrases assembled and transposed from the licensed human humming example, plus unchanged learner single-note recordings as negative controls. Assembled fixtures test human phonation under known conditions; they are not spontaneous performances or a substitute for checking new learner melody takes. Personal recordings and local verification outputs are excluded from Git. Physical microphone, speaker, camera and timing behavior still require an iPhone take.

## Other built-in melodies

Ode to Joy uses the same assessment and result presentation for its five-note opening. Select it from Music, then Humming. The existing frozen piece ID, events, register, tempo and grading version keep scores separate from Hot Cross Buns; adding the piece changes neither grading version nor old history. Each four-second selection leads to the sixteen-second opening. Reference playback remains a separate Hear action. See [the opening arrangement](ode-to-joy-reference.md).

Twinkle, Twinkle is assessed the same way. Its first phrase jumps five notes (G2 to D3). The rater finds a new note from the sound alone, a fresh start or a lasting change of pitch of a semitone or more, so a jump needs no rule of its own. See [the opening arrangement](twinkle-reference.md).

Lightly Row is assessed the same way. Its skips are a minor third, three semitones, well beyond the one-semitone change the rater listens for, and its repeated notes are a beat apart, like Twinkle's. See [the opening arrangement](lightly-row-reference.md).

Old MacDonald is assessed the same way. Its leap of a sixth, nine semitones, comes between two phrases, so practised phrase by phrase it is heard only in Meet the notes and the whole line. See [the arrangement](old-macdonald-reference.md).

Yankee Doodle is assessed the same way. Most of its notes last half a second and change pitch, so each new note is found by its change of pitch rather than by a fresh start; quick notes get the same room for their starts as Hot Cross Buns' repeated ones. See [the arrangement](yankee-doodle-reference.md).
