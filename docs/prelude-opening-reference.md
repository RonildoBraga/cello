# Prelude opening score and reference

Level 10 is the opening of the Prelude of J. S. Bach's Cello Suite No. 1 in G major, BWV 1007, as written but slowly: eight running notes to a phrase, two notes a second. Level 7 brought running notes and Level 9 the chords; this puts them together and adds the one thing neither had, the top note stepping down to its neighbour and back. It is the last level of the plan in [issue #78](https://github.com/RonildoBraga/cello/issues/78), built for [issue #84](https://github.com/RonildoBraga/cello/issues/84), and the milestone the path has pointed at since the first release.

It is an excerpt at a learner's speed, and the app says so, on the level and in About: passing it is a first step into the piece, not playing the Prelude. Bach writes each bar's figure twice, and players take it faster.

## Arrangement version 1

Each phrase is the first half of one of bars 1 to 4. Every note lasts half a beat.

| Phrase | Bar | Notes, voice and cello |
| --- | --- | --- |
| 1 | 1 | G2 D3 B3 A3 B3 D3 B3 D3 |
| 2 | 2 | G2 E3 C4 B3 C4 E3 C4 E3 |
| 3 | 3 | G2 F-sharp3 C4 B3 C4 F-sharp3 C4 F-sharp3 |
| 4 | 4 | G2 G3 B3 A3 B3 G3 B3 G3 |

Thirty-two notes, eight distinct pitches, four 4/4 bars and 16 beats. Each bar is one practice selection, with boundaries at 0, 4, 8, 12 and 16 beats. There are no rests and no note is sounded twice in a row. The notes of Level 9's chords are the first, second, third and sixth of each phrase; A3 is the only new note. The voice sounds the cello's own notes, G2 to C4.

The notes were checked against the public-domain edition of the suite on the Mutopia Project, [Suite 1 for Cello Solo](https://www.mutopiaproject.org/cgibin/piece-info.cgi?id=517) (Mutopia-2018/01/19-517), typeset by Andreas Scherer from the Schirmer edition of 1916 and placed in the public domain by the typesetter. Its LilyPond source gives the first half of bars 1 to 4 as `g16( d' b') a b d, b' d,`, `g,( e' c') b c e, c' e,`, `g,( fis' c') b c fis, c' fis,` and `g,( g' b) a b g b g`, in relative pitches an octave above the cello's, which its score moves down an octave. Bach's sixteenth notes are half a beat here. The edition is a verification source, not a redistributed app asset; the slurs it shows are left out, as the app cannot hear bowing.

All target frequencies use equal temperament with A4 = 440 Hz. The cello reference supplies pitch and timbre, not a demonstration of fingering or bow technique. At 60 BPM the opening lasts 16 seconds and each selection four.

## Meet the notes and Tap it

Meet the notes plays the eight notes one at a time, then the melody's widest jump, the octave from G2 to G3, and back, as every melody but the chords does; each of the other jumps was met on its own in Level 9. Tap it asks for two short notes per beat in every phrase, the rhythm of Hot Cross Buns' third phrase.

## Composition and recording provenance

See [the Prelude chords](prelude-chords-reference.md) for the suite's history and its source. The music is in the public domain. Our independently encoded excerpt copies no modern edition.

Playback adapts the same recorded sources already bundled for the other melodies. Human references rebuild the retropttam hum on the score one recorded cycle at a time, up to C4, fifteen semitones above its own pitch, keeping the voice's resonances (see [the G major scale](g-major-scale-reference.md)); cello references use the existing VSCO 2 recorded cello-section sustains. These sources remain under their existing licences and credits: [human source, CC BY 3.0 and adaptations](../CelloPractice/Resources/HUMMING-LICENSE.txt), and [cello sources and CC0 dedication](../CelloPractice/Resources/CELLO-LICENSE.txt). No new recording is distributed.

Sources checked on 13 November 2026.

## Assessment and history

Humming and tapping use the shared melody assessments unchanged. Each take freezes its piece ID (`preludeOpening`), score version, register, key, expected events, tuning, tempo, section and grading version, so this level's progress is separate from the other melodies and adding it regrades nothing.

The plan asked for proof that the scoring can follow it before the level was built: thirty-two notes of half a second, many a sixth or more from the one before. Unit tests render the hummed and cello examples of every phrase and of the whole opening and check that each earns three stars, both in quiet and under the steady hiss of the noise test, and that every note sounds at its pitch, measured inside its own half beat.

No real cello take has been scored at any level yet, and no real take of this level exists, so the teacher's note has only been checked on the app's own examples and on simulated mistakes at earlier levels. Not yet checked: a real voice or a real cello on it, and the hummed examples by ear beyond phrase 2.
