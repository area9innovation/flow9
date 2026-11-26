#!/bin/bash

# Builds QtByteRunner from the flow9 checkout this script lives in, inside the
# runner-build image, into QtByteRunner-build-release/ at the root of the
# checkout. bin/flowcpp picks that directory up before the committed binary.
#
#   ./build.sh                    build
#   ./build.sh CONFIG+=debug      extra arguments go to qmake
#   ./build.sh --shell            a shell in the container instead
#
# Works with docker and with podman's docker shim.

set -e

IMAGE=flow9-runner-build
SCRIPT_DIR=$( cd "$( dirname "$0" )" && pwd -P )
FLOW_DIR=$( cd "$SCRIPT_DIR/../../../.." && pwd -P )

if [ ! -f "$FLOW_DIR/platforms/common/cpp/asmjit/src/asmjit/asmjit.h" ]; then
    echo "The asmjit submodule is missing. Run this in $FLOW_DIR first:" >&2
    echo "  git submodule update --init platforms/common/cpp/asmjit" >&2
    exit 1
fi

docker build -t "$IMAGE" "$SCRIPT_DIR"

# Run as the calling user so the output is not owned by root. Rootless podman
# maps the host user to root in the container, so a plain --user would land on
# a subordinate uid that cannot write the mount; keep-id maps it through.
USER_ARGS=(--user "$(id -u):$(id -g)")
if docker --version 2>/dev/null | grep -qi podman; then
    USER_ARGS+=(--userns=keep-id)
fi

# :z relabels the mount for SELinux hosts and is ignored elsewhere.
RUN_ARGS=(--rm "${USER_ARGS[@]}" -v "$FLOW_DIR:/flow:z")

if [ "$1" = "--shell" ]; then
    exec docker run -it "${RUN_ARGS[@]}" "$IMAGE" bash
fi

# The same steps as the out-of-source build in doc/linux.markdown.
# make does not rebuild objects when only the flags change, so the build
# directory is emptied whenever the qmake arguments or the Qt differ from the
# last build here, including a build made on the host, which leaves no stamp.
docker run "${RUN_ARGS[@]}" "$IMAGE" bash -c '
    set -e
    (cd platforms/common/cpp/gl-gui/shaders && ./pack.pl)
    mkdir -p QtByteRunner-build-release && cd QtByteRunner-build-release
    stamp="Qt $(qmake6 -query QT_VERSION) $*"
    if [ -n "$(ls -A)" ] && [ "$(cat .runner-build 2>/dev/null)" != "$stamp" ]; then
        echo "Previous build used different settings, starting clean"
        find . -mindepth 1 -delete
    fi
    qmake6 -r -spec linux-g++ CONFIG+=release "$@" ../platforms/qt/QtByteRunner.pro
    echo "$stamp" > .runner-build
    make -j$(nproc)
' build "$@"

echo
echo "Built $FLOW_DIR/QtByteRunner-build-release/QtByteRunner"
echo "bin/flowcpp uses it before the committed runner; delete the folder to go back."
