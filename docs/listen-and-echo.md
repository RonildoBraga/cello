# Listen & Echo

Open **Music → First sounds → Listen & Echo**. Hear an unfamiliar short pattern, then hum it back after the usual count of 1–2–3–4. The two-note level lasts four seconds; the three-note level lasts six. Every note lasts two beats at 60 BPM, including a short articulation gap in the recorded example.

The original catalogues contain six two-note and twelve three-note patterns. Two-note patterns repeat, rise or fall within G–A–B; three-note patterns add turns and expand to G–A–B–C–D. Patterns use the low voice: G2–B2 for two notes, G2–D3 for three. New pattern chooses uniformly among all other patterns at the selected level, so an immediate repeat is excluded. A level change selects a fresh pattern and resets the attempt.

## Hear, then record

Hear is always manual. Record remains visible but disabled until the current reference finishes successfully. Cancelling, interruption, leaving the page or changing the selection cannot unlock a different pattern. A completed audio clock and successful playback cleanup are required; an error is not treated as listening completion. Record starts only the countdown and never plays the example. The heard context remains fixed through capture and saving.

Hearing and preparation show a neutral card. Once recording starts, the shared live tuning card shows the measured note, Low/High bar, cents from the current target, and a short higher/lower cue. The target follows the exact frozen pattern's recording timeline, including note changes; silence leaves the pitch marker inactive. There is no automatic example playback, upcoming-note strip or camera preview. After saving, the existing Notes/Timing/Clarity goals and reference-versus-recorded pitch chart show what happened, followed by one next suggestion. Record again retries the same pattern; New pattern starts a fresh one. Both lengths remain available, with a three-note suggestion after completing two notes.

## Scoring and progress

Version-two melody assessment checks a possible pitch-only note change against neighboring voiced pitch medians, avoiding extra notes invented from a stale attack baseline while a voice settles. Amplitude reattacks remain independent. The pitch-match, timing and clarity goals keep their previous tolerances. Independent audio observations are compared with the exact frozen reference; the app does not transpose the learner's response or shift it onto the expected timeline. Wrong/missing notes lose goals, and uncertain or insufficient sound stays unscored. Stars describe audible notes, timing and clarity. They do not establish that a learner memorised the pattern or mastered an aural skill.

Echo contexts use the existing `MelodyPracticeContext` format, with `echoTwoNotes` or `echoThreeNotes` piece IDs, score version 1, the chosen voice register/key, A4 = 440 Hz, 60 BPM, complete expected events and melody grading version 2. There is no second, competing saved target. Canonical lookup compares every frozen field with the declared catalogue; a matching ID alone cannot earn progress. Known version-one contexts remain recognizable for historical titles, feedback and exports. Saved scores are not automatically regraded. Current progress requires version-two assessments; historical milestone keys remain stored separately.

Three three-star recordings among the last five rated attempts complete that level in that voice register. Patterns share a level window; the two lengths and two registers keep independent progress. Unscored attempts do not consume that window, and earned completion survives later misses or recording deletion. Completion uses `Documents/EchoProgress.json`; the recordings keep their original movies, context, observations and frozen ratings. Echo does not contribute milestones to the fixed-note or song ledgers. Old exercise IDs, numbering, grading and history formats remain unchanged.

Storage follows the existing recovery rules: an unreadable ledger is preserved, a failed milestone write leaves the recording saved, and deletion waits while recordings are the only durable proof of earned completion. Export retains the original movie, exact context/rating and Echo-labelled review feedback.

## Teaching and audio sources

This exercise offers practice listening to and reproducing unfamiliar patterns, with live pitch help requested by the learner in [issue #23](https://github.com/RonildoBraga/cello/issues/23). [MacEwan's ear-training introduction](https://openbooks.macewan.ca/introtoeartraining/chapter/how-to-practice-ear-training/) describes moving from single-note matching to note sequences and hearing sounds internally. [ABRSM's aural guidance](https://teacherhub.abrsm.org/mod/page/view.php?id=2020) discusses singing short phrases, musical memory and listening. These inform the activity; no source exercise, notation or recording is bundled, and this is not an exam-equivalence claim.

The patterns are original short sequences, rendered from the existing licensed retropttam human hum. Pitch, duration, fades and articulation gaps are edited locally. These are adaptations of recorded human sound, not newly recorded continuous performances of each pattern. The bundled [human recording credit and CC BY 3.0 licence](../CelloPractice/Resources/HUMMING-LICENSE.txt) also credit these adaptations. Missing recorded resources produce an error; there is no oscillator fallback in the app.

## Verification boundary

Tests cover canonical pattern generation and nonrepeat selection, separate versioned progress, saved-history recovery, positive recorded-human examples, independent incorrect-note controls, silence, movie decode/save/reload/export, full-Hear gating and cancellation UI. The live guide reuses the existing pitch reading and the frozen context's current-note lookup. A production-rated movie fixture can be exported from the integration test for external Simulator result review; it is a controlled reference-based fixture, not a learner performance. Personal recordings and review fixtures remain outside the repository.

TestFlight delivery and preservation of existing recordings/progress have been verified on the physical iPhone under [issue #16](https://github.com/RonildoBraga/cello/issues/16); remaining physical practice checks are tracked there. No performance result is fabricated to work around unavailable Simulator capture.
