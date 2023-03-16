# Flow9 with VS Code DevContainer

The flow9 repository have a Development Container configuration. This makes it possible to get started using flow9 without installing dependencies. For more info about Development Containers see: https://containers.dev/. The Flow9 Development Container configurations works well with Visual Studio Code. 

## VS Code and Docker

You will need VS Code installed (https://code.visualstudio.com/download). And add the the "Dev Containers" extension: 

	https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers

You will also need to have Docker. Test this with: 

	docker run hello-world

If it is working it should display "Hello from Docker!" and a lot more.

### Linux or WSL (Windows Subsystem for Linux)

Clone the flow9 git repository, it is recommended to use a sub-folder of home. For example "prg"

	cd ~
	mkdir prg
	cd prg
	git clone https://github.com/area9innovation/flow9.git

Start VS Code: 

	cd ~/prg/flow9
	code .

When VS Code starts, it will ask if you if you want to open the DevContainer. Select yes to this. The first time it will need to build the Docker image, this will take between 1 and 10 minutes.

When the DevContainer is active, the lower right corner of VS Code will display a green text "Dev Container: Flow9". 

In the DevContainer you now have an environment with your git checkout and the required java, haxe and haxelib installed. 

If you open a terminal in VS Code you should have a prompt that looks something like this: 

	vscode ➜ /workspaces/flow9 (master) $ 

The workspaces/flow9 folder is the same as your ~/prg/flow9 folder. 

### Windows

For Windows it is recommended to use the Ubuntu WSL on Windows. This is because the Linux filesystem is much faster. But it also works with the Windows file system. Create a sub folder: 

	c:
	cd \
	mkdir prg
	cd prg
	git clone https://github.com/area9innovation/flow9.git

Start VS Code: 

	c:
	cd \prg\flow9
	code .

See the Linux/WSL description for additional details. 

### MAC

TODO

## Verify that the Dev Container is working

In VS Code with the DevContainer open, do the following in a Terminal: 

	cd /workspaces/flow9
	flowc1 jar=sandbox/hello.jar sandbox/hello.flow
	java -jar sandbox/hello.jar

If it is working, it should print: Hello console.

Try the html target with:

	cd /workspaces/flow9
	flowc1 html=sandbox/graph.html sandbox/graph.flow

In the host open the created graph.html file in a browser. In WSL it might be something like: 

	file://wsl.localhost/Ubuntu/home/ub/prg/flow9/sandbox/graph.html

Verify the flow9 Plugin. TODO

## Trouble shooting VS Code image builds. 

If VS Code fails to create the dev-container it might be needed to remove the bad images and container. Do that by listing all the containers and remove the flow9 containers:  

	docker container ls --all
	docker container rm xyz
	docker container rm xyz..

	docker image prune

Where xyz is the id of the vsc-flow9-* containers
