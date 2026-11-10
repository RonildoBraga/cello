# Hot Cross Buns score and reference

Traditional melody. Original three-note teaching arrangement created for Cello, played with licensed recorded human and cello sources. No source score image or modern publisher arrangement is included.

## Arrangement version 1

The relative pitches are `3 2 1 | 3 2 1 | 1 1 1 1 2 2 2 2 | 3 2 1`. Durations in quarter-note beats are `1,1,2 | 1,1,2 | 0.5 × 8 | 1,1,2`: 17 events, four 4/4 bars and 16 beats. Each bar is one practice phrase; boundaries are 0, 4, 8, 12 and 16 beats. There are no notated rests in this arrangement. The event model also supports explicit rests and silent gaps.

The pattern was checked against the University of Hawaii's *Music for Preschool* (1971), printed page 32 / PDF page 45, which presents the familiar A–G–F version. We independently encode the traditional pitch/rhythm pattern, transpose it and generate audio; no page or audio from that publication is redistributed. [Primary source](https://files.eric.ed.gov/fulltext/ED060948.pdf#page=45).

The US Bureau of Education's *Music in the Public Schools* (1922), printed page 65, names Hot Cross Buns as material for quarter, half and eighth notes. [Government source](https://www.govinfo.gov/app/details/GOVPUB-I16-PURL-gpo67056). Historical versions vary: the public-domain 1878 *Baby's Bouquet* contains a different tune variant and is not the pitch source for this version. [Smithsonian edition](https://library.si.edu/digital-library/book/babyquotsbouque00cran).

| Reference | Key | Notes, low to high | Transposition from cello |
| --- | --- | --- | --- |
| Low voice | G major | G2, A2, B2 | −7 semitones |
| Cello | D major | D3, E3, F♯3 | 0 |

All frequencies use equal temperament with A4 = 440 Hz. Registers preserve the melody's relative intervals; the low voice is a starting option, not a measured vocal range. An earlier release also offered a higher voice (G3–B3); it was removed in [issue #48](https://github.com/RonildoBraga/cello/issues/48), and takes saved with it still open. The cello reference does not assert readiness to finger or bow the notes.

## Recorded audio and frozen context

References are rendered locally as 48 kHz, mono, 16-bit PCM from recorded samples, with short fades and quiet articulation gaps. The low voice uses the licensed retropttam human hum, retuned and arranged per note. This is an edited human recording, not a fresh continuous performance of the song. Cello playback uses four recorded VSCO 2 cello-section sustains, choosing the closest source and applying a small playback-rate tuning adjustment. Longer holds crossfade the recorded sustain instead of replaying a bow attack or adding synthesized partials.

The app labels these references Recorded hum / Recorded cello. [Human source and adaptation credit](../CelloPractice/Resources/HUMMING-LICENSE.txt) and [cello source and CC0 credit](../CelloPractice/Resources/CELLO-LICENSE.txt) are bundled; the Music resources disclosure links to the original sources and licences. Missing assets are reported as playback errors. There is no synthetic fallback. The original foundation human example is unchanged.

The UI uses 60 BPM: the complete melody lasts 16 seconds and each phrase lasts four seconds, including the final quiet boundary. The model supports 40–120 BPM for later exercises. The shared audio-session path suppresses reference sound from live pitch observations; playback starts only on a Hear action and stops when leaving the page or changing reference settings.

`MelodyPracticeContext` stores immutable piece/version, key/register, A4 tuning, selected events relative to time zero, tempo, duration, section and optional grading version. Takes save and export that snapshot without consulting current settings. The first reference-only release used nil grading version; humming recording now uses melody grading version 1. Old fixed-note sessions and separate rhythm history files keep their existing formats and behavior. See [humming assessment](melody-humming.md).

Tests verify score timing, phrase boundaries, transpositions, frequency detection, audio duration, fades, articulation gaps, explicit rests, invalid-input bounds and session save/reload/export compatibility.

The recorded-reference release changes timbre only: expected note events, keys/registers, score and grading versions and completion keys remain unchanged. Independent synthetic fixtures stay in the test target; the shipped app contains only recorded-sample playback.
