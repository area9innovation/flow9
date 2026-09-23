Flow: getting started (on Linux)
================================

Quick start
-----------

```bash
git clone https://github.com/area9innovation/flow9.git
cd flow9
./bin/setup-linux
```

`bin/setup-linux` installs the packages your distribution needs, initialises the
`asmjit` submodule, builds the C++ runner from source and runs a hello world to
prove it all works. It prints every command before running it, and asks before
it touches your system with `sudo`. Use `--dry-run` to see the plan without
changing anything.

It knows the package names for `pacman` (Arch, Omarchy, Manjaro, EndeavourOS),
`apt` (Debian, Ubuntu, Mint, Pop!\_OS) and `dnf` (Fedora, RHEL). On any other
distribution it prints what you need and stops, so you can install the
equivalents and re-run it with `--skip-deps`.

Finally, add flow9 to your shell so `flowcpp` and friends are on your path:

```bash
export FLOW=$HOME/flow9
export PATH=$FLOW/bin:$PATH
```

Put that in `~/.profile` as well as `~/.bashrc` (or `~/.zshrc`). `~/.profile` is
what applications launched from a desktop menu see; some terminals only read
`~/.bashrc`. A common compromise is to keep the variables in a `~/.env` that
both files `source`.

If you would rather not install anything at all, the repository also ships a
Dev Container that works well with VS Code. See
[devcontainer.md](devcontainer.md).


What the setup script does
--------------------------

Everything below is what `bin/setup-linux` automates. You only need to read it
if you want to do the steps by hand, or if something went wrong.

### 1. Dependencies

flow9 needs three things: a **JDK** to run the `flowc` compiler, **Qt 6** and a
C++ toolchain to build the runner, and a few image and font libraries.

Qt 6.4 or newer works; that is what Ubuntu 24.04 packages, and the build has
been checked against both 6.4 and 6.11.

On Arch and derivatives (including Omarchy) everything is in the official
repositories - there is no need for the Qt Online Installer or a Qt account:

```bash
sudo pacman -S --needed base-devel git git-lfs perl python jdk21-openjdk rlwrap \
    qt6-base qt6-declarative qt6-multimedia qt6-multimedia-ffmpeg \
    qt6-webchannel qt6-websockets qt6-webengine qt6-positioning \
    glu zlib libjpeg-turbo libpng freetype2
```

On Debian and Ubuntu (24.04 or newer):

```bash
sudo apt-get install build-essential git git-lfs perl python3 openjdk-21-jdk rlwrap \
    qt6-base-dev qt6-base-dev-tools qt6-declarative-dev qt6-multimedia-dev \
    qt6-webchannel-dev qt6-websockets-dev qt6-webengine-dev qt6-positioning-dev \
    libgl-dev libglu1-mesa-dev zlib1g-dev libjpeg-dev libpng-dev libfreetype-dev
```

On Fedora:

```bash
sudo dnf install gcc-c++ make git git-lfs perl python3 java-latest-openjdk-devel rlwrap \
    qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtmultimedia-devel \
    qt6-qtwebchannel-devel qt6-qtwebsockets-devel qt6-qtwebengine-devel \
    qt6-qtpositioning-devel \
    mesa-libGLU-devel zlib-ng-compat-devel libjpeg-turbo-devel libpng-devel freetype-devel
```

`rlwrap` is only used to give the debugger line editing, and `qt6-webengine` is
optional - the runner builds without it, just without the embedded browser.

**Java must be 21 or newer.** `tools/flowc/flowc.jar` is compiled to class file
version 65, so older JDKs cannot load it. Check with `java -version`.

### 2. Repository content

The C++ runner uses [asmjit](https://github.com/area9innovation/asmjit) for its
JIT, which is a submodule:

```bash
git submodule update --init platforms/common/cpp/asmjit
```

The repository also uses [Git LFS](https://git-lfs.github.com) for the prebuilt
runner binaries. If you cloned without `git-lfs` installed, those files are
still small text pointers - install it and run `git lfs pull` to fetch them.

On Linux you can skip LFS entirely if you build the runner yourself, which is
what the next step does.

### 3. Build the C++ runner

**Linux users currently need to build the runner themselves.** The
`QtByteRunner` binary committed in `platforms/qt/bin/linux` predates the Qt 5 to
Qt 6 migration, so it still links against `libQt5Core.so.5`,
`libQt5WebEngineWidgets.so.5` and friends. Several distributions - Arch among
them - have dropped Qt 5 WebEngine, WebSockets and WebChannel from their
repositories, so that binary will not start there.

Build out of source, into a directory at the root of the checkout:

```bash
(cd platforms/common/cpp/gl-gui/shaders && ./pack.pl)
mkdir -p QtByteRunner-build-release && cd QtByteRunner-build-release
qmake6 -r -spec linux-g++ CONFIG+=release ../platforms/qt/QtByteRunner.pro
make -j$(nproc)
```

`bin/flowcpp` looks for `QtByteRunner-build-release/QtByteRunner` before falling
back to the committed binary, so your build is picked up automatically. That
directory is in `.gitignore`, so the LFS-tracked binary stays clean in
`git status`.

Alternatively, `platforms/qt/build.sh` builds in place, straight into
`platforms/qt/bin/linux` - convenient, but it overwrites the committed binary.

Note that on Arch the Qt 6 `qmake` is installed as **`qmake6`**; plain `qmake`
exists only in `/usr/lib/qt6/bin`. `build.sh` handles both, and you can set
`QMAKE` to point at a specific one.

For more on building the runner, including the Mac and Windows instructions and
Qt Creator setup, see [platforms/qt/readme.md](../platforms/qt/readme.md).

### 4. Check that it works

Headless, which is the quickest check:

```bash
flowcpp --batch sandbox/hello_console.flow
```

should print `Hello console only`. With a window:

```bash
flowcpp sandbox/hello.flow
```

should print `Hello console` and open a window showing "Hello window!". That
program never calls `quit(0)`, so the runner keeps going after `main()` returns
- press Ctrl-C to stop it.

Then try the demo application, which shows off the UI library:

```bash
flowcpp demos/demos.flow
```


Compiling to JavaScript
-----------------------

To compile flow code to JavaScript:

```bash
flowc1 sandbox/hello.flow js=www/hello.js
```

This creates `www/hello.js`. The result will not run under Node or another
command line JavaScript engine - it needs a browser. Serve the `www` folder and
open `flowjs.html?name=hello`; you should get a "Hello window" screen, and
`"Hello console"` in the browser's error console.

To serve it through Apache with fast-cgi, see the "Enabling fast-cgi in apache"
section of [platforms/qt/readme.md](../platforms/qt/readme.md).


The debugger
------------

The C++ runner doubles as a debugger with a GDB-like command line. Wrapping it
in GNU Readline gives you line editing and history:

```bash
rlwrap flowcpp --debug sandbox/hello.flow
```

At the `(fdb)` prompt, `step`, `next` and `continue` do what you would expect,
and `help` lists everything.

Because it mimics GDB, it also works inside editors that have GDB integration -
see [resources/sublimetext/readme.md](../resources/sublimetext/readme.md).


Tools
-----

The linter is built into `flowc`:

```bash
flowc1 lint=1 sandbox/hello.flow
```

`lint=2` is stricter, `lint-picky=1` stricter still, and `lint-file=<file>`
limits the checks to one file. `flowc1 help=1` lists the rest, including
`find-unused-locals` and `find-unused-exports`.

For profiling, see [development.markdown](development.markdown).


Troubleshooting
---------------

**`flowcpp: cannot execute binary file`, or the runner exits immediately.**
The committed binary is a Git LFS pointer that was never fetched. Either
install `git-lfs` and run `git lfs pull`, or build the runner yourself as
described above.

**`error while loading shared libraries: libQt5Core.so.5`.**
You are running the committed Qt 5 binary on a system that no longer ships
Qt 5. Build the runner from source.

**`Project ERROR: Unknown module(s) in QT: websockets`** from qmake.
The Qt WebSockets development package is missing - `qt6-websockets` on Arch,
`qt6-websockets-dev` on Debian and Ubuntu, `qt6-qtwebsockets-devel` on Fedora.

**`qmake: command not found` on Arch.**
Use `qmake6`, or add `/usr/lib/qt6/bin` to your `PATH`.

**`UnsupportedClassVersionError`, or flowc refuses to start.**
Your JDK is older than 21. Check with `java -version`.

**Rendering is slow.**
Try `flowcpp --antialiassamples 1`, and if that helps, put
`antialiassamples=1` in `flow.config`.


Legacy: the first generation compiler (Haxe and Neko)
-----------------------------------------------------

`flowc` is the current compiler and needs only a JDK. The original compiler,
`bin/flow.n`, is a Neko program built with Haxe, and you only need this if you
are working on that compiler itself.

Our build servers use Haxe 4.2.5 and Neko 2.3.0. Both are packaged on most
distributions (`pacman -S haxe neko`, `apt-get install haxe neko`).

```bash
export HAXE_STD_PATH=/usr/share/haxe/std
haxelib setup ~/haxelib/lib
haxelib install format 3.4.2
haxelib install pixijs 4.8.4    # pixijs 5 is not supported
```

To rebuild `bin/flow.n`:

```bash
cd tools/flow
haxe FlowNeko.hxml
```

This should take seconds. If it takes more than a minute, something is wrong.

Neko needs to be findable by the dynamic linker. Set `NEKOPATH` to wherever
your distribution puts it (`/usr/lib/neko`, `/usr/lib/x86_64-linux-gnu/neko`
and `/usr/local/lib/neko` are all in use), and if you get
`Failed to load library : std.ndll`, that path is wrong.

Two long-standing gotchas, from Alexander Gavrilov:

> 1. Neko executables work by including a small executable with the bytecode,
>    and its 32-bitness must agree with `libneko.so`.
> 2. Some distributions include weird 'optimization' things that strip all
>    executables they see that they aren't told to ignore, and that kills the
>    bytecode. This is true for Fedora, and the thing is called prelink; the
>    nekovm rpm installs a config into `/etc/prelink.conf.d` to stop that.


Legacy: MySQL, PHP and Apache
------------------------------

None of this is needed to build or run flow. It is here for Area9 projects that
have a PHP backend, and the instructions are old - they were written for Ubuntu
18.04 with PHP 7.2, which is long out of support. Treat them as a sketch.

Set up MySQL from https://dev.mysql.com/downloads/repo/apt/, then give
`root@localhost` an empty password:

```bash
sudo mysql --user="root" --execute="ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY ''; FLUSH PRIVILEGES;"
```

and configure the server mode:

```bash
printf '[mysqld]
sql-mode=STRICT_ALL_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER\n' | sudo tee -a /etc/mysql/my.cnf
```

More detail is in
[innovation/doc/mysql.markdown](https://github.com/area9innovation/innovation/blob/master/doc/mysql.markdown).

For Apache, alias your application directory:

```bash
printf 'Alias "/todoapp" "/home/'$USER'/area9/todoapp/www2/"
<Directory /home/'$USER'/area9/todoapp/www2/>
     AllowOverride All
     Require local
</Directory>\n' | sudo tee /etc/apache2/conf-available/area9.conf
sudo a2enconf area9
sudo service apache2 restart
```

`todoapp` is the application name from exercise 9; rename it as you wish.
