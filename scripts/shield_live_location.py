#!/usr/bin/env python3
"""Read-only Shield 1.3.2 location experiment using the Mac host's existing DM_CTL.

Launch an isolated save copy, scan for a manually confirmed zone, then observe
candidate addresses after moving WITHOUT saving. No guest writes, debugger,
fixed runtime addresses, or host rebuild by default. Optional writer tracing
changes page protections and emulates stores in the isolated process only.
See docs/shield-live-location.md.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import time
import uuid

TITLE = '01008DB008C2C000'
BUILD = 'a16802625e7826bf83b6f9708e475b91'
PROFILE = Path(__file__).resolve().parents[1] / 'dm/games' / TITLE / 'live_location.json'
# Only names verified against this build's own tables in the location research.
ZONES = {
    'postwick': 0x019B5DC049D8CB3E,
    'route1': 0x078BC1FF1A657844,
    'wedgehurst': 0xE80BCEC03B7D6E23,
    'route2': 0x10355EFF1F4DB0B5,
    'route2-alt': 0x10355BFF1F4DAB9C,
    'weald': 0x8F67CD45F405D66E,
}
LABELS = {'postwick': 'Postwick', 'route1': 'Route 1', 'wedgehurst': 'Wedgehurst',
          'route2': 'Route 2', 'route2-alt': 'Route 2', 'weald': 'Slumbering Weald'}


def stamp():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def write_json(path, value):
    tmp = path.with_suffix('.tmp')
    tmp.write_text(json.dumps(value, indent=2) + '\n')
    tmp.replace(path)


def save_hashes(folder):
    # Committed save only; never inspect the host's mutable .work directory.
    return {str(p.relative_to(folder)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(folder.rglob('*')) if p.is_file()}


def check_build(modules):
    text = (modules / 'main.fixups.tsv').read_text()
    match = re.search(r'^# BUILD_ID\s+(\w+)$', text, re.M)
    if not match or match[1] != BUILD:
        raise ValueError('This experiment supports only Shield 1.3.2 main build ' + BUILD)


def describe_location(profile, area_id, zone_id):
    """Decode a validated pair, preserving an interior's exterior context.

    Parent relationships are explicit, version-matched placement evidence.
    Never infer them from a last-observed zone or a shared outdoor area alone.
    """
    area = profile['areas'].get(area_id)
    if not area or zone_id not in area['zones']:
        raise ValueError('Area/zone pair is outside the verified mapping')
    zone = area['zones'][zone_id]
    result = {'area_name': area['name'], 'location_kind': area.get('kind', 'outdoor'),
              'interior_name': None, 'exterior_location': None}
    if result['location_kind'] == 'interior':
        exterior = area.get('exterior', {})
        parent = profile['areas'].get(exterior.get('area_id'))
        label = parent['zones'].get(exterior.get('zone_id')) if parent else None
        if not isinstance(label, str) or parent.get('kind', 'outdoor') != 'outdoor':
            raise ValueError('Interior has no verified exterior mapping')
        name = zone.get('interior_name')
        result.update(interior_name=name, exterior_location={**exterior, 'label': label},
                      location_precision='named-interior' if name else 'exterior-context',
                      candidate_location=f'{name or "Indoors"} — {label}')
    else:
        result.update(location_precision='zone', candidate_location=zone)
    return result


def launch(app, source, run, headless=False, watch_address=None):
    resources = app / 'Contents/Resources'
    modules = resources / 'dm'
    host = app / 'Contents/MacOS/dmhost'
    check_build(modules)
    if watch_address is not None and not 0x7000000000 <= watch_address <= 0x70fffffff8:
        raise ValueError('Writer trace address must be inside this build\'s guest reservation')
    page_size = os.sysconf('SC_PAGE_SIZE')
    if watch_address is not None and watch_address % page_size + 8 > page_size:
        raise ValueError('Watched bytes must lie within one host page')
    if not host.is_file() or not source.exists():
        raise ValueError('Game host or source save is missing')
    if run.exists():
        raise ValueError('Use a new run directory; existing experiments are never overwritten')
    if source.is_dir() and (source == run or source in run.parents):
        raise ValueError('Run directory must be outside the source save')
    run.mkdir(parents=True)
    save = run / 'save'
    if source.is_dir():
        shutil.copytree(source, save)
    else:
        save.mkdir()
        shutil.copy2(source, save / 'main')
    if not (save / 'main').is_file():
        raise ValueError('Source must be a committed Shield save folder or a main save file')
    (run / 'temp').mkdir()
    (run / 'ctl').touch()
    # A clean host environment prevents inherited scripted input and probe
    # writes. Cloud credentials still live in Keychain: select Play offline.
    env = {k: v for k, v in os.environ.items() if not k.startswith(('DM_', 'DMSH_'))}
    env.update(DM_ROOT=str(run), DM_ROMFS=str(resources / 'romfs'), DM_SAVE=str(save),
               DM_TEMP=str(run / 'temp'), DM_MSL_DIR=str(resources / 'msl'),
               DM_FONT_DIR=str(modules / 'font'), DM_NVN_SHMAP=str(modules / 'shader_map.tsv'),
               DM_AOC_DIR=str(resources / 'aoc'), DM_PSO_BUNDLE=str(resources / 'pso'),
               DM_CTL=str(run / 'ctl'), DM_AUDIO='0')
    if not headless:
        env['DM_WINDOW'] = '1'
    if watch_address is not None:
        env['DM_PROBE_WATCH'] = f'{watch_address:x}+8'
    state = {'schema': 1, 'session': uuid.uuid4().hex, 'created_at': stamp(),
             'title': TITLE, 'build': BUILD, 'app': str(app), 'source': str(source),
             'baseline_save_hashes': save_hashes(save), 'candidates': [], 'observations': []}
    if watch_address is not None:
        state['instrumentation'] = {'kind': 'host-write-watch', 'address': watch_address, 'bytes': 8,
                                    'note': 'Investigative address hint; revalidate in this launch. '
                                            'Host changes page protection and emulates stores.'}
    with (run / 'log.txt').open('w') as log:
        process = subprocess.Popen([str(host), str(modules)], cwd=run, env=env,
                                   stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
    state['pid'] = process.pid
    write_json(run / 'session.json', state)
    print(f'Experiment started (PID {process.pid}). Save copy: {save}', flush=True)
    print('At the save startup screen choose Play offline (or Play locally if unpaired).', flush=True)
    return state


class Probe:
    def __init__(self, run):
        self.run = run
        self.state = json.loads((run / 'session.json').read_text())
        if self.state['title'] != TITLE or self.state['build'] != BUILD:
            raise ValueError('Unsupported experiment session')
        check_build(Path(self.state['app']) / 'Contents/Resources/dm')

    def command(self, line):
        if '\n' in line or '\r' in line:
            raise ValueError('Control commands must be single lines')
        with (self.run / 'ctl').open('a') as ctl:
            ctl.write(line + '\n')

    def read(self, address, count, timeout=15, allow_partial=False):
        # Unique names prevent a late response to a timed-out request from
        # masquerading as the result of a later read. Consume only after the
        # host logs fclose, not while memdump is still writing.
        target = self.run / ('read-' + uuid.uuid4().hex + '.bin')
        log_path = self.run / 'log.txt'
        offset = log_path.stat().st_size
        self.command(f'memdump {address:x} {count} {target}')
        deadline = time.monotonic() + timeout
        received = ''
        try:
            with log_path.open(errors='replace') as log:
                log.seek(offset)
                while time.monotonic() < deadline:
                    received += log.read()
                    completed = re.search(r'DM_CTL: memdump [^\n]*: (\d+) of (\d+) bytes → '
                                          + re.escape(str(target)) + r'\n', received)
                    if completed:
                        actual, requested = map(int, completed.groups())
                        data = target.read_bytes()
                        if requested != count or len(data) != actual or (actual != count and not allow_partial):
                            raise ValueError(f'Incomplete memory read at {address:#x}: {actual}/{count}')
                        return data
                    time.sleep(0.02)
            raise TimeoutError('Host did not complete the memory read; check log.txt and that the game is running')
        finally:
            target.unlink(missing_ok=True)

    def ranges(self):
        text = (self.run / 'log.txt').read_text(errors='replace')
        heap = re.search(r'guest AS (0x[0-9a-f]+) \+(0x[0-9a-f]+)  heap (0x[0-9a-f]+)', text)
        main = re.search(r'main: base (0x[0-9a-f]+) size (0x[0-9a-f]+)', text)
        if not heap or not main or '[mem] heap ' not in text:
            raise ValueError('Wait until the game has initialized its guest heap')
        # Scan the heap reservation, recording short reads at its uncommitted
        # tail. Do not mistake the reserved capacity for the committed size.
        base, size, start = (int(v, 16) for v in heap.groups())
        return [(int(main[1], 16), int(main[2], 16)), (start, base + size - start)]

    def persist(self):
        write_json(self.run / 'session.json', self.state)

    def resolve(self, expected=None):
        """Resolve module-relative roots without a scan or old candidate addresses.

        Keep a separate mirror, vtable identities and area membership as checks.
        The paired fields must also be unchanged across the mirror read; this
        detects some torn observations but is not an atomic game snapshot.
        """
        profile = json.loads(PROFILE.read_text())
        if profile['title'] != self.state['title'] or profile['build'] != self.state['build']:
            raise ValueError('Live location profile does not match the running game build')
        ranges = self.ranges()
        main, _ = ranges[0]
        heap, heap_size = ranges[1]
        def number(value):
            return int(value, 16)
        def word(address):
            return int.from_bytes(self.read(address, 8), 'little')
        def pointer(address):
            value = word(address)
            if not heap <= value <= heap + heap_size - 0x100:
                raise ValueError('Object pointer is outside the guest heap reservation')
            return value
        report = {'source': 'module-root-experiment', 'session': self.state['session'],
                  'at': stamp(), 'status': 'unknown', 'current_location': None,
                  'candidate_location': None, 'location_kind': None, 'location_precision': None,
                  'interior_name': None, 'exterior_location': None,
                  'expected_zone': expected, 'build': profile['build']}
        try:
            primary, mirror = profile['primary'], profile['mirror']
            root_slot = main + number(primary['root'])
            obj = pointer(root_slot)
            mirror_slot = main + number(mirror['root'])
            mirror_obj = pointer(mirror_slot)
            for offset in mirror['pointers']:
                mirror_obj = pointer(mirror_obj + number(offset))
            report.update(main_base=hex(main), root_slot=hex(root_slot), primary_object=hex(obj),
                          mirror_object=hex(mirror_obj))
            if word(obj + number(primary['vtable_field'])) != main + number(primary['vtable']):
                raise ValueError('Primary object vtable does not match this build')
            if word(mirror_obj + number(mirror['vtable_field'])) != main + number(mirror['vtable']):
                raise ValueError('Mirror object vtable does not match this build')
            area_address = obj + number(primary['area_field'])
            if number(primary['zone_field']) != number(primary['area_field']) + 8:
                raise ValueError('Profile area and zone must be adjacent')
            pair = self.read(area_address, 16)
            area, zone = int.from_bytes(pair[:8], 'little'), int.from_bytes(pair[8:], 'little')
            mirror_zone = word(mirror_obj + number(mirror['zone_field']))
            report.update(area_id=f'{area:016X}', zone_id=f'{zone:016X}', mirror_zone_id=f'{mirror_zone:016X}')
            if self.read(area_address, 16) != pair or pointer(root_slot) != obj:
                raise ValueError('Location changed during the observation; sample again')
            if zone != mirror_zone:
                raise ValueError('Primary and mirror zones disagree; sample again after the transition')
            description = describe_location(profile, f'{area:016X}', f'{zone:016X}')
            report.update(status='experimental-live-location', **description)
        except ValueError as error:
            report['reason'] = str(error)
        report['committed_save_unchanged_since_launch'] = save_hashes(self.run / 'save') == self.state['baseline_save_hashes']
        report['note'] = 'Research source; loading/menu/lifecycle validity still needs validation. No memory scan or save-file location read was used.'
        self.state.setdefault('root_observations', []).append(report)
        self.persist()
        write_json(self.run / 'root-report.json', report)
        print(json.dumps(report, indent=2), flush=True)
        return report

    def scan(self, zone, chunk_size=16 << 20):
        if self.state['observations']:
            raise ValueError('Use a new experiment for a fresh scan; preserve this observation history')
        ranges = self.ranges()
        needle = ZONES[zone].to_bytes(8, 'little')
        matches = set()
        total = sum(n for _, n in ranges)
        done = 0
        started = stamp()
        before = save_hashes(self.run / 'save')
        short_reads = []
        for base, size in ranges:
            for off in range(0, size, chunk_size):
                # Seven-byte overlap catches words straddling chunks, including
                # unaligned ones; no alignment assumption about the game structs.
                count = min(chunk_size + 7, size - off)
                data = self.read(base + off, count, allow_partial=True)
                if len(data) != count:
                    short_reads.append({'address': base + off, 'requested': count, 'read': len(data)})
                matches.update(base + off + i for i in find_all(data, needle))
                done += min(chunk_size, size - off)
                if len(matches) > 4096:
                    raise ValueError('Too many matches; refusing an unbounded candidate list')
                print(f'\rScanned {done / total:.0%}; {len(matches)} matches', end='', flush=True)
        print()
        self.state['candidates'] = sorted(matches)
        self.state['scan'] = {'zone': zone, 'started_at': started, 'finished_at': stamp(),
                              'ranges': ranges, 'matches': len(matches), 'short_reads': short_reads}
        self.state['observations'].append({'kind': 'scan', 'expected_zone': zone,
                                           'at': stamp(), 'save_hashes': before,
                                           'save_unchanged_during_scan': before == save_hashes(self.run / 'save')})
        self.persist()
        print(f'{len(matches)} candidates. Cross a location boundary without saving, then run observe.')

    def observe(self, expected=None, tracked_only=False):
        if not self.state.get('scan'):
            raise ValueError('Run scan in a manually confirmed location first')
        values = {}
        addresses_to_read = self.state['candidates']
        if tracked_only:
            addresses_to_read = [int(a, 16) for a in summarize(self.state)['consistent_addresses']]
        # Coalesce reads within each page: only candidate pages, never rescan
        # the heap during normal sampling. An unmapped page invalidates its
        # candidates rather than reading a different address or cached value.
        for page in sorted({a & ~0xfff for a in addresses_to_read}):
            addresses = [a for a in addresses_to_read if a & ~0xfff == page]
            start, end = min(addresses), max(addresses) + 8
            try:
                data = self.read(start, end - start)
            except ValueError:
                for a in addresses:
                    values[str(a)] = None
                continue
            for a in addresses:
                values[str(a)] = int.from_bytes(data[a - start:a - start + 8], 'little')
        hashes = save_hashes(self.run / 'save')
        observation = {'kind': 'sample', 'at': stamp(), 'expected_zone': expected,
                       'values': values, 'save_hashes': hashes,
                       'save_matches_launch': hashes == self.state['baseline_save_hashes']}
        if expected:
            observation['matched_addresses'] = [int(a) for a, v in values.items() if v == ZONES[expected]]
        self.state['observations'].append(observation)
        self.persist()
        report = summarize(self.state)
        write_json(self.run / 'report.json', report)
        print(json.dumps(report, indent=2), flush=True)
        return report


def find_all(data, needle):
    start = 0
    while (at := data.find(needle, start)) >= 0:
        yield at
        start = at + 1


def summarize(state):
    samples = [o for o in state['observations'] if o['kind'] == 'sample']
    labelled = [o for o in samples if o['expected_zone']]
    surviving = set(state['candidates'])
    for observation in labelled:
        surviving.intersection_update(observation['matched_addresses'])
    latest = samples[-1] if samples else None
    seen = {state['scan']['zone']} | {o['expected_zone'] for o in labelled}
    counts = {}
    candidate_label = None
    if latest:
        for value in latest['values'].values():
            label = next((LABELS[z] for z, h in ZONES.items() if h == value), 'unknown/unreadable')
            counts[label] = counts.get(label, 0) + 1
        if len(seen) >= 2 and surviving:
            current_values = {latest['values'].get(str(a)) for a in surviving}
            if len(current_values) == 1:
                value = next(iter(current_values))
                candidate_label = next((LABELS[z] for z, h in ZONES.items() if h == value), None)
    return {'source': 'live-memory-experiment', 'session': state['session'], 'at': stamp(),
            'status': 'unvalidated-candidates', 'current_location': None,
            'candidate_location': candidate_label,
            'initial_candidates': len(state['candidates']), 'consistent_candidates': len(surviving),
            'consistent_addresses': [f'0x{a:x}' for a in sorted(surviving)],
            'latest_candidate_labels': counts, 'manually_labelled_zones': sorted(seen),
            'labelled_samples': len(labelled),
            'committed_save_unchanged_since_launch': latest['save_matches_launch'] if latest else None,
            'note': 'Addresses are session-specific. A match is not an authoritative current location. '
                    'Test an unsaved crossing in both directions, menus, interiors and a new launch.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action', required=True)
    start = sub.add_parser('launch', help='Launch the packaged Mac host with an isolated save copy')
    start.add_argument('--app', type=Path, required=True)
    start.add_argument('--save', type=Path, required=True, help='Committed save folder or main file; only copied')
    start.add_argument('--headless', action='store_true', help='For agent runs; no window')
    start.add_argument('--trace-writer', type=lambda v: int(v, 16), metavar='HEX_ADDRESS',
                       help='Investigative guest address: enable the host page-protection write watch (8 bytes)')
    for name in ('launch', 'scan', 'observe', 'watch', 'resolve'):
        p = start if name == 'launch' else sub.add_parser(name)
        p.add_argument('--run', type=Path, required=True)
        if name in ('scan', 'observe', 'resolve'):
            p.add_argument('--location', choices=ZONES, required=name == 'scan',
                           help='Location independently confirmed on screen by the player')
        if name == 'watch':
            p.add_argument('--source', choices=('candidates', 'roots'), default='candidates',
                           help='roots resolves the build-specific pointer paths without an initial scan')
            p.add_argument('--interval', type=float, default=2)
            p.add_argument('--seconds', type=float, default=60)
    args = parser.parse_args()
    run = args.run.expanduser().resolve()
    if '\n' in str(run) or '\r' in str(run) or len(str(run).encode()) > 800:
        raise ValueError('Run path must fit a single DM_CTL command line')
    if args.action == 'launch':
        state = launch(args.app.expanduser().resolve(), args.save.expanduser().resolve(), run,
                       args.headless, args.trace_writer)
        print('Keep this terminal open. Run scan/observe from another terminal. Ctrl-C stops this host.', flush=True)
        try:
            _, status = os.waitpid(state['pid'], 0)
        except KeyboardInterrupt:
            os.kill(state['pid'], signal.SIGTERM)
            os.waitpid(state['pid'], 0)
            return
        if os.waitstatus_to_exitcode(status):
            raise ValueError('Game host exited with an error; inspect the experiment log.txt')
    else:
        # One reader at a time prevents state updates from racing. A crashed
        # invocation leaves a lock for explicit investigation/removal.
        lock = run / 'probe.lock'
        with lock.open('x'):
            pass
        try:
            probe = Probe(run)
            if args.action == 'scan':
                probe.scan(args.location)
            elif args.action == 'observe':
                probe.observe(args.location)
            elif args.action == 'resolve':
                probe.resolve(args.location)
            else:
                if args.interval < 0.5 or args.seconds <= 0:
                    raise ValueError('Watch interval must be >= 0.5 s and duration > 0')
                deadline = time.monotonic() + args.seconds
                while time.monotonic() < deadline:
                    if args.source == 'roots':
                        probe.resolve()
                    else:
                        probe.observe(tracked_only=True)
                    time.sleep(args.interval)
        finally:
            lock.unlink(missing_ok=True)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, TimeoutError) as error:
        print(f'error: {error}', file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        sys.exit(130)
