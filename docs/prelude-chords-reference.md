# Prelude chords score and reference

Level 9 is the four chords that open the Prelude of J. S. Bach's Cello Suite No. 1 in G major, BWV 1007, with their notes one after another, one to a beat. Each phrase starts from the same low G, jumps up twice and comes back to the note before. It is the Prelude with everything fast taken out, so the learner hears its shape before having to move through it. It is the fifth level of the plan in [issue #78](https://github.com/RonildoBraga/cello/issues/78), built for [issue #83](https://github.com/RonildoBraga/cello/issues/83).

## Arrangement version 1

Each phrase takes one bar of the Prelude. Bach's figure in each of bars 1 to 4 is eight sixteenth notes, played twice; the phrase keeps its lowest note, its middle note and its top note, then the middle note again.

| Phrase | Bar | Notes, voice and cello | Beats |
| --- | --- | --- | --- |
| 1 | 1 | G2 D3 B3 D3 | 1, 1, 1, 1 |
| 2 | 2 | G2 E3 C4 E3 | 1, 1, 1, 1 |
| 3 | 3 | G2 F-sharp3 C4 F-sharp3 | 1, 1, 1, 1 |
| 4 | 4 | G2 G3 B3 G3 | 1, 1, 1, 1 |

Sixteen notes of one beat each, seven distinct pitches, four 4/4 bars and 16 beats. Each bar is one practice selection, with boundaries at 0, 4, 8, 12 and 16 beats. Every move is a jump, from a third (G3 to B3) to an octave (G2 to G3): eight different jumps in all. The voice sounds the cello's own notes, as in the G major scale, G2 to C4.

The notes were checked against the public-domain edition of the suite on the Mutopia Project, [Suite 1 for Cello Solo](https://www.mutopiaproject.org/cgibin/piece-info.cgi?id=517) (Mutopia-2018/01/19-517), typeset by Andreas Scherer from the Schirmer edition of 1916 and placed in the public domain by the typesetter. Its LilyPond source of the Prelude gives bars 1 to 4 as `g16( d' b') a b d, b' d,`, `g,( e' c') b c e, c' e,`, `g,( fis' c') b c fis, c' fis,` and `g,( g' b) a b g b g`, each written twice in a bar, in relative pitches an octave above the cello's, which its score moves down an octave. That edition is a verification source, not a redistributed app asset.

All target frequencies use equal temperament with A4 = 440 Hz. The cello reference supplies pitch and timbre, not a demonstration of fingering or bow technique. At 60 BPM the four chords last 16 seconds and each selection four.

## Meet the notes and Tap it

Meet the notes plays the seven notes one at a time, then each of the eight jumps once, going higher, in the order the phrases bring them: G2 then D3, D3 then B3, G2 then E3, E3 then C4, G2 then F-sharp3, F-sharp3 then C4, G2 then G3, G3 then B3. It is the only level that practises more than one jump: every earlier melody keeps its one jump, up and down, so their drills, and the progress saved on them, are unchanged. Tap it asks for a tap on every beat.

## Composition and recording provenance

Bach most likely composed the six cello suites between 1717 and 1723, when he was Kapellmeister in Köthen. No autograph survives; the music is known from manuscript copies, among them one by Anna Magdalena Bach. The Prelude of the first suite, made mostly of broken chords, is the best known movement of the set (English Wikipedia, [Cello Suites (Bach)](https://en.wikipedia.org/wiki/Cello_Suites_(Bach))). The music is in the public domain. Our independently encoded excerpt copies no modern edition.

Playback adapts the same recorded sources already bundled for the other melodies. Human references retune the retropttam hum to the score; cello references use the existing VSCO 2 recorded cello-section sustains. These sources remain under their existing licences and credits: [human source, CC BY 3.0 and adaptations](../CelloPractice/Resources/HUMMING-LICENSE.txt), and [cello sources and CC0 dedication](../CelloPractice/Resources/CELLO-LICENSE.txt). No new recording is distributed.

The hummed C4 is fifteen semitones above the recorded hum's own pitch (110.6 Hz, close to A2), the furthest the one recording has been moved. It passes the pitch checks and keeps the voice's resonances, as the hum is rebuilt one recorded cycle at a time; see [the G major scale](g-major-scale-reference.md) for how that was chosen by ear.

Sources checked on 13 November 2026.

## The voice

The chords span an octave and a fourth with jumps up to an octave: cello writing. The roadmap left open whether the voice should do this level as written. It does, for now, on the cello's own notes, because the lessons are the same either way and nothing is locked; how it goes on real takes decides whether the voice keeps it, gets fewer jumps, or hums only the top line.

## Assessment and history

Humming and tapping use the shared melody assessments unchanged. Each take freezes its piece ID (`preludeChords`), score version, register, key, expected events, tuning, tempo, section and grading version, so this level's progress is separate from the other melodies and adding it regrades nothing. Unit tests render the hummed and cello examples of every phrase and of the whole level, check that each earns three stars, and check that every note sounds at its pitch. A unit test renders the first chord with its top note a whole tone short, and a whole tone too far, and checks that the teacher's note names the note and the way it was out ("Note 3 (B3) was low. Aim higher on it.").

Not yet checked: a real voice or a real cello on the jumps, and the hummed examples by ear beyond phrase 2.
