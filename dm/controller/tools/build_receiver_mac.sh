#!/bin/sh
# Build only; the user starts the listener explicitly. Output is a scratch path.
set -eu
if [ "$#" -ne 1 ]; then
    echo 'Usage: build_receiver_mac.sh /scratch/path/receiver-test' >&2
    exit 2
fi
task_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
xcrun clang -fobjc-arc -Wall -Wextra -Wno-unused-parameter -O2 \
    -mmacosx-version-min=14.0 -I"$task_dir/../../apple/controller" \
    "$task_dir/receiver_mac.m" "$task_dir/../../apple/controller/DMControllerSession.m" \
    "$task_dir/../../apple/controller/controller_protocol.c" \
    -framework Foundation -framework Network -framework Security -o "$1"
