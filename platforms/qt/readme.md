Normal use
----------

There is a precompiled binary in this repository. You can launch it with

  flowcpp

from flow9/bin, which you should put in your path.


Command line usage
------------------

Define what program to run by giving the filename on the command line:

    flowcpp sandbox/fun.flow

This will invoke "flow" or "flowc1" to compile the program to bytecode, and then run it.

You can also define what program to run by giving a bytecode filename on the command line:

    flowcpp bytecode_file.bytecode [bytecode_file.debug | --disassemble]

Here, bytecode_file.bytecode is a file with the compiled flow program.  
The bytecode_file.debug is a file with debug information.

Example of how to compile a flow program to bytecode with debugging info:

    flowc1 sandbox/hello.flow bytecode=driver.bytecode debug=1

or

    flow -c driver.bytecode --debuginfo driver.debug sandbox/hello.flow

Example of how to run a flow program and pass a parameter that will be accepted
through getUrlParameter in the flow code:

    flow app/app.flow -- devtrace=1

If you want flowcpp to compile flow code before running, there are 2 compilers to choose from.
1. Legacy neko compiler (1st generation, default, `--nekocompiler` command line option)
2. flowc compiler (3rd generation, `--flowc` command line option)

Those options can also be set in `flow.config` file as described below.

Other command line options to QtByteCoderunner
----------------------------------------------

`--disassemble`
  makes QtByteRunner disassemble bytecode file without running.

`--media-path <path>`
  defines where the runner should find the font resource files.
  Normally c:\flow9 on Windows.
  Warning: wrong media-path now causes program crash!

`--fallback_font <font>`
  enables lookup of unknown glyphs in the `<font>`. `<font>` example - `DejaVuSans`.

`--touch`
  Emulate touch device events.
  Press `F12` to turn device orientation
  Press `Ctrl-Shift-F11` to toggle Pan Gesture on/off.
    Use Mouse to click and drag to emulate Pan Gesture when On.
  Press `Ctrl-Shift-Arrow Key-Left Mouse` to simulate Swipe gestures
  This also sets: `target::mobile = true`

To learn about profiling, please read ../doc/development.html.

If rendering performance is low, then try this command line

`--antialiassamples <int>`
    Adjust the amount of antialiasing used when rendering. Set to 0 or 1 if you have
    slow rendering. If this helps, you can add this to your flow.config

    antialiassamples=1

Using `flow.config` file
----------------------

There is a way to provide a project-specific configuration setting via `flow.config` file put into project root - where `flowcpp` is ran from. This is a standard properties file (key=value), the following options are currently supported:
 * `flowcompiler` - choice of `nekocompiler`, `flowcompiler`, `flowc` (or `0`,`1`,`2`)
 * `media_path`
 * `fallback_font`

Options given in the command line take precedence over `flow.config`.


Building (command line)
-----------------------

On Linux and Mac, you can build the binary using the `build.sh`
script in this directory.

The new binary will be in `platforms/qt/bin/mac/QtByteRunner.app`,
or a slightly different path if you're on Linux.  Consider committing
it to version control.

A few Mac-specific tips:

* If you get messages about missing CGI stuff try:
  brew install fastcgi
* If you get messages about missing headers and/or libraries, make sure
  you have the latest version of
  [XQuartz](http://xquartz.macosforge.org/landing/) installed.

Linux specific tips:

* QT libs are expected to be in /opt/Qt5.12.0/5.12.0/gcc_64/lib. This is because
Linux runner is provided without the libraries and used in CI pipelines.
So committing it with different rpath will break things.

* To get rpath of byte runner you can do
readelf -d platforms/qt/bin/linux/QtByteRunner | grep rpath
inside flow9 repo.

* Evidently, required version of QT is 5.12.0, and it can be installed with
installer from
https://download.qt.io/archive/qt/5.12/5.12.0/qt-opensource-linux-x64-5.12.0.run
Installation path should be /opt/Qt5.12.0. Or you can install wherever and symlink.

* It's possible to have several versions of QT installed at once
with qtchooser. If you are using it, either provide qt= parameter when
using qmake or set default version to 5.12.0 with libs at the location
mentioned above. man qtchooser will tell you how.

* Minimal list of libraries required to run QT byte runner on Linux:
libasound2 libdbus-1-3 libegl1-mesa libfontconfig1 libfreetype6 libglib2.0-0
libglu1-mesa libjpeg8 libnspr4 libnss3 libpng12-0 libpulse0 libxcomposite1
libxcursor1 libxi6 libxml2 libxrender1 libxslt1.1 libxtst6 zlib1g

To compile it you will also need
libglu1-mesa-dev libjpeg8-dev libpng12-dev zlib1g-dev libfreetype-dev

Those names are for Ubuntu 16.04, names in other distros may vary. If in doubt,
just ldd committed version and look up the packages.

Building (IDE) (Mac)
--------------------

Another way to build QtByteRunner is to use the QtCreator IDE. It can be downloaded from

https://www.qt.io/download/

Download and execute online installer.
Choose
- Qt/Qt 5.12.0
and
- Tools
Install.

Be sure you have installed libpng, jpeg & freetype.
If you have no libs installed install Brew from http://brew.sh.
Then run
brew install libpng
brew install libjpeg
brew install freetype

Once you get libs installed run Qt Creator.

Open the project platforms/qt/QtByteRunner.pro
Press Projects on the left panel

Configure it's build directory to platforms/qt/bin/mac

Build either Release or Debug version.

Running from IDE on Mac
---------------------------

Open Qt Creator.
Then open the project platforms/qt/QtByteRunner.pro

Once you get the project opened choose Projects in the left panel
Choose Run tab.

Take sure your Working directory is set to %{sourceDir}/bin/mac

Unchoose flag Add build library search path to DYLD_LIBRARY_PATH and DYLD_FRAMEWORK_PATH.

Enjoy running your project in Qt Creator.

Building (IDE) (Win)
--------------------

Another way to build QtByteRunner is to use the QtCreator IDE. It can be downloaded from

https://www.qt.io/download/

Download and execute online installer.
Choose
- Qt/Qt 5.12.0/msvc(2017 or 2015) 64bit
and
- Qt/Qt 5.12.0/msvc(2017 or 2015) 32bit
and
- Qt/Qt 5.12.0/Qt WebEngine

Install.

Install Microsoft Visual Studio (2017 or 2015) Express from

https://www.visualstudio.com/vs/visual-studio-express/


Run Qt Creator.

Open the project `flow9/platforms/qt/QtByteRunner.pro`

Configure it to use the kit `Qt 5.12.0 + MSVC %2017|2015% 64bit` and `Qt 5.12.0 + MSVC %2017|2015% 32bit`

For both configurations add special build step with parameters:
Command: `windeployqt`
Arguments:
 - for Release: `--release release/QtByteRunner.exe`
 - for Debug: `--debug debug/QtByteRunner.exe`
This step creates updated `vc_redist.x64.exe` and requires environment variable VCINSTALLDIR (f.e. `C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\`)

Build either Release or Debug version.

Copy the 64bit release executable to flow9/platforms/qt/bin/windows to deploy.
Copy the 32bit release executable to flow9/platforms/qt/bin/windows32 to deploy.

Running from IDE on Windows
---------------------------

For 64 bit build be sure to copy .dlls from win32-libs\bin64 to the
build-QtByteRunner-Desktop_Qt_5_12_0_MSVC2017_64bit-Release/release  (or <...>-Debug/debug) directory where the
QtByteRunner.exe resides.

For 32bit be sure to copy .dlls from win32-libs\bin to the
build-QtByteRunner-Desktop_Qt_5_12_0_MSVC2017_32bit-Release/release  (or <...>-Debug/debug) directory where the
QtByteRunner.exe resides.


Running on Mac
--------------
1) If you ger error while trying to access MySQL DB through QtByteRunner and getting these errors:
    QSqlDatabase: QMYSQL driver not loaded
    QSqlDatabase: available drivers:
    -Then (re)install QT with MySQL support (could take 10+minutes):
    brew remove qt4
    brew install qt4 --with-mysql
    cd $FLOW/platforms/qt/bin/mac/QtByteRunner.app/Contents/PlugIns/sqldrivers/
    cp /usr/local/Cellar/qt/4.8.7/plugins/sqldrivers/libqsql* .

2) Getting such messages:
    localhost:3306
    Exception:Can't connect to local MySQL server through socket '/tmp/mysql.sock' (2) QMYSQL: Unable to connect
    -Change "localhost" to "127.0.0.1" in the code which tries to connect.
    -3306 is for local DB. Usually connection to servers requires using a tunnel and port forwarding, so check that as well (usually we use 3307 for port forwarding).

3) Getting such messages:
    127.0.0.1:3307
    QSqlQuery::exec: database not open
    Exception:Can't connect to MySQL server on '127.0.0.1' (61) QMYSQL: Unable to connect
    -Tunnel is not functioning or incorrect forwarding port number. Check it and try to connect using MySQL admin tool, like Workbench, HeidiSQL, etc.

Usage
-----

Before you run the program, you have to define the command line in QtCreator by clicking "Projects" in
the left hand side, and then choose the "Run Settings" tab.

Also be sure that the working directory is set right to point to the root of the flow9 folder.
So on a Mac, it could be /Users/asgerottaralstrup/flow9/. On a Windows machine,
it could be c:/flow9/

Enabling fast-cgi in apache
---------------------------

To execute flow code via apache to implement backend in flow, you should
have apache configured, see below Linux/Windows configuring.

You need to compile flow file into bytecode like this:

    flow --compile helloworld.serverbc helloworld.flow
    flowc1 helloworld.flow bytecode=helloworld.serverbc

It is important to finish the code with `quit` function, otherwise the program will hang.

Put `helloworld.serverbc` file in folder served by apache.
Any HTTP request to `helloworld.serverbc` will launch bytecode and its stdoutput
will return in HTTP response, you can see it directly in your browser.

Configuring fast-cgi on Linux
-----------------------------

Install libapache2-mod-fcgid and enable it:

    sudo apt-get install libapache2-mod-fcgid
    a2enmod fcgid

Set up config for apache cgi:
File /etc/apache2/mods-enabled/fcgid.conf should look like this:

    <IfModule mod_fcgid.c>
      FcgidConnectTimeout 20
      <IfModule mod_mime.c>
        IPCCommTimeout 600
        AddHandler fcgid-script .serverbc
        FcgidConnectTimeout 600
        FcgidIOTimeout 600
        # Useful for debugging when you want one instance of runner
        # DefaultMinClassProcessCount 1
        FCGIWrapper PATH_TO_CGI_BYTERUNNER .serverbc
      </IfModule>
      <Files ~ "\.serverbc$">
        Options ExecCGI
      </Files>
    </IfModule>

    where PATH_TO_CGI_BYTERUNNER is substituted for path to QtByteRunner.fcgi,
    e.g. /home/user/code/flow9/platforms/qt/bin/cgi/linux/QtByteRunner.fcgi

To compile QtByteRunner.fcgi use QtByteRunnerCgi.pro product.

Configuring fast-cgi on Windows
-------------------------------

For windows we have a precompiled x32 version: flow9/platforms/qt/bin/windows32/QtByteRunner.fcgi.exe
Flow repository already contains compiled version of fcgi.lib and libfcgi.dll (compiled with msvc 2015, win32 target). If you want to build it by yourself, use source code from here: https://github.com/FastCGI-Archives/fcgi2
QtByteRunnerCgi implements FastCGI mode. Apache must be configured to support this mode.

You have to install mod_fcgid for apache:

1. Identify the version of Apache server that is running. Tips: visit http://localhost/ on your browser. The default WampServer homepage will show the details of Apache server. (Example: Server Software: Apache/2.4.33 (Win64) ).
2. Download mod_fcgid binaries for windows. Extract the files and copy "mod_fcgid.so" into the apache modules folder. The folder path will be something like "C:\wamp64\bin\apache\apache2.4.33\modules" if your Apache version is 2.4.33.
Apache 2.4-VC15 (64-bit): http://www.apachelounge.com/download/VC15/modules/mod_fcgid-2.3.9-win64-VC15.zip
More versions here: http://www.apachelounge.com/download/
3. Edit the Apache configuration file. Open the file "C:\wamp64\bin\apache\apache2.4.33\conf\httpd.conf" in a text editor such as Notepad++.
- Enable mod_fcgid by adding the following line:

```
LoadModule fcgid_module modules/mod_fcgid.so
```

- Configure mod_fcgid by adding the following lines(fix paths if they are different on your setup):

```
<IfModule fcgid_module>
  FcgidInitialEnv PATH "C:/wamp64/bin/php/php5.6.35;C:/WINDOWS/system32;C:/WINDOWS;C:/WINDOWS/System32/Wbem;"
  FcgidInitialEnv SystemRoot "C:/Windows"
  FcgidInitialEnv SystemDrive "C:"
  FcgidInitialEnv TEMP "C:/Wamp64/tmp"
  FcgidInitialEnv TMP "C:/Wamp64/tmp"
  FcgidInitialEnv windir "C:/WINDOWS"
  FcgidIOTimeout 1024
  FcgidConnectTimeout 64
  FcgidMaxRequestsPerProcess 1000
  FcgidMaxProcesses 20
  FcgidMinProcessesPerClass 0
  FcgidMaxRequestLen 813107200

  <Files ~ "\.serverbc$">
    Options +ExecCGI +Indexes +MultiViews
    AddHandler fcgid-script .serverbc
    FcgidWrapper C:/flow9/platforms/qt/bin/cgi/windows32/QtByteRunner.fcgi.exe .serverbc
  </Files>

</IfModule>
```

Compile this test program to hello.serverbc and try to run it from browser:
```
import runtime;

main() {
  println("Hello console");
  quit(0);
}
```

Compiling flow compiled to c++
------------------------------

For a server-based program like reports.serverbc:

1) plop the output of generation into platforms/qt/flowgen
2) qmake CONFIG+=no_gui CONFIG+=native_build QtByteRunner.pro (or qmake-qt5 - not tested)
3) nice make clean all

Profiling contexts
------------------

When profiling, there are some special buckets for different things:

0 is garbage collection.
100 is for all rendering.
101 is for computing matrices and invalidating stuff where needed.
102 calls clips recursively to render any sub-buffers like filter inputs.
103 is rendering the content of filters and masks
104 is for rendering the final frame, excluding the inputs to any filters or masks

So if it's Filter1(Filter2(foo)) it would be
103: tmp1 <- foo
103: tmp2 <- Filter2(tmp1)
104: output -< Filter1(tmp2)

where tmp* and output are buffers in video memory.

Debugging the C++ code under Windows
------------------------------------

It is a hassle to get the GDB debugger to work in Qt Creator on windows, so the easier
choice is probably just to run GDB from the command line.

Compile the Qt runner in debug mode. Then copy all the *d.dll's from your Qt installation,
maybe C:\Qt\5.5\bin into the Debug build folder where QtByteRunner.exe is.

Then go to c:\flow9, or equivalent in a command line, and run:

  C:\mingw32\bin\gdb c:\flow9\build-QtByterunnder-Desktop-Debug\debug\QtByteRunner.exe

This will start the debugger, and hopefully read symbols correctly.

Next, to start the program, use

  r sandbox/hello.flow

or similar to start the program.

If it crashes, then use "bt" to see the callstack of the c++ runner where the problem is.
Type "q" to quit GDB.
