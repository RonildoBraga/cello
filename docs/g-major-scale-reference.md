# G major scale score and reference

Level 8 is one octave of the G major scale, up and back down, from the cello's open G string. It is the only level without a familiar melody: a scale is not a tune. It earns its place because G major is the key of Bach's first Prelude and every later level uses these notes, and scales come before the pieces that need them in string teaching. It is the fourth level of the plan in [issue #78](https://github.com/RonildoBraga/cello/issues/78), built for [issue #82](https://github.com/RonildoBraga/cello/issues/82).

## Arrangement version 1

| Phrase | Notes, voice and cello | Beats |
| --- | --- | --- |
| 1 | G2 A2 B2 C3 | 1, 1, 1, 1 |
| 2 | D3 E3 F-sharp3 G3 | 1, 1, 1, 1 |
| 3 | G3 F-sharp3 E3 D3 | 1, 1, 1, 1 |
| 4 | C3 B2 A2 G2 | 1, 1, 1, 1 |

Sixteen notes of one beat each, eight distinct pitches, four 4/4 bars and 16 beats. Each bar is one practice selection, with boundaries at 0, 4, 8, 12 and 16 beats. There are no rests. Phrases 2 and 3 meet on the top G, sounded twice.

On the cello the scale starts on the open G string and crosses to the open D string at phrase 2. All target frequencies use equal temperament with A4 = 440 Hz. The cello reference supplies pitch and timbre, not a demonstration of fingering or bow technique. At 60 BPM the scale lasts 16 seconds and each selection four.

## The voice at the cello's pitch

Until now the voice hummed every melody a fifth below the cello. Here that would start on C2, too low to hum, so this melody places the voice on the cello's own notes: G2 to G3, in G major both ways. A melody now says how far the voice sits from the cello (`MelodyPiece.transposition(for:)`). Every earlier melody keeps the voice a fifth below, because its notes and key are part of what its saved progress is saved under; a unit test pins the progress keys of every earlier lesson, phrases, whole melodies and Meet the notes, by voice and on the cello, to the values they had before this change.

The question of which key the cello should play the earlier melodies in (D major on the cello against G major hummed) stays open on purpose: changing it would move their saved progress, and it is waiting for a teacher's view.

## Meet the notes and Tap it

Meet the notes plays the eight notes one at a time, then the octave: G2 then G3, and back. A scale only steps, so the lesson's pair is its lowest and highest notes, as it is for Ode to Joy. Tap it asks for a tap on every beat, the rhythm of earlier phrases.

## The hummed example

The hummed G3 is ten semitones above the recorded hum's own pitch (110.6 Hz, close to A2), further than any earlier level moved it (eight, for Yankee Doodle's F3). The renderer retunes the one recording; the examples pass the same pitch checks as every other level. Whether G3 still sounds like a person humming has not been judged by ear. If it does not, the plan in issue #82 is a second recorded hum around D3, chosen for the notes it is nearer to, as the cello examples already choose between four recorded strings. A new recording would need its source and licence recorded like the first.

## Recording provenance

Playback adapts the same recorded sources already bundled for the other melodies. Human references retune the retropttam hum to the score; cello references use the existing VSCO 2 recorded cello-section sustains, the low notes from the recorded G string. These sources remain under their existing licences and credits: [human source, CC BY 3.0 and adaptations](../CelloPractice/Resources/HUMMING-LICENSE.txt), and [cello sources and CC0 dedication](../CelloPractice/Resources/CELLO-LICENSE.txt). No new recording is distributed. A scale has no composer and needs no score source.

## Assessment and history

Humming and tapping use the shared melody assessments unchanged. Each take freezes its piece ID (`gMajorScale`), score version, register, key, expected events, tuning, tempo, section and grading version, so this level's progress is separate from the other melodies and adding it regrades nothing. Unit tests render the hummed and cello examples of every phrase and of the whole scale, check that each earns three stars, and check that every note sounds at its pitch.

Not yet checked: the hummed examples by ear, from F-sharp3 up; a real voice humming up to G3; a real cello.
