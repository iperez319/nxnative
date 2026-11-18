"""Exercise the live probe's evidence rules and real file/control handshake."""
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch, Mock

SCRIPT = Path(__file__).resolve().parents[3] / 'scripts/shield_live_location.py'
SPEC = importlib.util.spec_from_file_location('shield_live', SCRIPT)
live = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(live)


class LocationProbeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        output = patch('sys.stdout', new_callable=io.StringIO)
        output.start()
        self.addCleanup(output.stop)
        self.root = Path(self.temp.name)
        self.app = self.root / 'Shield.app'
        modules = self.app / 'Contents/Resources/dm'
        modules.mkdir(parents=True)
        (modules / 'main.fixups.tsv').write_text('# BUILD_ID\t' + live.BUILD + '\n')
        host = self.app / 'Contents/MacOS/dmhost'
        host.parent.mkdir()
        host.touch()
        self.source = self.root / 'original'
        self.source.mkdir()
        (self.source / 'main').write_bytes(b'original committed save')
        self.run = self.root / 'experiment with spaces'
        with patch.object(live.subprocess, 'Popen', return_value=Mock(pid=1234)) as spawn:
            with patch.dict(os.environ, {'DM_KEYS': 'A*999', 'DM_PROBE': 'write', 'DM_SAVE': 'wrong'}):
                live.launch(self.app, self.source, self.run)
            self.environment = spawn.call_args.kwargs['env']
        self.probe = live.Probe(self.run)

    def test_launch_isolates_save_and_scrubs_automation(self):
        (self.run / 'save/main').write_bytes(b'changed by the test game')
        self.assertEqual((self.source / 'main').read_bytes(), b'original committed save')
        self.assertEqual(self.environment['DM_SAVE'], str(self.run / 'save'))
        self.assertNotIn('DM_KEYS', self.environment)
        self.assertNotIn('DM_PROBE', self.environment)
        self.assertEqual(self.environment['DM_WINDOW'], '1')
        with self.assertRaisesRegex(ValueError, 'never overwritten'):
            live.launch(self.app, self.source, self.run)

    def test_rejects_wrong_build_before_starting(self):
        modules = self.app / 'Contents/Resources/dm'
        (modules / 'main.fixups.tsv').write_text('# BUILD_ID\twrong\n')
        with patch.object(live.subprocess, 'Popen') as spawn:
            with self.assertRaisesRegex(ValueError, 'only Shield'):
                live.launch(self.app, self.source, self.root / 'second')
            spawn.assert_not_called()

    def test_writer_trace_is_explicit_and_restricted_to_guest_memory(self):
        with patch.object(live.subprocess, 'Popen', return_value=Mock(pid=1235)) as spawn:
            state = live.launch(self.app, self.source, self.root / 'traced', watch_address=0x707419c558)
            self.assertEqual(spawn.call_args.kwargs['env']['DM_PROBE_WATCH'], '707419c558+8')
            self.assertEqual(state['instrumentation']['kind'], 'host-write-watch')
        with patch.object(live.subprocess, 'Popen') as spawn:
            for address in (0x1000, 0x7100000000, 0x707419ffff):
                with self.assertRaises(ValueError):
                    live.launch(self.app, self.source, self.root / 'invalid', watch_address=address)
            spawn.assert_not_called()

    def root_fixture(self, displacement=0):
        profile = json.loads(live.PROFILE.read_text())
        self.main_base = 0x100000000
        heap = 0x7000000000
        self.primary_object = heap + 0x1000 + displacement
        parent, mirror = heap + 0x3000 + displacement, heap + 0x5000 + displacement
        self.root_memory = {}
        def put(address, value, size=8):
            self.root_memory.update({address + i: b for i, b in enumerate(value.to_bytes(size, 'little'))})
        self.put_root = put
        p, m = profile['primary'], profile['mirror']
        put(self.main_base + int(p['root'], 16), self.primary_object)
        put(self.primary_object + int(p['vtable_field'], 16), self.main_base + int(p['vtable'], 16))
        put(self.primary_object + 0x48, 0x9A3DF7D37DB70B41)
        put(self.primary_object + 0x50, live.ZONES['route1'])
        put(self.main_base + int(m['root'], 16), parent)
        put(parent + int(m['pointers'][0], 16), mirror)
        put(mirror + int(m['vtable_field'], 16), self.main_base + int(m['vtable'], 16))
        put(mirror + int(m['zone_field'], 16), live.ZONES['route1'])
        self.mirror_object = mirror
        self.probe.ranges = lambda: [(self.main_base, 0x29e4000), (heap, 0x1000000)]
        def read(address, count):
            try:
                return bytes(self.root_memory[address + i] for i in range(count))
            except KeyError as error:
                raise ValueError('unreadable pointer') from error
        self.probe.read = read
        return profile

    def test_module_roots_follow_moved_objects_without_scan(self):
        for displacement in (0, 0x100000):
            self.root_fixture(displacement)
            self.assertNotIn('scan', self.probe.state)
            report = self.probe.resolve()
            self.assertEqual(report['candidate_location'], 'Route 1')
            self.assertEqual(report['primary_object'], hex(self.primary_object))
            self.assertEqual(report['area_name'], 'a_0101')
            self.assertIsNone(report['current_location'])
            self.assertTrue(report['committed_save_unchanged_since_launch'])
        self.assertEqual(self.probe.state['candidates'], [])

    def test_module_roots_fail_closed(self):
        for failure in ('null', 'primary_vtable', 'mirror_vtable', 'mirror_disagrees', 'unknown_area', 'wrong_area_zone', 'changing_pair'):
            with self.subTest(failure=failure):
                profile = self.root_fixture()
                if failure == 'null':
                    self.put_root(self.main_base + int(profile['primary']['root'], 16), 0)
                elif failure == 'primary_vtable':
                    self.put_root(self.primary_object, self.main_base + 0x1234)
                elif failure == 'mirror_vtable':
                    self.put_root(self.mirror_object + 0x48, self.main_base + 0x1234)
                elif failure == 'mirror_disagrees':
                    self.put_root(self.mirror_object + 0x68, live.ZONES['postwick'])
                elif failure == 'unknown_area':
                    self.put_root(self.primary_object + 0x48, 0)
                elif failure == 'wrong_area_zone':
                    self.put_root(self.primary_object + 0x48, 0xDF864AE11FD1F74F)
                else:
                    original = self.probe.read
                    reads = []
                    def changing(address, count):
                        data = original(address, count)
                        if count == 16:
                            reads.append(address)
                            if len(reads) == 2:
                                data = data[:8] + live.ZONES['postwick'].to_bytes(8, 'little')
                        return data
                    self.probe.read = changing
                report = self.probe.resolve()
                self.assertEqual(report['status'], 'unknown')
                self.assertIsNone(report['candidate_location'])
                self.assertIn('reason', report)

    def test_module_root_profile_build_must_match(self):
        self.root_fixture()
        profile = json.loads(live.PROFILE.read_text())
        profile['build'] = 'other-build'
        incompatible = self.root / 'incompatible.json'
        incompatible.write_text(json.dumps(profile))
        with patch.object(live, 'PROFILE', incompatible):
            with self.assertRaisesRegex(ValueError, 'profile does not match'):
                self.probe.resolve()

    def test_interiors_keep_exact_identity_and_explicit_exterior_context(self):
        cases = (
            (0xD08669201CEB5B3E, 0xA9AB2CAA935AB8AB, "Hop's house — Postwick", 'named-interior'),
            (0xB6F6DA200E8FFE23, 0xC4811BAAA2CB7B86, 'Indoors — Postwick', 'exterior-context'),
            (0xD08668201CEB598B, 0xA9AB2DAA935ABA5E, 'Indoors — Postwick', 'exterior-context'),
        )
        for area, zone, label, precision in cases:
            with self.subTest(area=area):
                self.root_fixture()
                self.put_root(self.primary_object + 0x48, area)
                self.put_root(self.primary_object + 0x50, zone)
                self.put_root(self.mirror_object + 0x68, zone)
                report = self.probe.resolve()
                self.assertEqual(report['candidate_location'], label)
                self.assertEqual(report['location_kind'], 'interior')
                self.assertEqual(report['location_precision'], precision)
                self.assertEqual(report['zone_id'], f'{zone:016X}')
                self.assertEqual(report['exterior_location']['label'], 'Postwick')
                self.assertEqual(report['exterior_location']['zone_id'], '019B5DC049D8CB3E')

    def test_interior_fallback_does_not_guess_from_unknown_or_conflicting_state(self):
        self.root_fixture()
        self.put_root(self.primary_object + 0x48, 0xD08669201CEB5B3E)
        self.put_root(self.primary_object + 0x50, 0xA9AB2CAA935AB8AB)
        # The mirror still says Route 1: no interior or exterior suggestion.
        report = self.probe.resolve()
        self.assertIsNone(report['candidate_location'])
        self.assertIsNone(report['exterior_location'])
        self.put_root(self.mirror_object + 0x68, 0xA9AB2CAA935AB8AB)
        self.put_root(self.primary_object + 0x48, 0x1234)
        report = self.probe.resolve()
        self.assertIsNone(report['exterior_location'])
        profile = json.loads(live.PROFILE.read_text())
        profile['areas']['D08669201CEB5B3E']['exterior']['zone_id'] = 'UNKNOWN'
        with self.assertRaisesRegex(ValueError, 'no verified exterior'):
            live.describe_location(profile, 'D08669201CEB5B3E', 'A9AB2CAA935AB8AB')

    def fake_response(self, actual=None):
        def respond(line):
            # Model the production host's final completion line, after fclose.
            command, address, count, path = line.split(' ', 3)
            self.assertEqual(command, 'memdump')
            count = int(count)
            data = b'abcdefgh'[:actual if actual is not None else count]
            Path(path).write_bytes(data)
            with (self.run / 'log.txt').open('a') as log:
                log.write(f'[dm] DM_CTL: memdump 0x{address}: {len(data)} of {count} bytes → {path}\n')
        return respond

    def test_control_handshake_handles_spaces_and_removes_raw_bytes(self):
        self.probe.command = self.fake_response()
        self.assertEqual(self.probe.read(0x1234, 8), b'abcdefgh')
        self.assertEqual(list(self.run.glob('read-*.bin')), [])

    def test_short_reads_fail_closed_for_observation(self):
        self.probe.command = self.fake_response(actual=3)
        with self.assertRaisesRegex(ValueError, 'Incomplete memory read'):
            self.probe.read(0x1234, 8)
        self.assertEqual(self.probe.read(0x1234, 8, allow_partial=True), b'abc')
        self.assertEqual(list(self.run.glob('read-*.bin')), [])

    def test_timeout_cannot_return_old_dump(self):
        self.probe.command = lambda line: None
        with self.assertRaises(TimeoutError):
            self.probe.read(0x1234, 8, timeout=0.001)

    def scan_fixture(self):
        # One word crosses a 16-byte chunk boundary; another is unaligned.
        memory = bytearray(70)
        needle = live.ZONES['route1'].to_bytes(8, 'little')
        memory[13:21] = needle
        memory[39:47] = needle
        self.probe.ranges = lambda: [(0x1000, 80)]
        self.probe.read = lambda a, n, **kw: bytes(memory[a - 0x1000:a - 0x1000 + n])
        self.probe.scan('route1', chunk_size=16)
        self.assertEqual(self.probe.state['candidates'], [0x100d, 0x1027])
        self.assertTrue(self.probe.state['scan']['short_reads'])

    def test_unsaved_crossing_filters_stale_copy_but_never_claims_location(self):
        self.scan_fixture()
        memory = bytearray(70)
        memory[13:21] = live.ZONES['postwick'].to_bytes(8, 'little')
        memory[39:47] = live.ZONES['route1'].to_bytes(8, 'little')
        self.probe.read = lambda a, n: bytes(memory[a - 0x1000:a - 0x1000 + n])
        report = self.probe.observe('postwick')
        self.assertEqual(report['consistent_addresses'], ['0x100d'])
        self.assertEqual(report['candidate_location'], 'Postwick')
        self.assertEqual(report['current_location'], None)
        self.assertEqual(report['status'], 'unvalidated-candidates')
        self.assertTrue(report['committed_save_unchanged_since_launch'])
        # Reverse traversal retains the same candidate, even with two copies
        # again matching Route 1. History, rather than latest count, filters it.
        memory[13:21] = live.ZONES['route1'].to_bytes(8, 'little')
        report = self.probe.observe('route1')
        self.assertEqual(report['consistent_addresses'], ['0x100d'])
        self.assertEqual(report['candidate_location'], 'Route 1')
        # Unlabelled live watching follows just the surviving candidate and
        # changes the suggestion without receiving the desired location.
        memory[13:21] = live.ZONES['postwick'].to_bytes(8, 'little')
        report = self.probe.observe(tracked_only=True)
        self.assertEqual(report['candidate_location'], 'Postwick')
        self.assertEqual(report['latest_candidate_labels'], {'Postwick': 1})
        (self.run / 'save/main').write_bytes(b'saved after movement')
        self.assertFalse(self.probe.observe()['committed_save_unchanged_since_launch'])

    def test_unreadable_candidate_is_not_replaced_by_stale_value(self):
        self.scan_fixture()
        def unreadable(a, n):
            raise ValueError('unmapped')
        self.probe.read = unreadable
        report = self.probe.observe('postwick')
        self.assertEqual(report['consistent_candidates'], 0)
        self.assertEqual(report['latest_candidate_labels'], {'unknown/unreadable': 2})
        persisted = json.loads((self.run / 'session.json').read_text())
        self.assertEqual(set(persisted['observations'][-1]['values'].values()), {None})


if __name__ == '__main__':
    unittest.main()
