# App Store release materials

The first public submission is **1.19.0 (36)**, free in all App Store countries or regions, with automatic release after Apple approval. A successful upload or TestFlight availability does not establish public App Store availability. Track submission and approval separately in [issue 67](https://github.com/RonildoBraga/cello/issues/67).

- `listing-en-AU.json`: public English (Australia) metadata and review instructions. Private review contact fields are entered in App Store Connect and are not stored here.
- `icon-design.md`: original generated icon provenance and prompt. The opaque 1024px asset lives in the app icon catalog; the compiled archive must contain its 1024px Icon Image rendition.
- Screenshots must be original app captures from a clean demonstration Simulator. No learner recordings, private histories or invented results. The current required iPhone Dynamic Island medium slot accepts the test iPhone 17’s 1206 x 2622 captures. Inspect screenshots before uploading.

## Publish the support pages

GitHub Pages serves `docs/index.html`, `docs/privacy.html` and `docs/site.css` from this public repository. After merging a release branch, point the Pages source at `main:/docs`; keep the same URLs in About and the listing. Verify both pages actually load before submission.

## Verify a release

Follow `CONTRIBUTING.md`: pitch package and app unit tests, then the full real-clock UI suite before release. Optional replay tests need private fixtures and must be reported as skipped when absent. Simulator checks do not prove microphone, camera, speaker or haptic behaviour. Record physical installation, data preservation and any functional checks separately.

Before updating a learner’s phone, back up Documents and hash its files. Copy them back after installation and verify original recordings and progress. Never uninstall to update. Keep all backups, signing/export options, archives, IPAs, upload logs, device identifiers and private review contacts outside Git.

Archive the reviewed source and verify the app’s version, build, signature, compiled icon and exact bundled privacy manifest. Use public App Store distribution; do not set `testFlightInternalTestingOnly` for a public release. Confirm Apple finishes processing, select the matching build, complete metadata/privacy/age rating/availability and submit to review.

If a defect is found before approval, remove the submission from review and upload a corrected build. Learner data and frozen scoring/history contracts still apply; do not distribute an older binary over newer saved formats without verifying compatibility.
