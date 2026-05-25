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


Building (command line) (Mac)
-----------------------------

### Prerequisites

1. **Xcode Command Line Tools**

       xcode-select --install

2. **Homebrew** (https://brew.sh)

       /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

3. **Qt 6.11.1**
   - Download the Qt Online Installer from https://www.qt.io/download/
   - Install Qt 6.11.1 with the **macOS** kit (e.g. to `~/Qt/6.11.1/macos`)
   - Also install the following Qt modules:
     - **Qt WebEngine** (for embedded browser support)
     - **Qt Positioning** (WebEngine dependency)
     - **Qt Multimedia** (video/audio playback)
     - **Qt WebSockets**
     - **Qt WebChannel**

4. **Third-party libraries** (via Homebrew):

       brew install freetype libpng libjpeg glew

5. **Java JDK 21** (for flow compiler):

       brew install openjdk@21

   Then add to your shell profile (`~/.zshrc` or `~/.bash_profile`):

       export JAVA_HOME=$(/usr/libexec/java_home -v 21)
       export PATH="$JAVA_HOME/bin:$PATH"

6. **Environment variables** — add to your shell profile:

       export QTDIR=~/Qt/6.11.1/macos
       export PATH="$QTDIR/bin:$PATH"
       export PATH="<flow9_root>/bin:$PATH"

### Build steps

    cd platforms/qt
    mkdir build && cd build
    qmake -r -spec macx-clang CONFIG+=release ../QtByteRunner.pro
    make -j$(sysctl -n hw.ncpu)

The new binary will be in `platforms/qt/build/release/QtByteRunner.app`.

Deploy Qt frameworks into the app bundle:

    macdeployqt release/QtByteRunner.app

Copy to the distribution folder:

    cp -R release/QtByteRunner.app ../bin/mac/

### Mac tips

* If you get messages about missing CGI stuff: `brew install fastcgi`
* If you get OpenGL-related errors, make sure Xcode Command Line Tools are up to date
* On Apple Silicon (M1/M2/M3), Homebrew installs to `/opt/homebrew` — make sure
  `/opt/homebrew/include` and `/opt/homebrew/lib` are in your include/library paths

Building (command line) (Linux)
-------------------------------

### Prerequisites

1. **Qt 6.11.1**
   - Download the Qt Online Installer from https://www.qt.io/download/
   - Install Qt 6.11.1 with the **GCC 64-bit** kit (e.g. to `/opt/Qt/6.11.1/gcc_64`)
   - Also install the following Qt modules:
     - **Qt WebEngine** (for embedded browser support)
     - **Qt Positioning** (WebEngine dependency)
     - **Qt Multimedia** (video/audio playback)
     - **Qt WebSockets**
     - **Qt WebChannel**

2. **Build essentials and libraries** (Ubuntu/Debian):

       sudo apt-get install build-essential libgl1-mesa-dev libglu1-mesa-dev \
           libfreetype-dev libjpeg-dev libpng-dev zlib1g-dev \
           libfontconfig1-dev libxcb-xinerama0-dev libxkbcommon-dev \
           libglew-dev libnss3-dev libxcomposite-dev libxdamage-dev \
           libxrandr-dev libasound2-dev libpulse-dev libdbus-1-dev

3. **Java JDK 21** (for flow compiler):

       sudo apt-get install openjdk-21-jdk

   Add to `~/.bashrc`:

       export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
       export PATH="$JAVA_HOME/bin:$PATH"

4. **Environment variables** — add to `~/.bashrc`:

       export QTDIR=/opt/Qt/6.11.1/gcc_64
       export PATH="$QTDIR/bin:$PATH"
       export PATH="<flow9_root>/bin:$PATH"

### Build steps

    cd platforms/qt
    mkdir build && cd build
    qmake -r -spec linux-g++ CONFIG+=release ../QtByteRunner.pro
    make -j$(nproc)

Copy to the distribution folder:

    cp release/QtByteRunner ../bin/linux/

### Linux tips

* To check rpath of the built binary:
  `readelf -d platforms/qt/bin/linux/QtByteRunner | grep rpath`

* It's possible to have several versions of Qt installed at once with `qtchooser`.
  If you are using it, either provide `qt=` parameter when using qmake or set
  default version accordingly. See `man qtchooser`.

* Minimal list of libraries required to **run** QtByteRunner on Linux:
  libasound2 libdbus-1-3 libegl1-mesa libfontconfig1 libfreetype6 libglib2.0-0
  libglu1-mesa libjpeg8 libnspr4 libnss3 libpng16-16 libpulse0 libxcomposite1
  libxcursor1 libxi6 libxml2 libxrender1 libxslt1.1 libxtst6 zlib1g

  Package names are for Ubuntu 22.04+; names in other distros may vary. If in doubt,
  run `ldd` on the committed binary and look up the packages.

Building (IDE) (Mac)
--------------------

You can also build QtByteRunner using the Qt Creator IDE.

### Setup

1. Install **Qt 6.11.1** with the Online Installer from https://www.qt.io/download/
   - Select **macOS** kit
   - Select **Qt WebEngine**, **Qt Positioning**, **Qt Multimedia**, **Qt WebSockets**, **Qt WebChannel**
   - Select **Qt Creator** under Tools
2. Install **Xcode Command Line Tools**: `xcode-select --install`
3. Install third-party libraries via Homebrew:

       brew install freetype libpng libjpeg glew

### Build

1. Open Qt Creator
2. Open the project `platforms/qt/QtByteRunner.pro`
3. Configure it to use the kit **Qt 6.11.1 macOS** (clang 64-bit)
4. Set the build directory to `platforms/qt/build`
5. Build Release version
6. Run `macdeployqt` on the output to bundle Qt frameworks
7. Copy `QtByteRunner.app` to `platforms/qt/bin/mac/` to deploy

Running from IDE on Mac
---------------------------

1. Open Qt Creator and open the project `platforms/qt/QtByteRunner.pro`
2. Go to **Projects** in the left panel, choose the **Run** tab
3. Set **Working directory** to the flow9 root folder (e.g. `/Users/<username>/flow9`)
4. Uncheck **Add build library search path to DYLD_LIBRARY_PATH and DYLD_FRAMEWORK_PATH**
5. Set command line arguments (e.g. `sandbox/hello.flow`)
6. Click Run

Building (command line) (Win)
-----------------------------

### Prerequisites

1. **Visual Studio 2022 Build Tools** (or Community/Professional/Enterprise)
   - Download from https://visualstudio.microsoft.com/ru/vs/older-downloads/
   - Install the **"Desktop development with C++"** workload
   - Make sure **Windows 11 SDK** is selected in the individual components

2. **Qt 6.11.1 for MSVC 2022 64-bit**
   - Download the Qt Online Installer from https://www.qt.io/download/
   - Install Qt 6.11.1 with **MSVC 2022 64-bit** kit to `C:\Qt\6.11.1\msvc2022_64`
   - Also install the following Qt modules:
     - **Qt WebEngine** (for embedded browser support)
     - **Qt Positioning** (WebEngine dependency)
     - **Qt Multimedia** (video/audio playback)
     - **Qt WebSockets**
     - **Qt WebChannel**

3. **Java JDK 21** (for flow compiler)
   - Install OpenJDK 21 to `C:\Program Files\Java\jdk-21`
   - Set system environment variable: `JAVA_HOME = C:\Program Files\Java\jdk-21`
   - Add `%JAVA_HOME%\bin` to system `PATH`

4. **Environment variables** (set system-wide via System Properties > Environment Variables):
   - Add `C:\Qt\6.11.1\msvc2022_64\bin` to `PATH`
   - Add `<flow9_root>\bin` to `PATH`

### Build steps

Open a Command Prompt and run:

    :: Initialize MSVC 2022 environment (adjust path if using Community/Professional)
    call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"

    :: Create out-of-source build directory
    cd platforms\qt
    mkdir build
    cd build

    :: Generate Makefile with qmake
    C:\Qt\6.11.1\msvc2022_64\bin\qmake.exe -r -spec win32-msvc CONFIG+=release ..\QtByteRunner.pro

    :: Compile
    nmake

After a successful build, deploy Qt DLLs and copy to the distribution folder:

    :: Deploy all required Qt DLLs (including WebEngine)
    C:\Qt\6.11.1\msvc2022_64\bin\windeployqt.exe release\QtByteRunner.exe

    :: Copy third-party DLLs (freetype, glew, libpng, etc.)
    copy /Y ..\win32-libs\bin64\* release\

    :: Deploy to bin\windows
    xcopy /E /Y /I release ..\bin\windows

### Clean rebuild

To do a clean rebuild, remove the build directory and repeat the steps above:

    cd platforms\qt
    rmdir /S /Q build

Building (IDE) (Win)
--------------------

You can also build QtByteRunner using the Qt Creator IDE.

### Setup

1. Install **Qt 6.11.1** with the Online Installer from https://www.qt.io/download/
   - Select **MSVC 2022 64-bit** kit
   - Select **Qt WebEngine**, **Qt Positioning**, **Qt Multimedia**, **Qt WebSockets**, **Qt WebChannel**
2. Install **Visual Studio 2022 Build Tools** from https://visualstudio.microsoft.com/ru/vs/older-downloads/
   - Select **"Desktop development with C++"** workload with **Windows 11 SDK**

### Build

1. Open Qt Creator
2. Open the project `flow9/platforms/qt/QtByteRunner.pro`
3. Configure it to use the kit **Qt 6.11.1 MSVC 2022 64-bit**
4. Add a custom build step after the main build:
   - Command: `windeployqt`
   - Arguments: `release\QtByteRunner.exe` (for Release) or `debug\QtByteRunner.exe` (for Debug)
5. Build Release version
6. Copy the release output to `flow9/platforms/qt/bin/windows` to deploy

Running from IDE on Windows
---------------------------

Copy DLLs from `win32-libs\bin64` to the build output directory where
`QtByteRunner.exe` resides (e.g. `build-QtByteRunner-Desktop_Qt_6_11_1_MSVC2022_64bit-Release/release`).

Also run `windeployqt` on the executable to deploy all required Qt DLLs:

    C:\Qt\6.11.1\msvc2022_64\bin\windeployqt.exe release\QtByteRunner.exe

Set the working directory in Qt Creator Run Settings to the flow9 root folder
(e.g. `C:\Users\<username>\Documents\GitHub\flow9`).


Troubleshooting MySQL on Mac
-----------------------------

1) If you get errors like:

       QSqlDatabase: QMYSQL driver not loaded

   The MySQL/MariaDB Qt SQL driver plugin needs to be available. Install MySQL client
   libraries and rebuild the Qt SQL driver, or install via Homebrew:

       brew install mysql-client

   Then ensure the `libqsqlmysql.dylib` plugin is in `QtByteRunner.app/Contents/PlugIns/sqldrivers/`.

2) If you get:

       Can't connect to local MySQL server through socket '/tmp/mysql.sock'

   Change `"localhost"` to `"127.0.0.1"` in the flow code that connects.
   Port 3306 is for local DB. If connecting to a remote server, check that your
   SSH tunnel and port forwarding are active (commonly port 3307).

3) If you get:

       Can't connect to MySQL server on '127.0.0.1' (61)

   The tunnel is not running or the forwarding port is wrong. Verify connectivity
   using a MySQL client tool (e.g. MySQL Workbench, HeidiSQL, DBeaver).

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

1) Place the output of generation into `platforms/qt/flowgen`
2) `qmake CONFIG+=no_gui CONFIG+=native_build QtByteRunner.pro`
3) `make clean all`

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

### Using Visual Studio Debugger (recommended)

1. Build QtByteRunner in Debug mode (replace `CONFIG+=release` with `CONFIG+=debug` in the qmake step)
2. Run `windeployqt` on the debug executable to deploy debug Qt DLLs
3. Copy DLLs from `win32-libs\bin64` to the debug output directory
4. Open Visual Studio 2022 and use **Debug > Attach to Process** or launch directly:

       devenv /debugexe platforms\qt\build\debug\QtByteRunner.exe sandbox/hello.flow

### Using Qt Creator Debugger

1. Open `QtByteRunner.pro` in Qt Creator
2. Configure the Debug build with the **Qt 6.11.1 MSVC 2022 64-bit** kit
3. Set the working directory to the flow9 root folder
4. Set command line arguments (e.g. `sandbox/hello.flow`)
5. Press F5 to start debugging

Qt Creator uses the CDB debugger (from Windows SDK) when configured with an MSVC kit.
