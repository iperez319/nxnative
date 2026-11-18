#!/usr/bin/env python3
"""Build unsigned controller/test-receiver IPAs without a game profile or assets.

Usage: python3 scripts/build_controller.py --output /path/to/new/scratch-folder
Requires Xcode with the iPhoneOS SDK and XcodeGen. Never signs or installs.
"""
import argparse
from pathlib import Path
import plistlib
import shutil
import subprocess
import zipfile

REPO = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path, help='new scratch directory')
    parser.add_argument('--only', choices=('controller', 'receiver', 'both'), default='both')
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True)  # Refuse to replace an existing build.
    dm = output / 'source/dm'
    project = dm / 'controller'
    project.mkdir(parents=True)
    (dm / 'ios').mkdir()
    (dm / 'apple').mkdir()
    for source, target in (
        (REPO / 'dm/controller/Sources', project / 'Sources'),
        (REPO / 'dm/ios/Sources', dm / 'ios/Sources'),
        (REPO / 'dm/apple/controller', dm / 'apple/controller'),
        (REPO / 'dm/host', dm / 'host'),
    ):
        target.symlink_to(source, target_is_directory=True)
    shutil.copyfile(REPO / 'dm/controller/project.yml', project / 'project.yml')
    subprocess.run(['xcodegen', 'generate'], cwd=project, check=True)
    targets = {'controller': ['NxController'], 'receiver': ['NxControllerReceiver'],
               'both': ['NxController', 'NxControllerReceiver']}[args.only]
    derived = output / 'derived'
    for target in targets:
        subprocess.run([
            'xcodebuild', '-project', str(project / 'NxController.xcodeproj'),
            '-scheme', target, '-configuration', 'Release',
            '-destination', 'generic/platform=iOS', '-derivedDataPath', str(derived),
            '-jobs', '3', 'CODE_SIGNING_ALLOWED=NO', 'CODE_SIGNING_REQUIRED=NO',
            'CODE_SIGN_IDENTITY=', 'build',
        ], check=True)
        app = derived / f'Build/Products/Release-iphoneos/{target}.app'
        info = plistlib.loads((app / 'Info.plist').read_bytes())
        if not (app / info['CFBundleExecutable']).is_file():
            raise RuntimeError(f'Missing executable: {app}')
        if (app / '_CodeSignature').exists() or (app / 'embedded.mobileprovision').exists():
            raise RuntimeError('Expected an unsigned app')
        ipa = output / f'{target}.ipa'
        with zipfile.ZipFile(ipa, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
            for path in sorted(app.rglob('*')):
                if path.is_file():
                    archive.write(path, Path('Payload') / app.name / path.relative_to(app))
        print(f'Unsigned IPA: {ipa}', flush=True)
    print(f'Xcode project: {project / "NxController.xcodeproj"}', flush=True)


if __name__ == '__main__':
    main()
