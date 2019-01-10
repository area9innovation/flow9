Here's a bunch of docker images that could be useful for QT byte runner.

Requires docker >= 17.05.
Installation of docker is out of scope; there's a good guide at the docker website which is updated somewhat regularly.

# QT

Use this to create base QT images. Current QT version is 5.9.2.
Try using ARGs in shell scripts and Dockerfiles for minor version upgrades. Anything besides that will most likely require trial and error approach for figuring out required libs.

QT likes to tweak the installation process between versions and for example upgrade from 5.7 required some modifications.

First, build install image with ./build_install.sh because it's the biggest and just
downloads QT and installs it into /opt/ folder.

Then build full and trimmed versions with ./build.sh. They use the install image as a base. Full build takes care of mysql drivers too.

Trimmed is a volume only image that is useful to copy qt from in staged builds.

Special MySQL driver is required for 2 reasons:
1. The one included with QT installation is built against old mysqlclientlib which is not provided with it.
2. Using latest mysqlclientlib results in a bug. Consecutive database connections cause a segfault in the CGI byte runner.

# flowcpp

The flowcpp image can be used to run byte runner cron jobs. It does not have flow inside. Binding required folders is up to you.

run.sh can be used to run a bytecode file. An absolute path to it is the only argument. For example

`./run.sh /home/flow9/helloworld.bytecode`

--batch argument is baked in, GUI apps will crash.

# cgibyterunner

The cgibyterunner image allows to build linux version of cgi byte runner. Gets QT from qt images.

Byte runner built this way is eventually used by base app container.

# byterunner

The byterunner image allows to build the Linux version of regular byte runner. Again, gets QT from qt images. Uses path to flow stored in $FLOW environment variable. Thus it is up to you to checkout flow and define an export.

You can also get a list of libraries which are required to run byte runner locally on your machine from a Dockerfile.template in this folder.

Byte runner built this way is eventually used by jenkins agents.

# gui

Experimental way of running flowcpp without QT on Ubuntu. Read the Dockerfile
before using.

