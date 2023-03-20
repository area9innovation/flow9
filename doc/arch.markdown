# Manjaro/Endeavour

## Git
Git-lfs is needed to use flow9. So make sure, that you install it

	git clone <flow9-repo> 
	sudo pacman -S git-lfs
	git lfs install
	git pull lfs

## Adding to path
	- open environment variables;
		code ~/.bash_profile
	- Add code to file:
		export FLOW=$HOME/area9/flow9
		export PATH=$FLOW/bin:$PATH
	- Close file and update environment variables:
		source ~/.bash_profile

## Install neko/haxe
	-Install neko and haxe:
		pacman -S neko haxe
	- Setup base haxelib repository:
		cd ~
		mkdir -p ~/haxelib/lib
		haxelib setup ~/haxelib/lib
	- Install needed libraries
		haxelib install format 3.4.2
		haxelib install pixijs 4.8.4
		haxelib install threejs

## Build Byterunner for flowcpp
		pacman -S qt5-base qt5-websockets qt5-webengine
		cd $FLOW/platforms/common/cpp
		git clone https://github.com/area9innovation/asmjit
		cd asmjit
		git checkout next
		cd $FLOW/platforms/qt
		./build.sh 
