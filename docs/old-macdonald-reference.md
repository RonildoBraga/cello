# Old MacDonald first line score and reference

*Old MacDonald Had a Farm* is a traditional children's song. Cello uses its own unaccompanied teaching arrangement of its first line, "Old MacDonald had a farm, E-I-E-I-O", rendered with the existing licensed recorded human and cello sources. No words, score image, accompaniment, fingering or source performance is bundled.

## Why this tune is Level 6

It brings bigger jumps: a drop of a fourth in phrase 1, then a leap of a sixth up from the end of phrase 2 to the start of phrase 3. The sixth is the one that matters for the path's goal: from D3 up to B3 on the cello is the second jump of the opening of Bach's first Prelude (G, D, B). Nothing else is new. Every note is one Twinkle, Twinkle already uses, in both registers, and the rhythm is one beat a note with two held notes. It is the second level of the plan in [issue #78](https://github.com/RonildoBraga/cello/issues/78), built for [issue #80](https://github.com/RonildoBraga/cello/issues/80).

## Arrangement version 1

The scale-degree pattern is `1 1 1 5 | 6 6 5 | 3 3 2 2 | 1`, where the 5 and 6 lie below the first note. Durations in quarter-note beats are `1,1,1,1 | 1,1,2 | 1,1,1,1 | 4`: 12 note starts, five distinct pitches, four 4/4 bars and 16 beats. Each bar is one practice selection, with boundaries at 0, 4, 8, 12 and 16 beats. There are no notated rests.

The pattern was checked against the score in Wikipedia's articles on the song [in Spanish](https://es.wikipedia.org/wiki/El_viejo_MacDonald_ten%C3%ADa_una_granja) and [in French](https://fr.wikipedia.org/wiki/Old_MacDonald_Had_a_Farm), which give `g4 g g d | e e d2 | b'4 b a a | g2.` in G major and 4/4. There the last note is a dotted half followed by the first note of the next verse, and the song's last bar is a whole note; as a single line, the arrangement ends on the whole note. The articles are a verification source, not a redistributed app asset.

| Reference | Key | Five notes, low to high | Transposition from cello |
| --- | --- | --- | --- |
| Low voice | C major | G2, A2, C3, D3, E3 | -7 semitones |
| Cello | G major | D3, E3, G3, A3, B3 | 0 |

It is the first melody not in D major on the cello, so a melody now names its own key (`MelodyPiece.keyName(for:)`), worked out from its home note on the cello and the register's transposition. Every earlier melody keeps the key its saved takes were made in, which is part of what their progress is saved under; a unit test pins that.

All target frequencies use equal temperament with A4 = 440 Hz. The cello reference supplies pitch and timbre, not a demonstration of fingering or bow technique. At 60 BPM the line lasts 16 seconds and each selection four.

## Meet the notes and Tap it

Meet the notes plays the five notes one at a time, then the leap of a sixth: G2 then E3, and back (D3 then B3 on the cello). It practises a melody's widest move, so the drop of a fourth is not drilled on its own; it comes inside phrase 1.

Phrase 4 is one note held for four beats. Tap it asks for one tap and none while the note continues ("Tap once on 1. Count 2, 3 and 4 while the note continues."); a tap in the held beats costs the Pattern star, as a continuing note always has.

## Composition, arrangement and recording provenance

The song is traditional, with no known composer (Roud Folk Song Index 745). The English Wikipedia article traces versions with farmyard verses back to "In the Fields in Frost and Snow" in Thomas d'Urfey's opera of 1706, which used a different, minor-key tune, through versions collected in England around 1900 and a 1917 printed variant called "Ohio". It names recordings by the Sam Patterson Trio (1925) and Gid Tanner and His Skillet Lickers (1927) as perhaps the first known to use the now standard tune. The tune is treated as traditional and in the public domain; the app uses no words. Our independently encoded unaccompanied excerpt copies no modern edition or arrangement.

Playback adapts the same recorded sources already bundled for the other melodies. Human references retune the retropttam hum to the score; cello references use the existing VSCO 2 recorded cello-section sustains. These sources remain under their existing licences and credits: [human source, CC BY 3.0 and adaptations](../CelloPractice/Resources/HUMMING-LICENSE.txt), and [cello sources and CC0 dedication](../CelloPractice/Resources/CELLO-LICENSE.txt). No new recording is distributed.

Sources checked on 12 November 2026.

## Assessment and history

Humming and tapping use the shared melody assessments unchanged. Each take freezes its piece ID (`oldMacDonald`), score version, register, key, expected events, tuning, tempo, section and grading version, so this level's progress is separate from the other melodies and adding it regrades nothing. Unit tests render the hummed and cello examples of every phrase and of the whole line, check that each earns three stars, and check that every note sounds at its pitch.

With twelve notes in the whole line, two can miss and the Notes goal is still reached: a whole take with both notes after the leap sung low earns three stars. The teacher's note then mentions them after the praise ("Also: Notes 8 and 9 (E3) were low. Aim higher on them."). Practised alone, phrase 3 loses the Notes goal for the same mistake.

Not yet checked: a real voice or a real cello on the leap.
