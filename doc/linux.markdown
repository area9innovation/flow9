Flow: getting started (on Linux)
================================

Much of the information in this getting-started is created for Ubuntu 18.04/20.04,
so some of the operations may be different for your Operating System of
choice.

# Installation steps
1.  [Environment configuration](#environment-configuration)
2.  [Backend](#backend)
    - [MySQL](#mysql)
    - [PHP7.2](#php7.2)
    - [Apache2](#apache2)
3.  [Clone the repositories](#clone-the-repositories)
4.  [Install `Haxe`](#install-haxe)
5.  [Install `Neko`](#install-neko)
6.  [Install `JDK`](#install-jdk)
7.  [Compile Flow itself(Optional)](#compile-flow-itselfoptional)
8.  [Check it using flowcpp (C++ runner)](#c-runner-flowcpp)
9.  [Install fdb, the Flow debugger](#fdb-the-flow-debugger)
10. [Check it using flowjs (Javascript in browser)](#try-it-javascript-in-browser)
11. [Try it (Executed via apache, in browser)](#try-it-executed-via-apache-in-browser)
12. [Tools](#tools)
13. [Profiling](#profiling)
# Environment configuration
All environment variables should be defined in `~/.profile`. This is
necessary since applications that are started from an application menu
(i.e., not started from the command line; e.g., emacs) will not see
environment variables defined in other files, such as `~/.bashrc`. In
some terminals, though, `~/.profile` is not considered during startup,
so as a compromise you can store variables in some file, which is
`source`'d in both `~/.profile` and `~/.bashrc`
```bash
touch ~/.env
echo "source ~/.env" | tee -a ~/.bashrc ~/.profile
```
Also it can be useful to define environment variables in .xsessionrc. This way they will be
[enabled for any X session](https://askubuntu.com/questions/82120/how-do-i-set-an-environment-variable-in-a-unity-session)

# Backend
## MySQL
Set up MySQL and MySQL Workbench:
> https://dev.mysql.com/downloads/repo/apt/
```bash
sudo dpkg -i mysql-apt-config_0.8.16-1_all.deb
sudo apt update
sudo apt install -y mysql-server mysql-client
```
Make root@localhost user with empty password:
```bash
sudo mysql --user="root" --execute="ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY ''; FLUSH PRIVILEGES;"
```
Configure MySQL-server mode:
```bash
printf '[mysqld]
sql-mode=STRICT_ALL_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER\n' | sudo tee -a /etc/mysql/my.cnf
```
More details on mysql setup can be found in [innovation/doc/mysql.markdown](https://github.com/area9innovation/innovation/blob/master/doc/mysql.markdown)

## PHP7.2
Set up PHP:
```bash
sudo add-apt-repository ppa:ondrej/php
sudo apt update
sudo apt install -y php7.2 php7.2-mysql php-gettext php7.2-mbstring php-xdebug libapache2-mod-php7.2 php7.2-xml php7.2-zip php7.2-mcrypt
sudo update-alternatives --config php
```

when switching from older php version:
```bash
sudo a2dismod php5.6
sudo a2enmod php7.2
sudo service apache2 restart
```

also copying libraries config from php5.6 might be required
```bash
sudo cp /etc/php/5.6/apache2/conf.d/* /etc/php/7.2/apache2/conf.d
```

if php7.2 is not available, 7.0 version/libs work too.


## Apache2
Install and configure apache2:
```bash
sudo apt install apache2
printf 'Alias "/todoapp" "/home/'$USER'/area9/todoapp/www2/"
<Directory /home/'$USER'/area9/todoapp/www2/>
     AllowOverride All
     Require local
</Directory>\n' | sudo tee /etc/apache2/conf-available/area9.conf
sudo a2enconf area9
sudo service apache2 restart
```
Note that todoapp is name for application in exercise 9, you can rename it as you wish.
# Clone the repositories
If you haven't installed git yet, enter next commands:
```bash
sudo apt install -y git
git config --global user.email "<email for github account>"
git config --global user.name "<your full name>"
git config --global alias.hist "log --pretty=format:'%h %ad | %s%d [%an]' --graph --date=format:'%Y-%m-%d %H:%M:%S'"
git config --global push.default simple
git config --global pull.rebase true
```
In order not to enter authentication data each time, follow the instructions described in [Connecting to GitHub with SSH](https://help.github.com/articles/connecting-to-github-with-ssh/).

Make area9 dir:
```bash
mkdir -p ~/area9 && cd ~/area9
```
Clone flow9 repos:
```bash
git clone ssh://git@github.com/area9innovation/flow9.git
```

Notice, that flow9 repo requires installed [Git LFS](https://git-lfs.github.com).
You have to reclone the flow9 repository after installing Git LFS, or use
```bash
git lfs pull
```
# Install `Haxe`
Our build servers use haxe 4.2.5 and neko 2.3.0.

A Linux installer is available here: [Haxe download
site](https://haxe.org/download/)

**Note** If you choose to use Linux package installer for Ubuntu, you
may encounter following problem:
`add-apt-repository: command not found`.\
In such case, run following command:
`sudo apt-get update && sudo apt-get install software-properties-common`

After running the installer, run this:
```bash
printf 'export HAXE_STD_PATH=/usr/share/haxe/std
export FLOW=$HOME/area9/flow9
export PATH=$FLOW/bin:$PATH\n' >> ~/.env
```
and run `source ~/.env`.

If you have followed the installation instructions for Linux Package
installer, you have already set up Haxe library directory, so you don’t
have to do the next step.

Set up your Haxe library directory:
```bash
cd ~
mkdir -p ~/haxelib/lib
haxelib setup ~/haxelib/lib
```
Then install the required libraries:
```bash
haxelib install format 3.4.2
haxelib install pixijs 4.8.4 #(pixijs version 5 isn't supported)
```
# Install `Neko`
Our build servers use haxe 4.2.5 and neko 2.3.0. Newer versions might
work as well, but it is not guaranteed.

**If the haxe installer above did not install Neko** or installed a wrong
version, you can do it manually either by downloading it from the
official site

The [Neko download site](http://nekovm.org/download) offers both
32-bit and 64-bit binaries.  Make sure your haxe and neko match. Most
use the 32-bit version.

or via package manager like this:
```bash
sudo apt-get install neko
```
**Run this:**
```bash
printf 'export NEKOPATH=/usr/lib/x86_64-linux-gnu/neko
export PATH=$NEKOPATH:$PATH\n' >> ~/.env
```
and run `source ~/.env`.

**NOTE:** if you have error “Uncaught exception - load.c(237) : Failed
to load library : std.ndll (dlopen(std.ndll, 1): image not found)” check
your real neko path and put it in NEKOPATH, it can be
/usr/local/lib/neko or another path.

Alexander Gavrilov offers:

> there are two possible problems I remember with neko:
>
> 1.  neko executables work by including a small executable with the
>     bytecode, and its 32-bitness must agree with
>     [libneko.so](http://libneko.so)
> 2.  some distributions include weird ‘optimization’ things that strip
>     all executables they see that they aren’t told to ignore, and that
>     kills the bytecode specifically, point 2 is true for Fedora, and
>     the weird thing is called prelink. the nekovm rpm included with
>     the system installs a config into /etc/prelink.conf.d to stop that

LD\_LIBRARY\_PATH (Ubuntu)
--------------------------

The `LD_LIBRARY_PATH` environment variable must include the path to
Neko. This is not done by explicitly setting this variable but by adding
an application-specific file to the `/etc/ld.so.conf.d` directory like
so:

Create the file `/etc/ld.so.conf.d/flow.conf` and add to it the path
    to Neko (/usr/bin/neko in Ubuntu). You can do this with:
```bash
echo '/usr/bin/neko' | sudo tee -a /etc/ld.so.conf.d/flow.conf
```
Run
```bash
sudo ldconfig
```
If you get the following messages
```
 /sbin/ldconfig.real: /usr/lib/nvidia-375/libEGL.so.1 is not a symbolic link
 /sbin/ldconfig.real: /usr/lib32/nvidia-375/libEGL.so.1 is not a symbolic link
```
then the following solution works
```bash
sudo mv /usr/lib/nvidia-375/libEGL.so.1 /usr/lib/nvidia-375/libEGL.so.1.org
sudo mv /usr/lib32/nvidia-375/libEGL.so.1 /usr/lib32/nvidia-375/libEGL.so.1.org
sudo ln -s /usr/lib/nvidia-375/libEGL.so.1 /usr/lib/nvidia-375/libEGL.so.375.39
sudo ln -s /usr/lib32/nvidia-375/libEGL.so.1 /usr/lib32/nvidia-375/libEGL.so.375.39
```
Note that `LD_LIBRARY_PATH` will not actually contain the path to Neko,
but the system can now find libraries on that path nonetheless.
# Compile Flow itself(Optional)
Neko version of flow from the repo should be fine but if you wish to compile your own, do:
```bash
cd ~/area9/flow9/tools/flow
haxe FlowNeko.hxml
```
This should take a few seconds. If it takes more than a minute, very likely something is going wrong.
The following file will be created or overwritten:
```
flow9/bin/flow.n
```

# Install `JDK`
Be sure that you have installed JDK 11 or newer in a 64-bit version. That is required by the *flowc* compiler, which is used
by default. You may find it here:

	https://www.oracle.com/java/technologies/javase-jdk11-downloads.html

OpenJDK is suitable as well.

# C++ runner (flowcpp)
Under linux it’s easier to compile yourself a binary instead of using
the precompiled one. To do so, you should have Qt 5.12.0 set up by default
Install required libraries:
```bash
sudo apt-get install zlib1g-dev libjpeg-dev libpng-dev -y
wget -q -O /tmp/libpng12.deb http://mirrors.kernel.org/ubuntu/pool/main/libp/libpng/libpng12-0_1.2.54-1ubuntu1_amd64.deb \
  && sudo dpkg -i /tmp/libpng12.deb \
  && rm /tmp/libpng12.deb
```
With Ubuntu 20.04, follow the instruction [here](https://askubuntu.com/questions/1136302/can-not-install-libpng12-so-0-on-ubuntu-19-04-for-packet-tracert-7) to proper install libpng12.

Some distributions don't have latest `libpng12` versions in their repositories,
and it can conflict with other packages, like `usrmerge`. You can find info on
installing more recent versions of `libpng12` [here](https://askubuntu.com/questions/1116185/cant-install-libpng12-due-to-usrmerge-cant-run-packettracer-without-it).

Download and setup QT 5.12.0 (or later):
```bash
wget https://download.qt.io/archive/qt/5.12/5.12.0/qt-opensource-linux-x64-5.12.0.run
chmod +x qt-opensource-linux-x64-5.12.0.run
```

If you are using Ubuntu, then you can also install QT via apt. This means you can install it without a UI, and without an QT account. It is done via:
```bash
sudo apt update
sudo apt install qt5-default qtmultimedia5-dev qtwebengine5-dev libqt5websockets5-dev
```

**Install into `/opt/Qt/5.12.0` and be sure to select all items to install!**
You might want to install into a different folder but it's important to create
a symlink to the folder mentioned above and build with libraries statically
linked from it if you plan on committing your QT byte runner to this repo.
```bash
./qt-opensource-linux-x64-5.12.0.run
rm qt-opensource-linux-x64-5.12.0.run
```

```bash
sudo apt install libpulse-dev libglu1-mesa-dev qtchooser -y
qtchooser -install qt512 /opt/Qt/5.12.0/5.12.0/gcc_64/bin/qmake
echo "export QT_SELECT=qt512" >> ~/.env && source ~/.env
```
Clone Area9's fork of asmjit repo:
```bash
cd $FLOW/platforms/common/cpp
git clone ssh://git@github.com/area9innovation/asmjit.git
cd asmjit
git checkout next
```
Build QtByteRunner:
```bash
cd $FLOW/platforms/qt
./build.sh # it can return with error 127, but that's expected
```
New QtByteRunner binary will appear in $FLOW/platforms/qt/bin/linux folder

If you get the following messages
```
Project ERROR: Cannot run compiler 'g++'. Output:
===================
sh: 1: g++: not found
===================
Maybe you forgot to setup the environment?
```
then the following solution works
```bash
sudo apt update
sudo apt install build-essential
```

Now you can run hello.flow using flowcpp:
```
cd ~/area9/flow9/
flowcpp sandbox/hello.flow
```
You should see:
```
Flow compiler (3rd generation)

Processing 'sandbox/hello' on server.
0.63s


Hello console
```

After that, the runner will hang, because the program doesn’t end with a
call to `quit(0)`, and the different runners aren’t consistent with each
other about what happens when `main()` ends without an explicit quit
call. You can ctrl-C out of it.

# fdb, the Flow debugger
The C++ runner can also be used in debug mode, which activates a
debugger with a GDB-like command line.

Wrapping the debugger in GNU Readline gives an improved experience with
line editing and command history. If you haven’t already, do:
```bash
sudo apt-get install rlwrap
```
Then an example invocation to run the debugger is:
```bash
rlwrap flowcpp --debug sandbox/hello.flow
```
At the `(fdb)` prompt, you can enter commands such as `step`, `next`,
and `continue`. The `help` command will show a list of all supported
commands.

The debugger can also be used within an editor. Because it mimics GDB,
it works with editors with gdb integration, for example Sublime Text
package. See [resources/sublimetext/readme.md](../resources/sublimetext/readme.md)
for more details.

# Try it (JavaScript in browser)
To compile Flow code to JavaScript, try e.g.
```bash
flowc1 sandbox/hello.flow js=www/hello.js
```
You should see:
```bash
Flow compiler (3rd generation)

Processing 'sandbox/hello' on server.
```
and `flow9/www/hello.js` should be created.

You might think to try the resulting JavaScript code with a command line
tool like Node or SpiderMonkey, but that will break. So you’ll need to
run it a browser.

A quick way to try that is:
```bash
xdg-open http://localhost/flow/flowjs.html?name=hello
```
Your browser should open and display a “Hello window” screen indefinitely and you look in the error console of your
browser and see:
```
"Hello console"
```

# Try it (Executed via apache, in browser)
Information on this topic can be found in platforms/qt/readme.md
in section "Enabling fast-cgi in apache"
# Tools
The auxiliary tools for Flow include a linter, a code formatter, and a
refactoring tool.

They can be run directly using `flow9/bin/lint.sh`.

These tools are also used by the Sublime Text and Emacs integrations.
(The editors also use `flow9/bin/autocomplete.sh` for autocompletion.)
# Profiling
The instructions in [development.markdown](development.markdown) for using the
Flow profiler should work fine on Mac as long as you have Java 8
installed.
