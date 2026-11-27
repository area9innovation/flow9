# See:
# https://github.com/devcontainers/images/tree/main/src/base-ubuntu
# https://containers.dev/guide/dockerfile
#
# Ubuntu 24.04 is what gives us Qt 6 from the distribution repositories,
# including qt6-webengine-dev, which is not packaged for 22.04.

FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Toolchain, git-lfs and the JDK that flowc needs. flowc.jar is compiled to
# class file version 65, so the JDK must be 21 or newer.
RUN apt-get update && apt-get install -y \
	build-essential \
	perl \
	python3 \
	git-lfs \
	rlwrap \
	openjdk-21-jdk \
	maven

# Qt 6 and the image/font libraries, so the container can build QtByteRunner.
# These mirror the package list in bin/setup-linux - keep the two in step.
RUN apt-get install -y \
	qt6-base-dev \
	qt6-base-dev-tools \
	qt6-declarative-dev \
	qt6-multimedia-dev \
	qt6-webchannel-dev \
	qt6-websockets-dev \
	qt6-webengine-dev \
	qt6-positioning-dev \
	libqt6sql6-mysql \
	libgl-dev \
	libglu1-mesa-dev \
	zlib1g-dev \
	libjpeg-dev \
	libpng-dev \
	libfreetype-dev

# Add applications for testing the GUI setup (For example xeyes)
RUN apt-get install -y x11-apps

# Haxe compiles the JavaScript targets of flowc and the first generation
# compiler (bin/flow.n); haxelib needs Neko. Ubuntu 24.04 packages both, so no
# PPA is required.
RUN apt-get install -y haxe neko

# Configure some haxe paths in the share folder.
ENV HAXEPATH=/usr/share/haxe
ENV HAXE_STD_PATH=$HAXEPATH/std
ENV HAXELIB_PATH=$HAXEPATH/lib

# Installing haxelib in a share folder. The libraries and versions are those in
# mise-shared-tasks/haxelib.txt - keep the two in step. The file itself is out
# of reach here: the build context is the .devcontainer folder.
RUN haxelib setup $HAXELIB_PATH \
	&& haxelib install pixijs 4.8.4 \
	&& haxelib install threejs 91.0.1 \
	&& haxelib install hxnodejs 12.2.0 \
	&& haxelib install node-express 0.0.5 \
	&& haxelib install format 3.4.2

RUN echo "\necho \"Welcome to Flow9 DevContainer. See the doc/devcontainer.md for more information.\"" >> /home/vscode/.bashrc
