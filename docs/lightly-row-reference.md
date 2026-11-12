# Lightly Row opening score and reference

*Lightly Row* is the English name of the German children's song *Hänschen klein*, which is sung to an older tune. Cello uses its own unaccompanied teaching arrangement of the tune's opening line, rendered with the existing licensed recorded human and cello sources. No words, score image, accompaniment, fingering or source performance is bundled.

## Why this tune is Level 5

Twinkle's jump of a fifth came once. Lightly Row moves by skips: from one note to the note after next, a third, twice in its first two phrases, before it climbs back up by step. A skip is smaller than Twinkle's jump and far more common in tunes. Nothing else is new: its five notes are the five of Ode to Joy, and its rhythm is one beat a note with a held note ending three of the four phrases. It is the first level of the plan in [issue #78](https://github.com/RonildoBraga/cello/issues/78), built for [issue #79](https://github.com/RonildoBraga/cello/issues/79).

## Arrangement version 1

The scale-degree pattern is `5 3 3 | 4 2 2 | 1 2 3 4 | 5 5 5`. Durations in quarter-note beats are `1,1,2 | 1,1,2 | 1,1,1,1 | 1,1,2`: 13 note starts, five distinct pitches, four 4/4 bars and 16 beats. Each bar is one practice selection, with boundaries at 0, 4, 8, 12 and 16 beats. There are no notated rests.

The tune is usually written in 2/4 with quavers. This arrangement doubles every length so that its opening line fills the app's four bars of 4/4 at 60 BPM, like the other melodies.

The pattern was checked against the score source in Wikipedia's articles on *Hänschen klein*, [in English](https://en.wikipedia.org/wiki/H%C3%A4nschen_klein) and [in German](https://de.wikipedia.org/wiki/H%C3%A4nschen_klein), which give `c8 a a4 | b8 g g4 | f8 g a b | c c c4` in F major and 2/4, in German note names where `b` is B-flat. Our cello reference transposes that relative pattern to D major. The articles are a verification source, not a redistributed app asset.

| Reference | Key | Five notes, low to high | Transposition from cello |
| --- | --- | --- | --- |
| Low voice | G major | G2, A2, B2, C3, D3 | -7 semitones |
| Cello | D major | D3, E3, F-sharp3, G3, A3 | 0 |

All target frequencies use equal temperament with A4 = 440 Hz. The cello reference supplies pitch and timbre, not a demonstration of fingering or bow technique. At 60 BPM the opening lasts 16 seconds and each selection four.

## Meet the notes

The lesson plays the five notes one at a time, then a skip: B2 then D3, and back (F-sharp3 then A3 on the cello). Meet the notes practises a melody's widest move larger than a whole tone (`NoteDrill.drills`). Here the two skips, D3 down to B2 and C3 down to A2, are the same size, and the first is the one practised. There are no quick repeated notes.

## Composition, arrangement and recording provenance

The tune is anonymous and at least 250 years old. The German Wikipedia article on *Hänschen klein* cites a music manuscript in which it is written down as a dance tune, dated June 1784, and a hunting song, *Fahret hin*, sung to it in a collection printed in 1807. The Dresden teacher Franz Wiedemann (1821–1882) wrote the words of *Hänschen klein* for that tune in 1860. The English words of *Lightly Row* are a nursery rhyme sung to it; the app uses no words. The melody is in the public domain. Our independently encoded unaccompanied excerpt copies no modern edition or arrangement.

Playback adapts the same recorded sources already bundled for the other melodies. Human references retune the retropttam hum to the score; cello references use the existing VSCO 2 recorded cello-section sustains. These sources remain under their existing licences and credits: [human source, CC BY 3.0 and adaptations](../CelloPractice/Resources/HUMMING-LICENSE.txt), and [cello sources and CC0 dedication](../CelloPractice/Resources/CELLO-LICENSE.txt). No new recording is distributed.

Sources checked on 12 November 2026.

## Assessment and history

Humming and tapping use the shared melody assessments unchanged. Each take freezes its piece ID (`lightlyRow`), score version, register, expected events, tuning, tempo, section and grading version, so this level's progress is separate from the other melodies and adding it regrades nothing. Unit tests render the hummed and cello examples of every phrase and of the whole opening, check that each earns three stars, and check that every note sounds at its pitch.

Not yet checked: a real voice or a real cello on the skips.
