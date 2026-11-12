# Yankee Doodle first strain score and reference

*Yankee Doodle* is an 18th-century tune. Cello uses its own unaccompanied teaching arrangement of the tune's first strain, rendered with the existing licensed recorded human and cello sources. No words, score image, accompaniment, fingering or source performance is bundled.

## Why this tune is Level 7

It brings running notes: a new note every half beat for most of the tune, changing pitch as it goes. Hot Cross Buns had quick notes, but they repeated one pitch. Here the notes climb, turn and drop while they run, which is how the opening of Bach's first Prelude moves. Each register gains one new note: F3 for the voice and C4 on the cello. It is the third level of the plan in [issue #78](https://github.com/RonildoBraga/cello/issues/78), built for [issue #81](https://github.com/RonildoBraga/cello/issues/81).

## Arrangement version 1

The scale-degree pattern is `1 1 2 3 1 3 2 5 | 1 1 2 3 1 7 | 1 1 2 3 4 3 2 1 | 7 5 6 7 1 1`, where the 5, 6 and 7 lie below the first note. Every note lasts half a beat, except the last two of phrases 2 and 4, which last one beat each: 28 note starts, seven distinct pitches, four 4/4 bars and 16 beats. Each bar is one practice selection, with boundaries at 0, 4, 8, 12 and 16 beats. There are no notated rests.

The tune is usually written in 2/4 with eighth notes. Two bars of 2/4 fill one bar of the app's 4/4, and every eighth note is half a beat at 60 BPM.

The pattern was checked against the first setting of the tune on [The Session](https://thesession.org/tunes/10574), which gives `GG AB|GB AD|GG AB|G2 F2|GG AB|cB AG|FD EF|G2 G2` in G major and 2/4, with an eighth note as the unit. Our cello reference plays that pattern an octave lower, in the same key. The Session is a verification source, not a redistributed app asset.

| Reference | Key | Seven notes, low to high | Transposition from cello |
| --- | --- | --- | --- |
| Low voice | C major | G2, A2, B2, C3, D3, E3, F3 | -7 semitones |
| Cello | G major | D3, E3, F-sharp3, G3, A3, B3, C4 | 0 |

All target frequencies use equal temperament with A4 = 440 Hz. The cello reference supplies pitch and timbre, not a demonstration of fingering or bow technique. At 60 BPM the strain lasts 16 seconds and each selection four.

## Meet the notes and Tap it

Meet the notes plays the seven notes one at a time, then the melody's widest move, the drop of a fifth that ends phrase 1: G2 then D3, and back (D3 then A3 on the cello). Last comes the note the melody repeats quickly, the G that opens phrases 1 to 3, sounded eight times at half a beat: C3 for the voice, G3 on the cello. The quick-notes advice (sing "doo", or play each note separately) is shown on every selection that repeats it.

Phrases 1 and 3 have eight half-beat notes, the rhythm of Hot Cross Buns' third phrase. Phrases 2 and 4 are new: four half-beat notes, then two one-beat notes ("Two short notes per beat on 1 and 2: 1 & 2 &. Then tap on 3 and on 4.").

## Composition, arrangement and recording provenance

The tune is anonymous. The English Wikipedia article on [Yankee Doodle](https://en.wikipedia.org/wiki/Yankee_Doodle) says the melody is thought to be much older than its words. The earliest known words date from 1755 or 1758, credited to the British Army surgeon Richard Shuckburgh in the French and Indian War, and the tune appeared in the ballad opera *The Disappointment* in 1762. It is the state song of Connecticut. The melody is in the public domain; the app uses no words. Our independently encoded unaccompanied excerpt copies no modern edition or arrangement.

Playback adapts the same recorded sources already bundled for the other melodies. Human references retune the retropttam hum to the score; cello references use the existing VSCO 2 recorded cello-section sustains. These sources remain under their existing licences and credits: [human source, CC BY 3.0 and adaptations](../CelloPractice/Resources/HUMMING-LICENSE.txt), and [cello sources and CC0 dedication](../CelloPractice/Resources/CELLO-LICENSE.txt). No new recording is distributed.

The hummed F3 is about eight semitones above the recorded hum's own pitch (110.6 Hz, close to A2), the furthest the one recording has been moved so far; E3, in Twinkle, Twinkle, was seven.

Sources checked on 13 November 2026.

## Assessment and history

Humming and tapping use the shared melody assessments unchanged. Each take freezes its piece ID (`yankeeDoodle`), score version, register, key, expected events, tuning, tempo, section and grading version, so this level's progress is separate from the other melodies and adding it regrades nothing. Unit tests render the hummed and cello examples of every phrase and of the whole strain, check that each earns three stars, also under the steady hiss of the noise test, and check that every note sounds at its pitch, measured inside its own half beat.

It is the first melody whose quick notes change pitch, so it is the first real test of scoring version 4 on running notes. A unit test renders three mistaken takes of phrase 1 and checks what the teacher's note says:

- The whole run a quarter of a beat late: "All the notes began about 0.2 s late. Change note as each bar reaches the line."
- Rushed, at fifteen sixteenths of the time: "Notes 7 and 8 began about 0.2 s early. Wait for each bar to reach the line."
- The two opening G's run together as one long note. One note in eight may go unheard, so every goal is still reached; the teacher's note now says so after the praise: "Also: 7 of the 8 notes were heard. Give each note a clear start of its own." It said nothing before, and running quick notes together is the habit this level is most likely to show.

The noise test found one more thing, in the cello examples rather than the scoring. The four recorded cello strings are matched by their loudest moment, and each starts with a bow's slow attack, so a half-second note cut from the D3 recording played about 8 dB quieter than one from the A3 recording. Under the hiss, a quiet D3 straight after a loud A3 never stood clear enough to be heard as a new note. Every cello example note is now played at the same loudness (`RecordedReference`), which also evens out what a learner hears; the hummed examples are unchanged.

Not yet checked: a real voice or a real cello on running notes, and whether half a second a note is too fast to hum cleanly. The saved takes so far show quick repeated notes were the hardest thing on the path; if this level proves too fast, the plan is to slow it down or split it.
