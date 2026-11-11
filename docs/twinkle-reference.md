# Twinkle, Twinkle opening score and reference

The tune known in English as *Twinkle, Twinkle, Little Star* is the French melody *Ah! vous dirai-je, maman*. Cello uses its own unaccompanied teaching arrangement of the first two lines, rendered with the existing licensed recorded human and cello sources. This is a short excerpt, not the whole tune. No words, score image, accompaniment, fingering or source performance is bundled.

## Why this tune is Level 4

Hot Cross Buns and Ode to Joy move only to the note next door. This opening begins with a jump of five notes, the first one on the path, and then steps back down. On the cello that jump is from the open D string to the open A string, the two strings Level 1 already practises. The rhythm stays easy, one beat a note with a held note at the end of each line, so the jump is the only new thing.

## Arrangement version 1

The scale-degree pattern is `1 1 5 5 | 6 6 5 | 4 4 3 3 | 2 2 1`. Durations in quarter-note beats are `1,1,1,1 | 1,1,2 | 1,1,1,1 | 1,1,2`: 14 note starts, six distinct pitches, four 4/4 bars and 16 beats. Each bar is one short practice selection, with boundaries at 0, 4, 8, 12 and 16 beats. Bars 1 and 2 are the tune's first line and bars 3 and 4 its second. There are no notated rests.

The pattern was checked against the score source in Wikipedia's articles on [the English song](https://en.wikipedia.org/wiki/Twinkle,_Twinkle,_Little_Star) and [the French melody](https://en.wikipedia.org/wiki/Ah!_vous_dirai-je,_maman), which both give `c4 c g' g a a g2 | f4 f e e d d c2` in C major and 4/4: quarter notes with a half note ending each line. Our cello reference transposes that relative pattern to D major. The articles are a verification source, not a redistributed app asset.

| Reference | Key | Six notes, low to high | Transposition from cello |
| --- | --- | --- | --- |
| Low voice | G major | G2, A2, B2, C3, D3, E3 | -7 semitones |
| Cello | D major | D3, E3, F-sharp3, G3, A3, B3 | 0 |

Each register has one note that no earlier level uses: E3 for the voice and B3 for the cello, both one step above the top of Ode to Joy. All target frequencies use equal temperament with A4 = 440 Hz. The cello reference supplies pitch and timbre, not a demonstration of fingering, string crossing or bow technique. At 60 BPM the opening lasts 16 seconds and each selection four.

## Meet the notes

The lesson plays the six notes one at a time, then the jump itself: G2 then D3, and back down (D3 then A3 on the cello). A melody with a jump practises that jump; a melody that moves only by step compares its lowest and highest notes instead (`NoteDrill.drills`). This tune's lowest and highest notes, G2 and E3, are never sung one after the other, so that pair is not asked for. Hot Cross Buns' only jump is between its lowest and highest notes and Ode to Joy has none, so their lessons are unchanged.

## Composition, arrangement and recording provenance

The melody is anonymous and from the 18th century. Wikipedia's article on the French melody gives 1761 for its first publication, citing George List, "The Distribution of a Melodic Formula: Diffusion or Polygenesis?", *Yearbook of the International Folk Music Council* 10 (1978), and 1774 for the earliest known printing of the French words with the music. The English words are Jane Taylor's poem "The Star" (1806); the app uses no words. The melody is in the public domain. Our independently encoded unaccompanied excerpt copies no modern edition or arrangement.

Playback adapts the same recorded sources already bundled for the other melodies. Human references retune the retropttam hum to the score; cello references use the existing VSCO 2 recorded cello-section sustains. These sources remain under their existing licences and credits: [human source, CC BY 3.0 and adaptations](../CelloPractice/Resources/HUMMING-LICENSE.txt), and [cello sources and CC0 dedication](../CelloPractice/Resources/CELLO-LICENSE.txt). No new recording is distributed.

Sources checked on 12 November 2026.

## Assessment and history

Humming and tapping use the shared melody assessments unchanged. Each take freezes its piece ID (`twinkle`), score version, register, expected events, tuning, tempo, section and grading version, so this level's progress is separate from the other melodies and adding it regrades nothing. Unit tests render the hummed example of every phrase and of the whole opening and check that it earns three stars, and that every note of the voice and cello examples sounds at its pitch.

Not yet checked: a real voice or a real cello making the jump. The tests above use the app's own examples, which change note cleanly; a singer may slide between the two notes.
