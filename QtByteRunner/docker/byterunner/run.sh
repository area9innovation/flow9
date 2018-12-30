#!/bin/bash
set -e

echo "Building Linux QBR in a container"


folder="artifacts"
volume_name="build_qbr_artifact"
dummy_container="qbr_artifact"

rm -rf "$folder"
mkdir -p "$folder"

# This has to be usable from jenkins agents, which run inside docker themselves
# I can not map a folder inside the container into another container, so I create
# named volume instead and use dummy container to copy files out of it.

# cleanup
docker volume rm -f "$volume_name"
docker volume create "$volume_name"

docker run -i --name build_qbr --rm \
  -v "$volume_name:/flow/bin/linux" \
  area9/qt-byte-runner:desktop

# extracting artifacts from the volume
docker create --name "$dummy_container" -v "$volume_name:/artifact" hello-world
docker cp "$dummy_container:/artifact/QtByteRunner" "$folder/QtByteRunner"
docker rm "$dummy_container"
docker volume rm "$volume_name"

