# Background noise

A learner should not need a silent room. This note records what was measured, what the app now does about noise, and what is planned. Scoring is unchanged so far: the first step only measures the room and says when it is noisy.

## What was measured

**How the app listens.** The audio session uses measurement mode: the raw microphone, with no noise suppression, gain control or directional pickup, so a held note is not altered. Nothing separates the learner from the room. "There is sound" is a fixed level, 0.0008 of full scale (about -62 dBFS), in both the pitch detector and the raters. The melody rater raises it to 8% of the take's loudest moment, so one loud bang can lift it above the hum.

**Real takes.** In 77 saved takes that contain a pause, the room's level was about -73 dBFS (median) against a hum near -47 dBFS. The fixed sound level therefore sits only about 11 dB above a quiet room, and in 8 takes the room was within 4 dB of it or above it.

**A noise experiment.** The app's hummed examples were set to that hum level, mixed with four kinds of noise and scored by the current raters. Levels are relative to the hum.

| Noise | Stars are lost from | With the signal limited to 70–1500 Hz |
| --- | --- | --- |
| Steady hiss | -13 dB for quick repeated notes and the jump; -3 dB for held notes | fine to -8 dB |
| Low rumble, below 120 Hz | -18 dB for held notes and three-note phrases | fine at -18 dB; at -13 dB except held single notes |
| A second hum-like voice | -13 dB | no better |
| A knock as loud as the hum | can cost two stars | fixed |
| One bang 27 dB louder | the take reads as no sound | not fixed |

The noises were synthetic and the examples cleaner than a real hum, so these are where today's scoring breaks in principle, not a promise about a real room.

**What iOS offers** (from Apple's documentation; not yet tried on a device). Microphone modes such as Voice Isolation are chosen by the user in Control Centre; an app can only open that panel (`AVCaptureDevice.showSystemUserInterface`). It is built for speech and would treat a cello as background. Audio-session data sources can offer a cardioid polar pattern, most sensitive to sound from the front.

**Recognising the learner's voice** was the first idea and is not the plan. Recognition says who is making a sound; it does not remove other sound mixed with it, a closed-mouth hum carries little that is personal, and it needs a model from outside the app. The app has something better: it knows the notes it asked for.

## Step 1 (built): hear the room, and say when it is noisy

`RoomNoise` is the room's own level: the quietest tenth of what the microphone heard in the last ten seconds outside a take (`RoomListener`). The count of 1–2–3–4 is silent and no hum lasts ten seconds without a pause, so the learner is not measured as noise: it takes about nine seconds of steady sound for a quiet room to turn noisy, and one second of quiet for it to turn back. The first take after the microphone comes on is judged from its count-in alone. Steady noise (a fan, traffic) is measured well. Talk and music that come and go read lower than they sound, so they are under-reported in this step.

A room is noisy when its level alone reaches the level the app counts as sound (0.0008). From there the app cannot tell a pause from a note.

- **During the count-in** the status line reads "Noisy room. Bring the phone closer." in place of "Get ready".
- **The live tuner** shows a note only when the sound is at least two and a half times the room's level. The bar stops at 0.0024, below the softest hums in the saved takes, so a loud room, or a learner who hums through the count-in, never hides the hum.
- **The result** of a take made in a noisy room carries a line saying so, on the practice screen and in Recordings. The take keeps the room's level in an optional `roomLevel` field; earlier takes have none.

The saved pitch observations and both raters are untouched, so no score or saved progress changes. `CaptureController` publishes the room only when it becomes known, noisy or quiet, so screens are not redrawn for each measurement.

Not verified on a device: the Simulator has no microphone, so the measurement, the warning and the tuner's behaviour are covered by unit tests of `RoomNoise` and `RoomListener` only.

## Planned

1. **Real noisy takes** as private test recordings: the same lessons in a quiet room, with talk, and with a fan or kitchen noise, at arm's length and at about 20 cm.
2. **Scoring that listens for the hum**, as a new grading version with passes carried over: limit the signal to the range where a hum or cello sounds, set the sound level from the room, and count only steady pitch near the notes asked for. The noise experiment becomes a permanent test.
3. **A trial of the cardioid pattern and Voice Isolation** behind a hidden switch, kept only if the recorded pitch stays accurate.

A person talking or a television close by, as loud as the hum and in its range, will remain hard. Distance is the cure: halving the distance from the mouth to the phone roughly doubles the hum against the room.
