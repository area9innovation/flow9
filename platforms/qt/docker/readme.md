Here's a bunch of docker images that could be useful for QT byte runner.

The are not available in public registries and are meant to be built locally
when needed.

Installation of docker is out of scope; there's a good guide at the docker website
which is updated regularly.

# QT

Use this to create base QT images. Current QT version is 5.12.11.
The version is hardcoded throught the scripts. The updates are rare and often
too much is changing between them anyway.

The points below need verification:
Special MySQL driver is required for 2 reasons:
1. The one included with QT installation is built against old mysqlclientlib which 
is not provided with it.
2. Using latest mysqlclientlib results in a bug. Consecutive database connections
cause a segfault in the CGI byte runner.

# byterunner

This folder is useful to build QtByteRunner and its cgi version. Corresponding
scripts are a good place to start. Dockerfile supposedly has all the
dependencies.

# flowcpp

The flowcpp image can be used to run byte runner without installing required lib.
It does not have flow inside. Binding required folders is up to you.

run.sh can be used to run a bytecode file. An absolute path to it is the only 
argument. For example

`./run.sh /home/flow9/helloworld.bytecode`

--batch argument is baked in, GUI apps will crash.

