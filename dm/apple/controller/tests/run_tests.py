#!/usr/bin/env python3
"""Synthetic protocol tests and encrypted localhost transport tests; no devices."""
from pathlib import Path
import subprocess
import tempfile


def main():
    here = Path(__file__).resolve().parent
    shared = here.parent
    with tempfile.TemporaryDirectory(prefix='nx-controller-tests-') as temp:
        root = Path(temp)
        protocol = root / 'protocol-test'
        subprocess.run(['xcrun', 'clang', '-std=c11', '-Wall', '-Wextra', '-Werror',
                        '-fsanitize=address,undefined', str(here / 'protocol_test.c'),
                        str(shared / 'controller_protocol.c'), '-o', str(protocol)], check=True)
        subprocess.run([str(protocol)], check=True)
        pairing = root / 'pairing-test'
        subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-Wall', '-Wextra', '-Werror',
                        str(here / 'pairing_test.m'), str(shared / 'DMControllerPairing.m'),
                        '-framework', 'Foundation', '-framework', 'CoreImage',
                        '-framework', 'CoreGraphics', '-o', str(pairing)], check=True)
        subprocess.run([str(pairing)], check=True)
        loopback = root / 'loopback-test'
        subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-Wall', '-Wextra',
                        '-Wno-unused-parameter', str(here / 'loopback_test.m'),
                        str(shared / 'controller_protocol.c'), '-framework', 'Foundation',
                        '-framework', 'Network', '-framework', 'Security', '-o', str(loopback)], check=True)
        for mode in ('normal', 'wrong-key', 'silent', 'no-ack', 'waiting', 'browser-waiting', 'handoff', 'handoff-wrong-key', 'stall-diagnostic'):
            subprocess.run([str(loopback), mode], check=True, timeout=10)
        bonjour = root / 'bonjour-test'
        subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-Wall', '-Wextra',
                        '-Wno-unused-parameter', str(here / 'bonjour_test.m'),
                        str(shared / 'DMControllerSession.m'), str(shared / 'controller_protocol.c'),
                        '-framework', 'Foundation', '-framework', 'Network', '-framework', 'Security',
                        '-o', str(bonjour)], check=True)
        subprocess.run([str(bonjour)], check=True, timeout=12)
        bridge = root / 'bluetooth-bridge-test'
        subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-Wall', '-Wextra',
                        '-Wno-unused-parameter', str(here / 'bluetooth_bridge_test.m'),
                        str(shared / 'DMControllerSession.m'), str(shared / 'controller_protocol.c'),
                        '-framework', 'Foundation', '-framework', 'CoreBluetooth',
                        '-framework', 'Network', '-framework', 'Security', '-o', str(bridge)], check=True)
        for mode in ('normal', 'wrong-key'):
            subprocess.run([str(bridge), mode], check=True, timeout=10)


if __name__ == '__main__':
    main()
