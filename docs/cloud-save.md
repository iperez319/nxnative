# Cloud saves

On iPhone/iPad, the Play page shows a short save status and **Set up cloud
saves** when disconnected. Cloud saves are optional; **Play** works locally
without setup. Once connected, **Play** checks cloud progress before starting
the game. Conflicts show device/cloud save summaries and let you choose a copy,
play offline, or go **Back** without starting. Pairing and restoring return to
the page until you choose to play. **More** groups cloud backups, offline play,
backup files, connection settings and technical details. Pairing entry and file
selection use system dialogs only when requested.
Mac apps and iOS builds with the settings launcher disabled retain the separate
prelaunch **Cloud saves** dialog. Sync is disabled until paired.
Use the companion `cloud-save-service` directory's README to deploy the Linux
service behind the Whatbox HTTPS endpoint. Existing installed apps must be
rebuilt; shader outputs remain reusable.

Pair using the HTTPS URL and a ten-minute, one-use code issued on the server.
Each app/device has its own revocable Keychain token. Never put a token or
seedbox password in env.txt. Shared Keychain access groups are not enabled.

Save in-game, open **Game menu → Saves and backups**, and choose **Sync now**.
Wait for **Ready for another device**, then launch on the other device and check
the cloud before playing. **Sync now** captures committed files; it cannot
save unsaved gameplay or transfer running memory. Choosing **Play offline** durably pauses automatic uploads and cloud polling,
including after a background relaunch. **Sync now** or an accepted prelaunch
reconciliation resumes uploads. Both devices advancing can still create a conflict. Choose a complete branch before
launch. History and displaced local snapshots remain recoverable; game files
are never merged. An older history restore creates a new revision. Different
or unknown game builds/DLC require explicit confirmation.

On iPhone/iPad, the small icon beside the top controls opens **Game menu → Saves
and backups** while playing. Its circular activity indicator means an upload is
in progress; a cloud checkmark means uploaded, a crossed cloud means paused,
and an orange attention icon means a save needs review. It retains a 44-point
touch target and a spoken status for VoiceOver. Full status text stays in the menu.
Turn off **Save status indicator** beside the FPS setting (or in **Feedback /
display**) to use a static menu icon from the next launch. Cloud syncing continues.
Mac uses the
Cloud saves app menu. The mobile save screen updates live and offers actions
that are available at that point; import, cloud restore and connection setup
are prelaunch tools. Remote changes during play require restart. Background
uploads can continue under normal system suspension, but force-quit can cancel
them until the app is reopened. On Mac, use **Prepare to switch devices** before a handoff.

Save paths remain Documents/save (iOS) and the existing title directory under
Application Support/nxnative (Mac). A separate save_device root is included
where used. Archives explicitly preserve physical aliases and guest-name
attributes. The save.cloud-sync sibling contains queue files, a restore journal,
and local backups; it is excluded from iCloud backup. Do not alter an active
journal or queued files. A failed restore rolls all roots and sync metadata back
before the guest starts. Imported roots expose the restore flag until a
successful CommitOption clears it.

The initial client limits expanded files to 64 MiB, queued archives to three,
and pending captures to two. At a 256 MiB retained-history threshold it stops
new automatic queue/archive and cloud-history restore work and reports the reason. Existing committed saves
remain usable. Export retained recovery copies before clearing unreferenced
history; do not delete the live state or queued archives. This is a conservative
starting limit pending measurements, not a claim that all titles fit.

## Device handoff and status

Save in-game, then choose **Sync now** on the mobile save screen. If uploads
were paused, the button says **Resume & sync** so resuming is an explicit choice.
The Mac action remains **Prepare to switch devices → Continue**.
The coordinator waits for captures and
ordered uploads, verifies receipts, and checks that the remote head still matches.
Only then does the mobile summary show **Ready for another device**. **Last save
uploaded** alone describes an acknowledged save, not a completed handoff check.
Revision and confirmation details remain available under **More → Technical
details**; the Mac status uses **Committed save uploaded — check cloud on the other device**.
New local commits invalidate readiness;
unknown outcomes, conflicts or a newer head cannot produce success. A 90-second
wait expiry leaves durable uploads intact. Leaving the save screen does not cancel
queued work. Always perform prelaunch reconciliation on the destination.

Status snapshots distinguish local-only, pending, uploading, uploaded, offline
pause, conflict, remote advance and recovery/error states. Pending captures count
separately from uploads. Revision, confirmed upload time and source device are
shown when known; unknown metadata is labeled honestly. Device times are descriptive,
not used to decide which conflicting branch wins.

## Local backups

**More → Backup files → Export backup file** works before launch and during play, without pairing or network
access. It clones committed account/device roots under the filesystem locks, then
builds and validates NXSave v1 on the worker. Save in-game first: it cannot save
running memory. On mobile, exporting goes directly to the destination picker
without an extra confirmation. Choose a destination in Files (iOS) or the save panel (Mac).
The staged export survives until the picker completes or is cancelled. Cancellation
removes only disposable staging, never live roots, history or queue archives.

**Recovery copies** (called **Retained recovery copies** on Mac) exports preserved backups and archives without the
history quota blocking it. Exporting a directory recovery copy marks its original
build/time unknown; an existing archive retains its metadata. No history is deleted.
If staging fails, free unrelated storage and retry rather than removing journals
or active queue files.

**Import backup file** accepts only nxNative `.nxsave` archives before launch. The app
bounds the input to 128 MiB, validates paths, roots, hashes and the 64 MiB expanded
limit, rejects other titles/profiles, and asks explicitly about different or unknown
build/DLC metadata. Confirmation shows the archive identity and the local progress
it replaces. Restore first verifies a recovery copy, then uses the restore journal;
interruption restores both roots and local sync metadata before game startup.

For paired apps, import retains previous queued candidates and ancestry, preserves
offline pause, and blocks automatic publication until an explicit prelaunch branch
choice. An outstanding transport prevents import until its receipt is reconciled.
Late callbacks cannot acknowledge the imported branch. Import never installs foreign
credentials or sync state. Import/history actions appear before launch only;
cloud changes during play explain that a restart is required. Cloud history
always confirms replacement, including any build/DLC concern, before restoring.
Raw folders and third-party formats are not supported.

## User-run pilot

Back up the current save directories first. Follow the repository's normal
unsigned build/sideload workflow; agents must not sign or install devices.

1. Deploy the service and run its live HTTP tests and backup/verify commands.
   Check persistence after a service/process restart and the actual volume's
   SQLite/fsync behavior.
2. Rebuild Shield for matching versions on iPad and iPhone. Pair both. Upload
   the iPad save, cold-launch/check cloud on iPhone, advance/upload there, and
   return to iPad. Compare save contents, aliases and attributes at each hop.
3. Play offline on both from the same revision; reconnect and verify a conflict
   preserves both candidates. Exercise choosing each branch and restoring old
   history. Try a version mismatch separately.
4. Exercise lock/unlock, airplane mode, revoked credentials, system background
   completion and force-quit. Confirm a background-only wake never preloads or
   starts the game. Record commit latency and frame pacing during autosaves.
5. Repeat with a game using independent account/device saves, a different engine,
   and Mac. Verify cloud UI remains available with DM_LAUNCHER=0.

Synthetic tests cover archive metadata, two-root restore interruption, server
publication races and existing filesystem behavior. Device lifecycle, network
handoff, performance and cross-version gameplay still require this pilot.
