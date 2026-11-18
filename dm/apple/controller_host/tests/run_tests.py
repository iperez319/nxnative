#!/usr/bin/env python3
"""Encrypted localhost receiver-to-game input integration; no games or radios."""
from pathlib import Path
import subprocess
import tempfile


def main():
    repo = Path(__file__).resolve().parents[4]
    with tempfile.TemporaryDirectory(prefix='nx-host-input-') as temp:
        out = Path(temp)
        profile = out / 'game_profile.h'
        subprocess.run(['python3', str(repo / 'dm/games/game.py'), 'header',
                        '01008DB008C2C000', str(profile)], check=True)
        stubs = out / 'hid.o'
        flags = ['xcrun', 'clang', '-O1', '-g', '-Wall', '-Werror',
                 '-Wno-unused-function', '-Wno-unused-parameter',
                 '-fsanitize=address,undefined', '-I', str(out),
                 '-I', str(repo / 'dm/host'), '-I', str(repo / 'dm/apple/controller')]
        subprocess.run([*flags, '-c', str(Path(__file__).with_name('hid_fixture.c')),
                        '-o', str(stubs)], check=True)
        binary = out / 'host-input-test'
        subprocess.run([*flags, '-fobjc-arc', str(Path(__file__).with_name('host_input_test.m')),
                        str(repo / 'dm/apple/controller_host/DMControllerHost.m'),
                        str(repo / 'dm/apple/controller/DMControllerSession.m'),
                        str(repo / 'dm/apple/controller/DMControllerPairing.m'),
                        str(repo / 'dm/apple/controller/DMControllerBluetooth.m'),
                        str(repo / 'dm/apple/controller/controller_protocol.c'),
                        str(repo / 'dm/host/hle_haptics.c'), str(stubs),
                        '-framework', 'Foundation', '-framework', 'Network',
                        '-framework', 'Security', '-framework', 'CoreBluetooth',
                        '-o', str(binary)], check=True)
        for mode in ('normal', 'wrong-key'):
            subprocess.run([str(binary), mode], check=True, timeout=10)


if __name__ == '__main__':
    main()
