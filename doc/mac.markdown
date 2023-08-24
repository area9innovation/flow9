# Flow: getting started (on Mac OS X)

For more details on all of the ways Flow code can be compiled and run,
including options not mentioned below, see `doc/runtimes.markdown`.

If these instructions prove incorrect or incomplete, please fix it
and commit your changes to the repository.

## The basics

The basic prerequisites for compiling and running Flow programs are
Haxe and Neko.

You need Haxe because the Flow compiler and some of the Flow standard
library is written in the Haxe language, so you need Haxe installed
to build the Flow platform itself.

You need Neko because the usual way of running the Flow compiler is to
compile it to Neko bytecode and run it with the C++ bytecode runner.
(Also some of Haxe may depend on Neko, e.g. the `haxelib` command.)

The simplest thing is to install Haxe and Neko in your home directory,
rather than systemwide.

Those prerequisites are sufficient to compile Flow code to SWF
and JavaScript; you can then run your compiled code in a web browser.

## Install Xcode

Install Xcode through the App Store.

## Install command-line tools

To install the command line developer tools, issue this command in
Terminal:

    xcode-select --install

and click on the "Install" button. (The "Get XCode" button is not
applicable since from the previous step, XCode is already
installed.) Proceed with further installation of command line tools.

### Troubleshooting

If after agreeing to the license terms, you happen to encounter the
message "Can't install the software because it is not currently
available from the Software Update server", here is an alternate route
to install the developer tools:

1. Make sure you have an Apple ID to download from the app store. (If you're an iPhone user, you probably already have one.)
2. Have your Mac OS version and Xcode version handy. In order to get Xcode version, run `xcodebuild -version`
3. Navigate to [this URL](https://developer.apple.com/downloads/index.action?name=for%20Xcode%20-)
4. Based on your Mac OS and Xcode versions, select command line tools. Download and install.

## Install Homebrew

Follow the installation instructions at the [Homebrew site](http://brew.sh).

(It's possible that a different package manager such as
[MacPorts](http://www.macports.org/) or
[Fink](http://www.finkproject.org) would be an acceptable substitute
for Homebrew. So for example, if you want to try MacPorts, substitute
`port` for `brew` in the remaining instructions)

## Add bash completion to terminal

By default, Mac OS terminal is lacking bash completion (start a command line and use tab to complete it or to list possible arguments). Here are the steps to add bash completion to the Mac terminal. This allows for quick command line completion:

First, install the appropriate brew package:

    brew install bash-completion

homebrew tells you exactly what you have to do. Just add this to .bash_profile:

    [ -f /usr/local/etc/bash_completion ] && . /usr/local/etc/bash_completion

Finally, add the following lines to ~/.inputrc (create the file if necessary). The first setting will allow for completion even if you got the casing wrong. Should there be ambiguities, the second setting will show all possible options right away, instead of typing tab twice:

    set completion-ignore-case on
    set show-all-if-ambiguous on

You will need to restart your terminal to benefit from those changes and enable bash completion.

## Install Haxe

Our build servers use haxe 4.2.5 and neko 2.3.0.

An OS X installer is available here:

    http://haxe.org/download/

After running the installer, add this to your shell init file (e.g. `~/.bash_profile` or `~/.zshrc`):

    export HAXE_STD_PATH=/usr/local/lib/haxe/std

and start a new shell. It is not necessary at least for newest Haxe 3.4.4.

Set up your Haxe library directory:

    cd ~
    mkdir -p haxelib/lib
    haxelib setup

You will be prompted to enter the desired haxelib path. Please specify the haxelib location you just created, e.g. `/Users/mathieu_perceau/haxelib/lib`.

Then install the required libraries:

    haxelib install format
    haxelib install pixijs 4.8.4
    (pixijs version 5 isn't supported)

## Install Neko 2.3.0

If the haxe installer above did not install Neko or installed a wrong version, you can do it manually like this:

    brew install neko

And add this to your shell init file (e.g. `~/.bash_profile` or `~/.zshrc`):

    export NEKOPATH=/usr/local/lib/neko
    export PATH=$NEKOPATH:$PATH

**NOTE:** if you have error “Uncaught exception - load.c(237) : Failed to load library : std.ndll (dlopen(std.ndll, 1): image not found)”
check your real neko path and put it in NEKOPATH, it can be /usr/local/lib/neko or another

As always when editing shell init files, you'll need to start a new shell
to pick up the changes.

### Troubleshooting

No issues to report at the moment.

# Install `JDK`
Be sure that you have installed JDK 11 or newer in a 64-bit version. That is required by the *flowc* compiler, which is used
by default. You may find it here:

	https://www.oracle.com/java/technologies/javase-jdk11-downloads.html

OpenJDK is suitable as well.

## Check out Flow repository

You should have [Git LFS](https://git-lfs.github.com) installed.
Reclone the flow9 repository after installing Git LFS, or use
```bash
git lfs pull
```

Do the checkout:

    cd ~
    git clone https://github.com/area9innovation/flow9

And add this to your shell init file (e.g. `~/.bash_profile` or `~/.zshrc`):

    export FLOW=$HOME/flow9
    export PATH=$FLOW/bin:$PATH

and start a new shell.

## Compile Flow itself

    cd ~/flow9/src
    haxe Build.hxml
    cd ..
    neko src/build.n

If compilation succeeds, some tests will also run, and the output will
conclude with a line like:

    Flowunit tests: 963 checks passed.

The following files will be created or overwritten:

    bin/flow.n
    bin/flowrunner.n
    src/build.n
    www/FlowRunner.swf
    www/FlowFlash.swf
    www/js/flow.js
    www/js/flow.js.map
    www/js/flowrunner.js
    *.bytecode

## Try it (C++ runner)

You'll probably need to do this first:

    brew install qt5

Because of a runtime dependency on libjpeg and libpng, you should also run

    brew install libjpeg
    brew install libpng

There are also runtime dependencies on the XQuartz libraries libpng and libGLU.  To ensure you have a recent enough version of libpng, you should download the latest XQuartz (http://xquartz.macosforge.org/landing/).  By default it will install to /opt/X11, where it needs to be to be found at runtime, rather than to /usr/X11 where you may find an XQuartz preinstalled.

The repository contains a prebuilt Mac OS X binary for `flowcpp`.

You can also run command-line-only stuff with it, and avoid
initializing the GUI subsystem:

    cd ~/flow9
    flowcpp sandbox/hello.flow

You should see:

    "neko flow.n  --compile hello.bytecode --debuginfo hello.debug sandbox/hello.flow
    Compiling sandbox/hello.flow ...
    "
    Hello world

After that, the runner will hang, because the program doesn't end with
a call to `quit(0)`, and the different runners aren't consistent with
each other about what happens when `main()` ends without an explicit
quit call.  You can ctrl-C out of it.

If you get a message that a library version on your system is not new
enough, `brew update && brew upgrade` might fix it.

Unless you're hacking on the C++ source code for the bytecode
runner, you shouldn't need to rebuild it. You can just use
the binary that's already in the repository.

But if you need to build a new binary, see `platforms/qt/readme.txt`.

More info on compiling flow in js or running it on apache can be found in linux doc.

## fdb, the Flow debugger

The C++ runner can also be used in debug mode, which activates a
debugger with a GDB-like command line.

Wrapping the debugger in GNU Readline gives an improved experience
with line editing and command history.  If you haven't already, do:

    brew install rlwrap

Then an example invocation to run the debugger is:

    rlwrap flowcpp --batch --debug sandbox/helloworld.flow

At the `(fdb)` prompt, you can enter commands such as `step`,
`next`, and `continue`.  The `help` command will show a list of
all supported commands.

The debugger can also be used within an editor.  Because it mimics
GDB, it works with editors with gdb integration, for example Sublime
Text's SublimeGDB package. See [resources/sublimetext/readme.md](../resources/sublimetext/readme.md)
for more details.

## Try it (JavaScript in browser)

To compile Flow code to JavaScript, try e.g.

    flow --js helloworld.js sandbox/helloworld.flow

You should see:

    neko flow.n  --js helloworld.js sandbox/helloworld.flow
    Compiling sandbox/helloworld.flow ...

and `helloworld.js` should be created.

You might think to try the resulting JavaScript code with a command
line tool like Node or SpiderMonkey, but that will break. So you'll
need to run it a browser.

A quick way to try that is:

    mv helloworld.js www
    (cd www; python -m SimpleHTTPServer) &
    open http://localhost:8000/flowjs.html?name=helloworld

Your browser should open and display a "Loading" screen indefinitely.
But you'll know the code ran if you look in the error console of your
browser and see:

    Errors.hx:40 : "Hello world"

You can leave the web server running for now, or kill it with:

     kill %

Notice that while this works for quick checks, you should work to
setup a local web browser to serve the flow/www folder as "flow",
so the link

    http://localhost/flow/flowjs.html?name=helloworld

works right.

## Apache + PHP + MySQL

Apache should be already available: sudo httpd

It has PHP module, but for some flow apps PHP needs mcrypt extension.
Install PHP 7.1 Homebrew package:

    brew install php@7.1

With Pecl from that package you need to install mcrypt:

    /usr/local/Cellar/php@7.1/7.1.18/bin/pecl install mcrypt-1.0.0

Add the following to /etc/php.ini (path of .so may be not the same):

    extension="/usr/local/Cellar/php@7.1/7.1.18/pecl/20160303/mcrypt.so"

If /etc/php.ini does not exist create that from /private/etc/php.ini

More details on mysql setup can be found in `flow/doc/linux.markdown` and `flow/doc/mysql.markdown`

## Tools

The auxiliary tools for Flow include a linter, a code formatter,
and a refactoring tool.

They can be run directly using `flow/bin/lint.sh`.

These tools are also used by the Sublime Text and Emacs integrations.
(The editors also use `flow/bin/autocomplete.sh` for autocompletion.)

### Building the tools (optional)

You'll probably want to just use the binary that's already in the
repository.

But if you want or need to rebuild it, read on.

The tools are written in OCaml, so you may first need:

    brew install ocaml

Then to do the build:

    cd ~/flow9/flowtools/src
    make deploy

The new binaries will be in the `flowtools/bin/mac` directory.
Consider committing them to version control.

## Profiling

The instructions in [development.markdown](development.markdown) for
using the Flow profiler should work fine on Mac as long as
you have Java 8 installed.
