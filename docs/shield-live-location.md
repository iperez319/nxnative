# Shield live location experiment

This Mac research tool tests whether Shield's known zone hashes update in memory
before an in-game save. It uses the packaged host's existing `DM_CTL memdump`
command. No host rebuild, debugger attachment or guest memory writes are needed.
It supports only Shield 1.3.2, main build
`a16802625e7826bf83b6f9708e475b91`.

The original scan output is **unvalidated candidates**. The newer pointer-based
reader is an experimental, build-specific live source, with additional checks.
Loaded placement tables, old transitions and save buffers can all contain the
same hash. A stationary match is insufficient. Addresses belong to one launch
and must not be carried to another as absolute offsets. The pointer-based reader
instead discovers the module base from the current launch and follows globals.

First live test, 2026-10-28: a user-confirmed Route 1 → Postwick → Route 1
traversal changed the same three memory candidates in both directions while the
isolated committed save's SHA-256 remained unchanged. Ninety other Route 1
matches stayed unchanged in Postwick. This establishes that live zone information
exists before saving in this build/session; it does not identify which of the
three copies is authoritative or establish a stable address across launches.

## Pointer-based reader: latest result

The Mac and iOS guides use a read-only in-process implementation of this
check in **Current game** mode. The host gates the module offsets on the
exact Shield build and bounds each object read to committed guest heap.
The guide requires stable roots, matching type pointers, a stable area/zone
pair and mirror agreement before looking up a checklist area. Unresolved
locations fall back to saved or manual browsing. Synthetic transition tests
cover this implementation. Live iOS and broad gameplay coverage remain open.

The follow-up identified a live object through `main+0x2961d98`. The pointed-to
object contains the area hash at `+0x48` and zone hash at `+0x50`. The write watch
captured the zone store at `main+0xdcb83c` during both directions of an unsaved
Postwick/Route 1 crossing. Local disassembly confirms `str x8, [x19, #0x50]` in
the function starting at `main+0xdcb430`. Its caller loads the object through a
GOT entry whose relocation points to that global, supporting the global's role
beyond a coincidental pointer match.

A separate live save-state mirror is reachable through
`main+0x26364f0 → +0x1c0 → +0x68`. The reader checks both objects' vtable identities,
rechecks the area/zone pair across the mirror read, requires zone agreement and
verifies that the zone belongs to the area. Null or unreadable pointers, wrong
vtable identity, changing/disagreeing values and unmapped areas/zones return
unknown. All offsets and mappings live in the exact-build
[research profile](../dm/games/01008DB008C2C000/live_location.json).

The profile worked in the instrumented process and two subsequent fresh,
uninstrumented processes with different `main` bases. Both new processes resolved
Route 1 without an initial scan or manual calibration; an unsaved crossing to
Postwick also worked in the first of them. The heap objects happened to retain
their addresses in these runs; synthetic tests additionally move them to check
that the reader follows pointers instead of relying on those addresses.

At the fresh title screen, the primary zone was zero while the mirror already
held Route 1 from the save. The reader returned unknown, then Route 1 after the
user loaded the save. Inside user-confirmed Hop's house, both sources changed
to a matching interior pair, which initially returned unknown because that
mapping had not yet been added. The committed experiment save changed during that interior step;
autosave was not controlled. The preceding outdoor no-save checks remain
separate evidence, with unchanged save hashes.

After `launch`, use this command directly, without `scan`:

```sh
python3 scripts/shield_live_location.py resolve \
  --run '../Games/Pokemon Shield/location-research/my-live-test'
```

For repeated reads:

```sh
python3 scripts/shield_live_location.py watch --source roots \
  --run '../Games/Pokemon Shield/location-research/my-live-test' --seconds 60 --interval 2
```

`root-report.json` and `session.json` record timestamped observations.
`candidate_location` carries the experimental label; `current_location` remains
null to prevent treating this research result as a production adapter. Save
files are hashed for experiment checks, but no location field is decoded from
them by this reader. Each sample uses small memory reads rather than a heap scan.
These reads are sequential and cannot prove an atomic snapshot or detect every
possible state transition between reads.

Remaining coverage: other regions, other interiors with verified display names,
loading/restore behavior, gameplay menus and allocation/order changes. No
companion integration or iOS validation is claimed.

## Interiors and exterior context

Three Postwick interior area/zone pairs are now explicitly mapped. The recorded,
user-confirmed Hop's house pair resolves to **Hop's house — Postwick**. The two
other mapped Postwick interiors resolve to **Indoors — Postwick**, retaining their
distinct area/zone IDs for future room naming. Their exact room names and live
behavior have not been validated.

This parent relationship comes from the game's own placement records, rather
than assuming the last outdoor zone is the interior's owner. Members 148, 149
and 150 all reference Postwick's place-name key. Members 148 and 149 have exits
to `a_0101` with destination zone `019B5DC049D8CB3E`, specifically Postwick.
Member 150 links to member 149's interior, which has that exterior exit. The
shared area alone is insufficient because it also contains Route 1, Wedgehurst
and Route 2.

The result includes `location_kind: interior`, `interior_name` when known,
`exterior_location` with the parent area's ID, zone ID and label, and
`location_precision: named-interior` or `exterior-context`. The display therefore
keeps the player indoors while making town/route guide context available. Missing
or conflicting live state still returns unknown; it never reuses an old exterior
label after a failed read. Unmapped interiors remain unknown until their area,
zone and exterior relationship are verified.

The new label was replayed against the existing Hop's house live observation;
this was a mapping update, not a new live movement test. Private game-table
evidence and replay output are in `interior-placement-evidence.json` and
`interior-label-replay.json` under the game's ignored research directory.

## Optional writer instrumentation

`launch --trace-writer HEX_ADDRESS` explicitly enables the existing host's
`DM_PROBE_WATCH` on eight bytes at a prior investigative address. It is restricted
to this build's guest reservation and one host page. Unlike the default read-only
probe, it changes page protection and emulates stores through a writable alias;
run it only against an isolated research save. A previous address is only a hint
and must be revalidated after launch. Unemulated stores can briefly unprotect the
page, so missing watch events do not establish absence of writes. This option is
not needed for the pointer-based reader or future normal use.

## Run on the Mac

From the app repository, start a new experiment directory inside the game's
private research folder. Point `--save` at a committed save folder or an existing
copied `main` file. The tool copies it into the experiment and launches the
packaged host directly. It never launches against the original save directory.

```sh
python3 scripts/shield_live_location.py launch \
  --app '../Games/Pokemon Shield/Pokémon Shield.app' \
  --save '../Games/Pokemon Shield/location-research/route1-main-20261027' \
  --run '../Games/Pokemon Shield/location-research/my-live-test'
```

Keep that terminal open. Choose **Play offline** on the host's save startup
screen, or **Play locally** if unpaired, then continue the game normally. Cloud
pairing is held in Keychain, so a fresh experiment directory alone does not
unpair the host. Do not choose cloud restore or publication for a research copy.
Ctrl-C in the launch terminal stops that experiment's host.

In a second terminal, scan while standing in a location independently confirmed
on screen. For the supplied Route 1 fixture:

```sh
python3 scripts/shield_live_location.py scan \
  --run '../Games/Pokemon Shield/location-research/my-live-test' --location route1
```

The initial scan reads main's mapped image and the guest heap reservation in
16 MiB chunks. It transfers several GiB through temporary files and can cause
stutter; use it for research, not continuous tracking. Each completed chunk is
deleted immediately. Short reads, including the uncommitted heap tail, are
recorded in `session.json`; a short read can omit candidates. This is a bounded
scan of these two ranges, not proof that all possible location sources were found.

Cross into Postwick **without saving**, then record the independently observed
label:

```sh
python3 scripts/shield_live_location.py observe \
  --run '../Games/Pokemon Shield/location-research/my-live-test' --location postwick
```

Only the candidate pages are read after the initial scan. The report intersects
matches across labelled observations, filtering out copies that remain Route 1.
Return to Route 1 without saving and repeat `observe --location route1`. Useful
additional controls: stay still, move within Route 1, open/close menus, cross the
same boundary twice, and test an interior. Only use labels actually observed;
the probe does not infer them from the save or its candidate majority.

Known labels: `postwick`, `route1`, `wedgehurst`, `route2`, `route2-alt` (the second
Route 2 zone), `weald`. Interiors and all other zones remain unknown. After the
initial scan, optional continuous sampling is:

```sh
python3 scripts/shield_live_location.py watch \
  --run '../Games/Pokemon Shield/location-research/my-live-test' --seconds 60 --interval 2
```

Sampling alone does not count as a manually confirmed transition. Run only one
probe command per experiment at a time; a lock prevents concurrent state edits.
Do not move during a labelled observation: candidate pages are sampled in
sequence, not as an atomic paused-game snapshot.
Once labelled observations cover two distinct zones, `candidate_location` shows
a provisional label only when all remaining candidates agree on a known hash.
Watch reads those surviving candidates, so the suggestion can change without
supplying a new location label. Unknown, unreadable or disagreeing values produce
no suggestion. This agreement rule does not validate loading or menu semantics.

## Evidence and interpretation

- `session.json`: game/build identity, session ID, launch save hashes, scan
  ranges and short reads, raw candidate values and timestamped manual labels.
- `report.json`: latest candidate counts and addresses consistent with every
  labelled observation, plus the provisional `candidate_location` when possible.
  `current_location` intentionally remains null.
- `log.txt`: the actual host log and memory-read completion messages.
- `save/`: isolated committed save. `.work` directories are never used as a
  context source. Original save, game assets and app files are not modified.

`committed_save_unchanged_since_launch` compares the current committed files to
their launch hashes. It detects changed saves; it does not prove no filesystem
commit occurred between samples. Record unsaved movement explicitly, disable
autosave in the test copy if needed, and keep independently observed labels.
Do not infer freshness from an old or stopped watch report; check its timestamp.
Unreadable candidates become unknown. A missing host response is an error, and
no previous dump is reused. A crashed probe can leave `probe.lock`; remove that
lock only after confirming no probe invocation is still running. A timed-out
host request may leave a late `read-*.bin` in the private experiment directory.

Promote additional candidates only after repeated unsaved forward/reverse
transitions, lifecycle checks and rediscovery across new launches. The roots
above have a captured update path and area/zone checks; broader coverage and
explicit lifecycle handling are still needed before companion integration.
Never persist a discovered absolute address as a production game offset.

## Verification

```sh
python3 -m unittest discover -s dm/tools/tests -p test_shield_live_location.py
```

The thirteen tests exercise save isolation, build rejection, complete/short/timed-out
control responses, unaligned matches across chunks, stale-copy elimination,
reverse traversal, changed saves and unreadable candidates, explicit writer-trace
scope, pointer following after object relocation, object identities, conflicting
or torn observations, area membership and profile build gating. They do not
establish the game's runtime field semantics; the live tests provide that evidence.
Interior checks cover the named house, exterior-only context, exact ID retention
and rejecting unknown, conflicting or missing parent mappings.
