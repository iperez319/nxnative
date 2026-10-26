# Cloud saves

Rebuilt iOS and Mac apps offer **Cloud saves** before starting the guest, even
when the normal settings launcher is disabled. Sync is disabled until paired.
Use the companion `cloud-save-service` directory's README to deploy the Linux
service behind the Whatbox HTTPS endpoint. Existing installed apps must be
rebuilt; shader outputs remain reusable.

Pair using the HTTPS URL and a ten-minute, one-use code issued on the server.
Each app/device has its own revocable Keychain token. Never put a token or
seedbox password in env.txt. Shared Keychain access groups are not enabled.

Save in-game, wait for **Uploaded**, then launch on the other device and check
the cloud before playing. **Sync now** captures committed files; it cannot
save unsaved gameplay or transfer running memory. Choosing **Play offline** durably pauses automatic uploads and cloud polling,
including after a background relaunch. **Sync now** or an accepted prelaunch
reconciliation resumes uploads. Both devices advancing can still create a conflict. Choose a complete branch before
launch. History and displaced local snapshots remain recoverable; game files
are never merged. An older history restore creates a new revision. Different
or unknown game builds/DLC require explicit confirmation.

The on-screen Cloud button opens sync status while playing. Mac uses the
Cloud saves app menu. Remote changes during play require restart. Background
uploads can continue under normal system suspension, but force-quit can cancel
them until the app is reopened. Wait for Uploaded before a handoff.

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
new capture/restore work and reports Saved locally. Existing committed saves
remain usable. Export retained recovery copies before clearing unreferenced
history; do not delete the live state or queued archives. This is a conservative
starting limit pending measurements, not a claim that all titles fit.

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
