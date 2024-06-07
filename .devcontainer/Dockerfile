
# See:
# https://github.com/devcontainers/images/tree/main/src/base-ubuntu
# https://containers.dev/guide/dockerfile

FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

# Install add-apt-repository and git-lfs
RUN apt-get update && apt-get install -y \
	software-properties-common \
	git-lfs

# Add java
RUN apt-get install -y \
	default-jdk \
	maven

# Add support for QT and flowcpp
RUN apt-get install -y \
	libqt5webenginewidgets5 \
	libqt5multimedia5 \
	libqt5websockets5 \
	libqt5sql5-mysql \
	libglu1-mesa

# Add applications for testing the GUI setup (For example xeyes)
RUN apt-get install -y x11-apps

# Configure some haxe paths in the share folder.
ENV HAXEPATH=/usr/share/haxe
ENV HAXE_STD_PATH=$HAXEPATH/std
ENV HAXELIB_PATH=$HAXEPATH/lib

# Add haxe repository (need the 'software-properties-common' package), and install haxe
RUN add-apt-repository ppa:haxe/releases -y \
	&& apt-get update \
	&& apt-get install -y haxe

# Installing haxelib in a share folder
RUN haxelib setup $HAXELIB_PATH \
	&& haxelib install format 3.4.2 \
	&& haxelib install pixijs 4.8.4 \
	&& haxelib install threejs 91.0.1

RUN echo "\necho \"Welcome to Flow9 DevContainer. See the doc/devcontainer.md for more information.\"" >> /home/vscode/.bashrc
