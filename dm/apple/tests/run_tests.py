#!/usr/bin/env python3
"""Run Apple save and Shield guide tests. An opening archive replay is opt-in."""
import argparse
import os
import json
import struct
import sys
from pathlib import Path
import subprocess
import tempfile
from shield_guide_catalog import verify_catalog
from shield_guide_fixtures import write_fixtures

here=Path(__file__).resolve().parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--guide-only', action='store_true', help='Skip the unrelated Apple tests.')
parser.add_argument('--guide-ledger', type=Path, help='Write the reviewed compiled guide catalog as JSON.')
parser.add_argument('--mac-guide-ui', action='store_true', help='Exercise the Mac guide menu and window in a desktop session.')
parser.add_argument('--archive-replay', nargs=3, metavar=('PRE_LAB', 'WEDGEHURST', 'ROUTE_2'),
                    help='Optional read-only opening replay. Pass three unpacked Shield main files.')
args=parser.parse_args()
subprocess.run([sys.executable, str(here.parent / 'tools/build_shield_reference.py'), '--check'], check=True)

with tempfile.TemporaryDirectory(prefix='nx-save-tests-') as work:
    root=Path(work); binary=root/'archive-test'
    (root/'game_profile.h').write_text('#define DM_GAME_ID "01008DB008C2C000"\n')
    guide=root/'shield-guide-test'
    compile_guide=['xcrun','clang','-fobjc-arc','-I'+str(root),str(here.parent/'shield_guide.m'),
                   str(here.parent/'shield_guide_save.m'),'-framework','Foundation','-framework','CoreGraphics',
                   '-framework','CoreText']
    subprocess.run([*compile_guide,str(here/'shield_guide_test.m'),'-o',str(guide)],check=True)
    fixtures=root/'shield-fixtures'
    write_fixtures(fixtures)
    subprocess.run([str(guide),'--synthetic',str(fixtures)],check=True)
    catalog=root/'guide-catalog.json'
    subprocess.run([str(guide),'--catalog',str(catalog)],check=True)
    verify_catalog(catalog, args.guide_ledger)
    # A second compile exercises the production title gate, not just a bad build string.
    other=root/'other-profile'; other.mkdir()
    (other/'game_profile.h').write_text('#define DM_GAME_ID "0100ABF008968000"\n')
    isolated=root/'shield-guide-profile-test'
    subprocess.run([*compile_guide[:3], '-I'+str(other), *compile_guide[4:],
                    str(here/'shield_guide_profile_test.m'), '-framework','Cocoa','-o',str(isolated)],check=True)
    subprocess.run([str(isolated)],check=True)
    if args.archive_replay:
        subprocess.run([str(guide), *args.archive_replay], check=True)
    if args.mac_guide_ui:
        mac=root/'shield-guide-mac-test'
        subprocess.run([*compile_guide,str(here/'shield_guide_mac_test.m'),'-framework','Cocoa','-o',str(mac)],check=True)
        subprocess.run([str(mac),str(fixtures)],check=True)
    if args.guide_only:
        sys.exit(0)
    subprocess.run(['xcrun','clang','-fobjc-arc','-Wno-deprecated-declarations','-DDM_SYNC_TESTING',str(here/'archive_test.m'),str(here.parent/'save_archive.m'),'-framework','Foundation','-lz','-o',str(binary)],check=True)
    queue=root/'queue-test'
    subprocess.run(['xcrun','clang','-fobjc-arc','-Wno-deprecated-declarations','-I'+str(root),str(here/'queue_test.m'),str(here.parent/'save_archive.m'),'-framework','Cocoa','-framework','Security','-lz','-o',str(queue)],check=True)
    subprocess.run([str(queue),str(root/'queue-test-data')],check=True)
    experience=root/'experience-test'
    subprocess.run(['xcrun','clang','-fobjc-arc','-Wno-deprecated-declarations','-I'+str(root),str(here/'experience_test.m'),str(here.parent/'save_archive.m'),'-framework','Cocoa','-framework','Security','-lz','-o',str(experience)],check=True)
    subprocess.run([str(experience),str(root/'experience-data')],check=True)
    landing=root/'landing-test'
    subprocess.run(['xcrun','clang','-fobjc-arc','-Wno-deprecated-declarations','-I'+str(root),str(here/'landing_test.m'),str(here.parent/'save_archive.m'),'-framework','Cocoa','-framework','Security','-lz','-o',str(landing)],check=True)
    subprocess.run([str(landing),str(root/'landing-data')],check=True)
    controls=root/'control-test'
    subprocess.run(['xcrun','clang',str(here.parent.parent/'ios/tests/control_math_test.c'),'-o',str(controls)],check=True)
    subprocess.run([str(controls)],check=True)
    normal=root/'normal'; normal.mkdir()
    subprocess.run([str(binary),'normal',str(normal)],check=True)
    deleted=root/'deleted'; deleted.mkdir(); subprocess.run([str(binary),'delete-device',str(deleted)],check=True)
    for point in ('journal','account','device','installed','metadata'):
        dest=root/point; dest.mkdir()
        result=subprocess.run([str(binary),'normal',str(dest)],env={**os.environ,'DM_SYNC_CRASH_AT':point})
        assert result.returncode==88,(point,result.returncode)
        subprocess.run([str(binary),'recover',str(dest)],check=True)
        subprocess.run([str(binary),'recover',str(dest)],check=True)
    archive=normal/'snapshot.nxsave'; original=archive.read_bytes()
    service=here.parents[3]/'cloud-save-service'
    if service.is_dir():
        sys.path.insert(0,str(service))
        from cloudsave.archive import validate
        validate(archive)
        print('PASS: Apple-produced archive accepted by Python service validator')
    n=struct.unpack('>I',original[8:12])[0]; manifest=json.loads(original[12:12+n]); payload=original[12+n:]
    for mutation in ('unsafe','duplicate','root','type','hash','boolean-size'):
        m=json.loads(json.dumps(manifest))
        entry=next(e for e in m['entries'] if e['type']=='file')
        if mutation=='unsafe': entry['path']='../escape'
        elif mutation=='duplicate': m['entries'].append(entry.copy())
        elif mutation=='root': del m['roots']['device']
        elif mutation=='type': entry['type']='symlink'
        elif mutation=='hash': entry['sha256']='0'*64
        elif mutation=='boolean-size': entry['size']=True
        raw=json.dumps(m).encode(); archive.write_bytes(b'NXSV0001'+struct.pack('>I',len(raw))+raw+payload)
        assert subprocess.run([str(binary),'validate',str(normal)]).returncode==2,mutation
    archive.write_bytes(original[:-2]); assert subprocess.run([str(binary),'validate',str(normal)]).returncode==2
    archive.write_bytes(original+b'trailing'); assert subprocess.run([str(binary),'validate',str(normal)]).returncode==2
print('PASS: durable queue ordering/deduplication/pressure, metadata/empty directories/two roots, five restore crash points, repeated recovery, truncation and trailing bytes')
