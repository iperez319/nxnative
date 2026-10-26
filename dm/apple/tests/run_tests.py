#!/usr/bin/env python3
"""Synthetic snapshots only; no player data or game assets."""
import os
import json
import struct
import sys
from pathlib import Path
import subprocess
import tempfile

here=Path(__file__).resolve().parent
with tempfile.TemporaryDirectory(prefix='nx-save-tests-') as work:
    root=Path(work); binary=root/'archive-test'
    subprocess.run(['xcrun','clang','-fobjc-arc','-Wno-deprecated-declarations','-DDM_SYNC_TESTING',str(here/'archive_test.m'),str(here.parent/'save_archive.m'),'-framework','Foundation','-lz','-o',str(binary)],check=True)
    (root/'game_profile.h').write_text('#define DM_GAME_ID "01008DB008C2C000"\n')
    queue=root/'queue-test'
    subprocess.run(['xcrun','clang','-fobjc-arc','-Wno-deprecated-declarations','-I'+str(root),str(here/'queue_test.m'),str(here.parent/'save_archive.m'),'-framework','Cocoa','-framework','Security','-lz','-o',str(queue)],check=True)
    subprocess.run([str(queue),str(root/'queue-test-data')],check=True)
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
