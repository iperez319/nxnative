#!/usr/bin/env python3
"""Run the production Shield guide on an iPhone or iPad simulator using original generated saves."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
sys.path.insert(0, str(REPO / 'dm/apple/tests'))
from shield_guide_fixtures import write_fixtures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True, help='new scratch directory')
    parser.add_argument('--device', required=True, help='simulator UUID')
    parser.add_argument('--only', action='append', default=[], help='run a named GuideUITests method (repeatable)')
    args = parser.parse_args()
    root = args.output.resolve()
    root.mkdir(parents=True)
    for name, source in [('Sources', HERE / 'Sources'), ('UITests', HERE / 'UITests'),
                         ('Production', REPO / 'dm/ios/Sources'), ('Apple', REPO / 'dm/apple'),
                         ('games', REPO / 'dm/games')]:
        (root / name).symlink_to(source, target_is_directory=True)
    shutil.copyfile(HERE / 'project.yml', root / 'project.yml')
    write_fixtures(root / 'Fixtures')
    env = dict(os.environ, DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer')
    subprocess.run(['xcodegen', 'generate'], cwd=root, env=env, check=True)
    subprocess.run(['xcodebuild', '-project', str(root / 'ShieldGuideHarness.xcodeproj'),
                    '-scheme', 'ShieldGuideHarness', '-destination', f'platform=iOS Simulator,id={args.device}',
                    '-derivedDataPath', str(root / 'derived'), '-resultBundlePath', str(root / 'results.xcresult'),
                    '-parallel-testing-enabled', 'NO', '-jobs', '3',
                    *[f'-only-testing:ShieldGuideUITests/GuideUITests/{name}' for name in args.only], 'test'], cwd=root, env=env, check=True)


if __name__ == '__main__':
    main()
