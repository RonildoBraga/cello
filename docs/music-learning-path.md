# Music learning path

Status: Music organisation, first-melody reference playback and humming phrase recording/feedback delivered. Melody rhythm and cello playing remain planned in [the delivery epic](https://github.com/RonildoBraga/cello/issues/1).

## Problem and goal

Voice and rhythm exercises currently share a Humming section, while the library offers no connection between isolated skills and music to play. A beginner needs to find the right practice, keep earned progress and understand how each skill contributes to a first melody and later repertoire.

The first delivery separates Humming, Rhythm and Cello inside a Music library. It adds a first-piece path for Hot Cross Buns and a longer-term path toward Bach’s Cello Suite No. 1 Prelude, BWV 1007. These are learning goals; a completed tap exercise is not evidence of performing a new melody.

## Navigation

```text
Music
  Foundations
    Humming → Steady hum; Listen & match
    Rhythm → Pulse; Two taps per beat; Mixed rhythm
    Cello → Open C/G/D/A strings
  Pieces
    Hot Cross Buns → Humming (four phrases, then whole melody); Listen & follow
    Bach, Suite No. 1 Prelude → long-term learning path
Practice → the selected foundation exercise
Recordings → existing local audio/video history
```

Music, Practice and Recordings remain visible iPhone tabs. Within Music, native lists, detail pages and back navigation express the hierarchy. The Music toolbar button returns to the library root. Starting a lesson from any route selects its area, resets that exercise to ready and opens Practice. Switching areas remembers the prior lesson in each area.

This is a design choice informed by [Apple’s sidebar guidance](https://developer.apple.com/design/human-interface-guidelines/sidebars): a tab bar is worth considering where sidebar space is limited. A custom hidden drawer is unnecessary for this small iPhone library. A larger-screen sidebar can be considered if the catalogue grows.

## First-release requirements

- Each existing exercise belongs to one visible area; the Rhythm menu contains only rhythm exercises.
- Original lesson IDs and displayed numbers stay stable: Humming 1–2, Rhythm 3–5 and Cello 1–4. Saved ratings, raw media, references and earned completion are unchanged.
- Library, exercise menu and next actions share the same lesson-selection action. Humming Lesson 2 can still recommend Rhythm Lesson 3.
- A navigation area never supplies a recording pitch target. Existing voice/cello target rules stay separate from the new `LearningArea` model.
- Leaving practice cancels unfinished rounds/count-ins. A take already finishing saves under its original exercise and reference.
- Piece pages show concrete milestones, planned status and usable links to shared foundations. They contain no inactive Start-piece control or fabricated readiness percentage.
- Choosing an already selected lesson from the library starts a fresh ready screen; it does not reveal a stale result.

Success is verified through navigation tests, saved-history compatibility checks, screen inspection and physical-device installation. No analytics service or new learner-data collection is required.

## Progression

Hot Cross Buns is the first proposed three-note melody. A beginner method’s published contents place open-string work, D-string notes, bowing and fingering before that tune; this supports preparation before whole-piece performance. See [Mel Bay’s method contents](https://www.melbay.com/Products/21499BCDEB/modern-cello-method-grade-1.aspx). The app will use its own arrangement and references, with provenance verified before distribution.

Each piece will develop through hearing/humming, tapping its actual rhythm and playing on cello. A comfortable vocal register may differ from the cello register; the selected reference must be explicit. Existing foundation achievements are reusable preparation, while phrase and piece performances earn their own results.

Bach is a longer-term destination through easier repertoire, note reading, scales/arpeggios, bow control, string crossings and phrasing. The [ABRSM cello syllabus from 2024](https://www.abrsm.org/sites/default/files/2023-10/Practical%20syllabus%20Bowed%20Strings%202024%20%283%20Cello%29%2020230901.pdf) provides context for the full Prelude’s advanced level. The app does not claim exam equivalence or predict how quickly a learner will be ready.

## Dependent deliveries

| Issue | Delivery | Depends on |
| --- | --- | --- |
| [#2](https://github.com/RonildoBraga/cello/issues/2) | Music library, separate Rhythm, foundation scores and piece-roadmap pages | Existing exercises |
| [#3](https://github.com/RonildoBraga/cello/issues/3) | Original first-melody score/event model and manual reference playback | #2 |
| [#4](https://github.com/RonildoBraga/cello/issues/4) | Phrase listening/humming and melody-aware assessment | #3 |
| [#5](https://github.com/RonildoBraga/cello/issues/5) | Piece rhythm, durations and spaces | #3 |
| [#6](https://github.com/RonildoBraga/cello/issues/6) | Cello prerequisites and a complete first-melody performance | #3–5 and physical cello validation |
| [#7](https://github.com/RonildoBraga/cello/issues/7) | Intermediate repertoire and teacher-reviewed milestones toward Bach | First complete melody |

The first-melody reference uses one versioned score, selectable whole/phrase contexts, three explicitly named registers and manual playback. Humming offers only the two voice registers; the cello register remains in reference playback. The optional immutable `MelodyPracticeContext` freezes piece, score version, key/register, tuning, expected events, tempo, section and grading version. Reference-only selections from the first release have a nil grading version; new humming takes use melody grading version 1 and a separate frozen `MelodyRating`. Existing sessions remain compatible. A melody context suppresses the fixed-note foundation grader and chart. Melody completion uses its own durable ledger keyed to the complete frozen context. Foundation stars cannot complete piece lessons. Hearing an example is always separate from Record's countdown.
