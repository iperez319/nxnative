# Shield guide simulator checks

Run the production guide using original generated Shield-format snapshots:

```sh
python3 dm/ios/tests/guide/run.py --output /tmp/shield-guide-ui --device SIMULATOR_UUID
```

The output directory must be new. Xcode and XcodeGen are required. Choose a
UUID from `xcrun simctl list devices available`; run phone and tablet suites
sequentially. `--only testChecklistFiltersAndSearch` selects a single method.
The runner stages sources and fixtures in the output directory, then writes
an Xcode result bundle with retained screenshots. It never loads game assets
or player saves. All preferences belong to `org.nxnative.ShieldGuideHarness`.

Tests use the production view, hosting controller, shared presentation policy,
catalog, reader and live resolver. Only UIApplication startup, synthetic
committed-file changes and live-memory inputs are supplied by the harness.
Physical-device menu behavior remains a separate check. Spoken VoiceOver is
excluded from acceptance at the owner's request.

Batch 5 adds the shared `dm/apple/tests/shield_guide_release_journeys.json`
expectations to the test bundle, including the expected nearby/later/completed
group. Three tests compare 16 opening, quest, Gym,
daily and collection states to that same table used by the portable and Mac
tests. Other cases cover a first commit after no save, synthetic rollback,
Rolling Fields respawn/weather controls and a source-menu selection after
several unchanged timer polls. Activity identifiers use the existing stable
keys (`guide.activity.<key>`). Scrolling uses the actual List viewport, so it
also works inside iPad's centered guide sheet. The complete suite has eleven
tests per device at the Batch 5 checkpoint. The final source audit adds a
twelfth test for the printed-guide tent-color service search.
The offline handbook adds two more tests for no-save search, source citations,
25-result pagination, searchable category selection and landscape detail layout,
bringing the current suite to fourteen tests per device.
Screenshots are retained in `results.xcresult`; they contain only generated
fixtures and original guide UI. The read-only real-archive replay is separate
in the Apple runner.
