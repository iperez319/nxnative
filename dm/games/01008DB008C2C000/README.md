# Pokémon Shield (`01008DB008C2C000`)

Update 1.3.2 (`v458752`) over the base game, SDK 7.3.2. Pokémon Sword's twin ([0100ABF008968000](../0100ABF008968000/README.md)): the same engine, and the same `sdk`, `subsdk0` (movie) and `subsdk1` (GLSLC) builds; only `main` is a build of its own (`a1680262…`, Sword's is `a3b75bcd…`). Everything in Sword's note about the engine, its services, files, shaders and rendering holds here; this note gives only what differs or was checked again. The profile is Sword's with Shield's title, name, IPA name, build row and shader tables. Plays on the iPhone (IPA 12.4 GB, user, 2026-10-26) and on the Mac at 30 fps, as on the Switch.

## What it needs

The same keys as Sword's profile, for the same reasons ([Sword, What it needs](../0100ABF008968000/README.md#what-it-needs)): the 4 GB layout with a 3.13 GB heap (`main.npdm` declares no system resource either), `mem_used 0x4c00000`, `pad_layout full`. The node area cut and the alignment of large regions come with the `sdk` build (`fcf93a41…`, `dm/tools/sdk_patches.py`). No host code is keyed to either game's `main`.

No `patches.py`.

## Files and shaders

- The RomFS has the same layout as Sword's (GFPAK archives under `bin/archive`, Wwise banks, loose BNSH files); `bin/sound/NX64/wwise/bank/Stream.pck` is the `romfs_marker` again.
- Shaders: 41,516, the same as Sword's. The split's three tables have the same data rows byte for byte (the game's own shaders, the GFPAK and loose BNSH files, and YEBIS's `.tfxo` stream in `main`, at the same offset); only the map's header note differs. The prewarm list is Sword's (it names shaders by content key).
- Each shader's cache key covers the profile's `shader_*` keys, so Shield's build does not hit Sword's cache entries; with `DMSH_PREFILL` naming Sword's library roots, the Metal compile cache takes Sword's libraries and only the translation runs again (the Mac build: 21,974 filled from Sword's, 45,728 reused, 176 compiled; 15 minutes for the 41,516; the iOS build: 21,684 filled, 175 compiled). IPA 12.4 GB.

## Performance

- On the Mac: 30 fps as on the Switch (frame time p50 33.3 ms, p95 34–35 ms in the house and outside in Postwick), no red line in 10 minutes from a fresh save.

## Mac routes

- The work folder's `run/boot.sh`, `run/ctl.sh` and `run/step.sh` are Sword's, run headless as there; `run/mash.sh <prefix> <rounds>` presses A ten times a round and takes a screenshot after each.
- From a fresh save (`DM_KBD` answers the name; without it the keyboard counts as cancelled and the game goes back to the photo), A at the language (about frame 600), the photo and the name reach the opening; A presses lead through it to the living room in Postwick, and the stairs to the bedroom with the Bag.
- `run/save_ref` is a save in the bedroom with the Bag taken, the same place as Sword's: Sword's route out of the front door (`LDown~0.8 LLeft~2.5 LRight~0.5 LDown~2.5 LLeft~0.3 LDown~2`, `run/route_out.sh`) works unchanged.
- The route checked on the Mac: the first boot's language, photo and name choices, the opening (the Champion's broadcast, the stadium), Postwick (the house, Hop's visit, the bedroom and the Bag), a save, and out of the front door to Hop.

## Live location research

Current prototype (2026-10-28): the [live location probe](../../../docs/shield-live-location.md) now resolves a live area/zone object through a module-relative global, checks its identity and a separate save-state mirror, and validates area/zone membership. The [build-gated research profile](live_location.json) contains the offsets. A host write watch caught the zone store at `main+0xdcb83c`; local disassembly connects it to the global's object. The resolver worked in that process and two fresh processes with different module bases, requiring no memory scan in the fresh processes. User-confirmed unsaved Postwick/Route 1 crossings tracked correctly. A title-screen sample returned unknown despite the mirror already containing Route 1, and user-confirmed Hop's house returned unknown for an unmapped interior instead of an outdoor label. The outdoor tests left the copied save unchanged; the interior step changed the experiment's committed save, with autosave uncontrolled. No source save or app was modified. Broader regions, interiors, loading/restore/menu behavior and iOS remain unvalidated. No game-specific host behavior was added.

Interior mapping follow-up: the existing Hop's house capture now resolves to **Hop's house — Postwick**. Placement members 148–150 explicitly map three interior area/zone pairs to Postwick's place-name key; their exits link directly to the Postwick exterior zone, or through the other interior. Two interiors with unverified room names use **Indoors — Postwick**, preserving their exact IDs. This update was checked against the archived live house observation and static game placement data; it does not add new live interior coverage. See the probe's [interior context behavior](../../../docs/shield-live-location.md#interiors-and-exterior-context).

## Opening walkthrough preview

Open **Guide → Open Pokémon Shield Guide** on the Mac or **Pokémon Shield
Guide** from the in-game menu on iPhone or iPad. Browse 31 areas across the
Gym Challenge, the Champion Cup and base-game postgame, from Postwick to
the Battle Tower. Town and route checklists include gifts, trades, side
quests, hidden items and return visits.
Open **Pokémon to find** on the numbered routes, in the mines and forests,
or by the Motostoke and Hulbury fishing spots for Shield encounter lists.
Where applicable the lists distinguish encounter methods, forms and
subareas, including which Route 2 encounters require the water bike.
Turn on **Show missing Galar Pokémon only** to filter route, Wild Area, and
Max Raid lists using your last readable save. The filter uses species records,
so forms of a caught species share its checkoff.
In the South and North Wild Area guides, **Wild Area subareas** lets you select
any of 17 subareas and nine weather conditions. It shows Shield species,
forms, methods and base levels, including strong wanderers and which of them
appear after becoming Champion. Match the weather to what you see in-game.
By default the subarea follows the live location or the last readable save,
depending on the selected source. Pick a named subarea to browse it and
choose **Follow location** to resume following the game.
Open **Max Raid dens** in the selected subarea to browse standard Shield
pools by den, beam and star rank, with encounter odds and Gigantamax forms.
Tap or click a numbered pin on the north-up map to select its den. The map
shows approximate terrain and landmarks. Den numbers are guide references
and cover the ordinary dens in the base Wild Area.
Open **Recurring sparkles** in a subarea to see possible rewards and how many
of its spots are awaiting respawn in the last save. The guide covers 229
repeatable sparkles across the base Wild Area. Choose a spot to highlight its
position on the north-up locator and see its saved status and direction from
the nearest listed den. Den numbers match the Max Raid browser. Counts update
when you save.
Both Wild Area halves show separate saved Max Raid battle and catch counts.
Check off a win manually if you leave without catching the Pokémon.
Chloe’s activity shows her current team based on the Fire Badge and
Champion records in your save.
Open **Curry Dex** from either Wild Area half to see which of the 151 recipes
you’ve cooked and which Camping King rewards are ready for assessment.
The guide reads recipe progress and reward records from the last save.
The North Wild Area checklist tracks Rotom Rally finishes and rewards, the
three Rotom Bike turbo upgrades and each Digging Duo brother’s best run.
Route 5 checks off the Rotom Bike and Route 9 tracks its Water Mode
upgrade. Water detours show where to go once the upgrade is in your
save. Both halves of the Wild Area show your equipped cycling outfit
when you choose a type color from a Rotom Rallyist.
Route 5 and Bridge Field each track their Nursery’s Flying Taxi stop,
deposited Pokémon and waiting Egg. Both show your saved hatch total.
Circhester checks off the Oval Charm separately from Morimoto’s first win.
Open **Galar Pokédex** in the Circhester guide to find uncaught species among
the 400 regional entries. The director’s checklist shows when the saved dex
is complete and checks off the Shiny Charm when its award is recorded.
Select a species to see its listed routes, Wild Area weather and methods,
raid dens and ranks, or a known gift, trade, fossil, or story source.
Entries without a listed encounter have an acquisition hint such as an
evolution requirement or a trade with Sword.
Route 6 lists all four fossil recipes and shows how many of each required
piece are in your Bag. Each species checks off when your Galar Pokédex
records it. The guide also recognizes your own Route 6 revivals while the
Pokémon are in your party or Boxes. Stow-on-Side’s gift checks off when the
visit and two Fossilized Drakes are recorded.
Open **Singles records** or **Doubles records** in the Battle Tower guide to
see your current rank, highest rank and wins from the last save. The
reward lists show which rank and win milestones you’ve reached, the
prizes for each, and progress through the repeat rewards after 200 wins. The
checklist also tracks each format’s Master Ball Tier and the Judge unlock.
Open **Silvally Memories** in the Battle Tower to see which of the 17
types are in your Bag or held by a saved party or Box Pokémon. The
Memories checkoff uses the gift sequence and the full set.
Open **Rotom forms** in Wyndon for the Catalog’s appliance options,
their types and moves, and the saved party or Box location of each
owned form. Forms you have seen also appear from their Pokédex records.
Open **Gigantamax collection** in either half of the Wild Area to track
the 25 launch-era Galar species. The guide finds the Gigantamax Factor
in your saved party and Boxes and shows base Shield den locations, gifts
and other acquisition routes.
Open **Alcremie collection** on Route 4 or in any Battle Café town to
track all 63 flavor-and-decoration combinations in your party and Boxes.
The guide shows spin recipes, Sweet sources, and how many Sweets are in
your Bag or held by Pokémon.
Open **Battle Café prizes** in Motostoke, Hammerlocke or Wyndon for that
café’s reward odds and the next prize indicated by the last save’s roll.
The daily flag reports challenge use as of the last save.
Open **Street Market** in Stow-on-Side for the saved bargain stock and
tomorrow’s preview, plus the buyer’s requested treasure, payout and
Bag count. The panel also lists the bargain odds and buyer prices.
Open **Sinistea evolutions** in Stow-on-Side or Glimwood Tangle for the
Cracked and Chipped Pot sources and saved quantities. It shows where
your Phony and Antique Sinistea and Polteageist are stored. Stow-on-Side
checks off each Polteageist form independently.
Hammerlocke’s Ribbon activities point to an eligible Pokémon in your
party or Boxes. The guide checks off Best Friends, Effort and Tower Master
Ribbons when they appear on a Pokémon in the saved collection.
The Battle Tower also checks off Hyper Training when a saved Pokémon has a
Hyper-Trained stat.
The four base-game move tutor activities check off when a Pokémon in your
saved party or Boxes knows one of that tutor’s moves. Hammerlocke and
Wyndon also show how many of their three moves you currently have.
Hammerlocke’s weather lessons show the next lesson from the last save and
count the five rewards from Bag entries or items held by Pokémon. The
friendship house, Mr. Focus, the Eviolite battle, two Motostoke gifts and
the Route 3 Cheri Berry check off from the saved interaction and reward
evidence. A retained Bag entry still counts after the stack runs out.
The Wild Area Station’s Poké Dolls, Magnolia’s Master Ball and the Stow-on-Side
Beast Ball also use saved visits and rewards. A past Bag entry or matching
personal catch can supply evidence for the two ball gifts. The
Hammerlocke boy’s activity points to an Applin in your party or Boxes
and shows when the save records that you discussed his request. Check
off the Sweet Apple quest after you help him.
Routes 3 through 10 each show their campsite Flying Taxi stop and
automatically check it off when the destination is saved. Route 3’s
Cheri Berry gift uses its own visit and reward evidence. Wedgehurst’s
post-lab Potion uses the verified opening stages. Outside those stages,
the Potion entry has a manual checkoff.
Open **League Card album** in the Motostoke or Battle Tower guide to see
all 27 base-game cards obtainable in Shield and where to get them. Each
card also appears in its own area and checks off from the saved album.
Open **Card Maker styles** in Motostoke or the Battle Tower to see how many
backgrounds, effects, frames, expressions, poses and coatings are available.
Town checklists show the options each visit, badge or event unlocks and
list the prices of paid coatings. Motostoke tracks the earnings, personal
card and hairstyle backgrounds. The South Wild Area tracks the Curry Dex
and Max Raid milestones.
Open **Uniform wardrobe** in a stadium town or at the Battle Tower to
track the 22 uniforms listed in the base guide. Gym and event rewards
also appear in the local checklist. The four salon towns share a checkoff
for the first saved Hair service.
Open **Boutique** in Wedgehurst, Motostoke, Hammerlocke, Circhester or
Wyndon to see your avatar’s clothing options by category. Each color has
its own ownership status. Unowned pieces show their prices. The stock
expands when the Style Card is in your saved Key Items.
Open **Local TMs** to see the TMs you can buy, find or earn in the area,
with directions and shop prices. **TM case** in Motostoke and at the
Battle Tower tracks all 100 reusable TMs from the Machines pocket in
your latest save. Field pickups and reward events have their own checkoffs.
Open **Technical Records** in either half of the Wild Area to see all
100 TRs, the number of copies in your saved Bag, and their prices in Watts.
The collection count includes TRs with a saved Bag entry after the last
copy was used.
The guide lists nearby Watt Traders, whose stock rotates daily. Max Raid
Battles can also award TRs. Teaching a move spends one copy.
Open **Postgame stadiums** in Wedgehurst for the seven stadium incidents.
Each stadium checks off from its own resolution record. The Energy Plant
guide tracks Eternatus and Zamazenta registration and identifies your
own rooftop catches in the saved collection. Hammerlocke and the
Slumbering Weald check off their own conversations with Sonia. The
Weald also checks for Sonia’s Book in Key Items and tracks Hop’s
epilogue from its event record.
Open **Gym Challenge** in Motostoke to see mission and badge progress
for all eight Gyms. Each stadium has both checkoffs in its own guide.
Motostoke also shows the saved Fire Gym mission score while the mission
is active. The Champion Cup has its own checkoff in Wyndon.
Hints appear before directions. Manual checkoffs are stored locally, and the
Battle Café and Loto-ID checkoffs follow the device's calendar day.
**Current game** follows supported live locations on Shield 1.3.2. During a
transition or when live location is unavailable, it uses the last readable
saved location or the manually selected area. **Last game save** and
**Browse manually** are also available directly. Objectives and progress
read the committed save while the guide is visible, including with cloud sync
disabled. The guide shows
guide text for all 120 base Town Map guidance tokens and reads the Pokédex
unlock from the save. Later area matches use exact placement-table pairs and
display as estimates. Supported save indicators include all eight Gym mission
and Gym clear records, seven individual postgame stadium records, and selected
gifts, trades, puzzles and quest stages. The guide automatically checks off
supported visible pickups, fixed hidden sparkles, fixed trades and selected
quest steps from the latest readable save. Recurring sparkles can show as
collected until they respawn. The remaining activities offer reversible
player checkoffs. The three archive previews also show their recorded party.

Postwick tracks the first Hop victory from its saved win flag. The
Champion Cup return lists Sonia’s three Max Revives as a player checkoff.
The [Apple suite](../../apple/tests/run_tests.py) exercises these rules
and other guide cases with synthetic saves. The Mac Guide menu smoke test
and [unsigned iOS build check](../../ios/tools/build_smoke.py)
cover desktop refresh and iOS compilation. Physical-device guide checks
remain pending.

The full base-route audit adds landmark directions for fixed pickups and
65 field Trainer checkoffs with native Shield teams. Route 2 Hop victory
uses its independent saved flag. Batch 3 estimates field Trainer completion
from each opponent's native flag, requiring both flags for six doubles pairs.
Special-result paths still limit a universal win-only interpretation. The
[tracking audit](../../../../implementation-plans/shield-smart-guide/batch-3-tracking-audit.md)
records that boundary and the reviewed events that use explicit player marks.
The Wild Area selector includes directions for each encounter subarea, and
the Battle Tower and Rose Tower list the same courtyard pickups. The full
Apple suite, Mac guide window, archived opening replay, Mac host build and
unsigned iOS Release smoke build passed for the route audit.

## Guide arrival and planning (2026-11-17)

The guide opens with a compact nearby checklist. Expand more nearby work,
later visits or completed entries, or enable **Show incomplete only**. Local
search includes activity hints, directions and service references. Reveal an
activity's details for preparation, saved evidence, access requirements and
links to related areas. Letter steps link Hammerlocke and Ballonlea; water
detours link to Route 9. Following a link enters manual browsing.

Both front ends now use one shared source policy for checklist and collection
progress. Manual browsing retains the last readable save with attribution.
A live location can disagree with the separately labeled last-saved objective;
an old local next step is suppressed on mismatch. Archive references hide
current progress and local marks, and stale refreshes suppress dynamic panels.
An unknown access prerequisite is distinct from a recorded unmet prerequisite.
See the [arrival audit](../../../../implementation-plans/shield-smart-guide/batch-4-arrival-audit.md)
and [verification](../../../../implementation-plans/shield-smart-guide/verification.md#batch-4-verification).
Mac Guide menu, keyboard and sizing checks pass. The production guide also
passes source, filter/search, long-list navigation, rotation and stale recovery
tests in iPhone and iPad simulators. Physical devices and the actual Game Menu
under gameplay load remain later observations.

## Guide release rehearsal (2026-11-17)

Batch 5 compares 16 generated journey expectations through the shared reader,
Mac menu and iOS simulator views, including Minccino/letter stages, the Ice Gym
retry, Café saved use and collection removal. The SwiftUI guide now keeps its
presentation object on unchanged timer polls, avoiding native source-menu
selection disruption. Source changes, live moves and saved changes still
refresh immediately. A separate Sword-profile compile verifies that the Guide
menu and Shield save/live callbacks remain disabled even with Shield's build ID.
See the [release rehearsal](../../../../implementation-plans/shield-smart-guide/batch-5-release-rehearsal.md)
and [verification](../../../../implementation-plans/shield-smart-guide/verification.md#batch-5-verification).
Actual older-game restoration, field Trainer loss/draw, late positive outcomes,
game midnight/clock changes, motion input and physical phone/tablet gameplay
menus remain open observations. Spoken VoiceOver is excluded from acceptance
at the owner's request; see the release rehearsal's gameplay queue.

## Guide source completeness audit (2026-11-18)

The [final source audit](../../../../implementation-plans/shield-smart-guide/final-source-audit.md)
reconciles 244 readable printed pickup rows and all 56 side-index rows to
compiled keys. It also exposes incomplete full-book references that were
previously described only as material in the source. Jack’s Center services,
Camping King tent colors, camping visitor/host basics, Hulbury herbs and
Hammerlocke/Tower BP purchase directions now appear in local service search.
These are reference entries, with no new automatic completion claims or keys.
The subsequent [reference-gap closeout](../../../../implementation-plans/shield-smart-guide/reference-gap-closeout.md)
adds **Offline handbook and reference** on Mac and iOS: 3,085 entries in 50
categories, including all 547 printed moves, 196 Abilities, 375 items, 400 EV
and 400 Egg Group rows, all type matchups, jobs, rosters, reward pools, shops
and customization choices. Category selection, multiword search, 25-result
pages and selectable source-cited details work without a save. The
[reference crosswalk](../../apple/tests/shield_guide_reference_coverage.json)
accounts for all 24 formerly partial/missing textual families. Card Maker
variants identify individual choices within native unlock groups; artwork
and native menu-slot numbering are not reproduced. Image-only map pins and
gameplay observations remain outside this textual coverage claim. No
checklist keys or completion rules changed. Routine tests need no private
inputs; regenerate the compiled data with `python3 dm/apple/tools/build_shield_reference.py`.

## Phone-controller receiver build (2026-11-08)

Shield 1.3.2 (`v458752`), with both DLC packages, was rebuilt into a complete
iOS IPA using Xcode 27.2 and the pinned Metal compiler 32023.922
(`metalfe-32023.922.4`). All 41,516 shaders built for chain `094f939bfef9`;
the shader comparison against the previous `a4e2088c2e69` build reported zero
regressions and nothing lost without failing. The actual game app compiled and
linked (270 files) with the shared [phone-controller receiver](../../controller/README.md),
including its pairing UI and LAN/Bluetooth permission declarations. The 9.5 GB
IPA bundles the RomFS, both DLC images and current shader libraries. This is
build/package evidence; this new package's physical gameplay and phone-to-game
input have not been accepted yet. No device installation was performed.
