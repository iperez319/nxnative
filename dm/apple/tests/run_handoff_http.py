#!/usr/bin/env python3
"""Run production head checks against the local Postman save-handoff simulation."""
import subprocess
import sys
import tempfile
from pathlib import Path
from urllib.parse import urlparse

if len(sys.argv) != 2:
    raise SystemExit('Usage: run_handoff_http.py http://localhost:PORT/saves')
url = urlparse(sys.argv[1])
if url.scheme != 'http' or url.hostname not in ('localhost', '127.0.0.1'):
    raise SystemExit('This synthetic harness only accepts a local HTTP simulation')
here = Path(__file__).resolve().parent
with tempfile.TemporaryDirectory(prefix='nx-handoff-http-') as work:
    root = Path(work)
    (root / 'game_profile.h').write_text('#define DM_GAME_ID "01008DB008C2C000"\n')
    binary = root / 'handoff-test'
    subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-Wno-deprecated-declarations',
                    '-I' + str(root), str(here / 'handoff_http_test.m'),
                    str(here.parent / 'save_archive.m'), '-framework', 'Cocoa',
                    '-framework', 'Security', '-lz', '-o', str(binary)], check=True)
    subprocess.run([str(binary), sys.argv[1]], check=True)
