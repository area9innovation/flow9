# Flow Sublime Text plugin

*Notice: `<FLOWDIR>` is your base flow core dir (where /lib and /bin folders are located)*

## Table of contents

- [Install Sublime Text 3](#install-sublime-text-3)
- [Install Package Control](#install-package-control)
- [Install SublimeLinter](#Install-sublimelinter)
- [Install Flow & Lingo integration](#install-flow-&-lingo-integration)
- [Install the Debugger](#install-the-debugger)
- [Setup and Check Features](#setup-and-check-features)
- [Tips & Tricks](#tips-&-tricks)


## Install Sublime Text 3

Install Sublime Text 3.

    http://www.sublimetext.com/3


Note for ubuntu users: if started from thumbnail, sublime might ignore env variables.
To fix that, add them to `~/.pam_environment`, or flow binary might be missing from `PATH`

### Set Unix line endings as default

Even on Windows, we want to use Unix line endings, so make sure to use something like this in
`Preferences -> Settings -> User`:

    {
      "default_line_ending": "unix"
    }

To change a specific file to use Unix line endings, you can use `View -> Line endings -> Unix`.

Also, make sure your Git is configured to use Unix line-endings:

    git config --global core.eol lf
    git config --global core.autocrlf input

With an existing repo that you have already checked out – that has the correct line endings
in the repo but not your working copy – you can run the following commands to fix it:

    git rm -rf --cached .
    git reset --hard HEAD

## Install Package Control

Next, install Package Control from

    https://packagecontrol.io/

by copying the text on the Installation page to the clipboard, then
use `View -> View Console` in Sublime Text and paste it, and press enter.

## Install SublimeLinter

Once you install Package Control, restart Sublime Text and bring up the Command Palette
(`Command+Shift+P` on OS X, `Control+Shift+P` on Linux/Windows).

Select `Package Control: Install Package`, wait while Package Control fetches
the latest package list, then select `SublimeLinter` when the list appears.
You can check the progress in the lower left corner of SublimeText.

**Notice, it is important you take `SublimeLinter`, and NOT `SublimeLint`.**

`SublimeLinter` requires separate linter plugin to work, so please unpack the
`<FLOWDIR>/resources/sublimetext/flow/SublimeLinter-contrib-flow.zip`
into the `Packages`.

### Settings

By default SublimeLinter package checks syntax periodically as you type. That can be controlled through
`Preferences -> Package settings -> SublimeLinter -> Settings - User` menu.

It's empty by default. Putting the following will make linter check files on load and save.

    {
      "sublimelinter": "load-save"
    }

Setting it to `"save-only"` will perform checks only after changing and saving a file.
This solves problem of long Sublime startup with many opened flow files.
Setting `"sublimelinter"` to `true` will enable periodic checks,
and setting it to `false` will disable linting.
Reference of all the linter settings for the curious is in
`Preferences -> Package settings -> SublimeLinter -> Settings - Default menu`.

It is good idea to put path to flow base directly, inside Flow plugin in file `Flow.sublime-settings`. You can use this:

    {
      "flowdir":"<FLOWDIR>",
      "rootdir": "<COMMON_ROOT_OF_ALL_PROJECTS>"
    }

If it is empty - base dir will be calculated from the path of the current file assuming that this file is nested under 
flowdir (like `c:\flow9\tools\myTool\my_tool.flow`). `"rootdir"` parameter is also optional and may be found heuristically.


## Install Flow & Lingo integration

### Windows

Go to `<FLOWDIR>/resources/sublimetext/flow/` and run `install.bat`

This will copy the `Flow` and `Lingo` folders to

    C:\Users\[UserName]\AppData\Roaming\Sublime Text 3\Packages\

as well as the `flow.py` and `lingo.py` files to

    C:\Users\[UserName]\AppData\Roaming\Sublime Text 3\Packages\SublimeLinter\sublimelinter\modules\

or the corresponding paths for Sublime Text 3.

### Mac OS X, Linux

Use `Preferences -> Browse Packages` inside Sublime Text to open the
folder where packages are stored.  
Then manually copy `Flow` and `Lingo` folders from `<FLOWDIR>/resources/sublimetext/flow/`
to that Sublime-Text-Packages folder

Sample command for Mac OS X:

    cd ~/flow9/resources/sublimetext/flow/
    cp -rp Flow Lingo ~/Library/Application\ Support/Sublime\ Text\ 3/Packages

Also copy `flow.py` and `lingo.py` from `<FLOWDIR>/resources/sublimetext/flow/`
to `SublimeLinter/sublimelinter/modules/` in Packages folder.

For F7 to work on Linux and Mac OS X, in the `resources/sublimetext/flow/Flow` folder,
edit `Flow.sublime-build` and change "compile.bat" to "compile.sh".

Also, on Linux or Mac OS X, open `Preferences -> Package Settings -> SublimeLinter -> Settings - User`
and paste:

    {
      "sublimelinter_executable_map":
      {
        "flow": "<FLOWDIR>/bin/lint.sh"
      }
    }


Also on Mac OS X, to run from the dock (or any other startup environment that's not a terminal),
edit /etc/launchd.conf to include `PATH` and `DYLD_LIBRARY_PATH` environment variables 
(see http://mark.shropshires.net/blog/setting-path-sublime-text-3-os-x).

Later versions of Mac OS X do no use `/etc/launchd.conf` file (checked with OS X 10.10.5).
Use another approach.

When new process started in Mac OS X from Spotlight or Dock, it doesn't inherit user settings,
like `$PATH`, because it is being run from system context, so it should be instructed to have env variables.

Sublime Text has mechanism for this, it allows to set up `PATH` and other env variables for build system.

Edit file `/Users/<user>/Library/Application Support/Sublime Text 3/Packages/Flow/Flow.sublime-build.mac`
and change `<user>` to your Mac OS X username.

Also change value of path and env accoringly to fit your system.
Pay attention to have full path, relative paths do not work.

    {
      "working_dir": "${project_path:${folder}}",
      "cmd": ["compile.sh", "$file_name"],
      "file_regex": "(?<file>.*\\.flow):(?<line>[0-9]*):",
      "path": "/Users/<user>/Devel/haxe:/Users/<user>/Devel/neko:/Users/<user>/Devel/flow/bin:/opt/local/bin:/opt/local/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
      "env": {
        "DYLD_LIBRARY_PATH": "/Users/<user>/Devel/neko"
      }
    }


Then rename this file to `Flow.sublime-build`. Build system should work well.

## Install the Debugger

1) Go to `Preferences -> Package Control -> Install Package -> SublimeGDB`
2) Then `Preferences -> Package Settings -> SublimeGDB -> Settings - User`
3) And paste this:

       {
          "workingdir": "<FLOWDIR>",
          "commandline": "flowcpp --debug-mi sandbox/helloworld.flow"
       }

or whatever path your flow program is at.

The `workingdir` parameter defines the root folder of your code files,
not necessarily the directory where flow is located.

The last part, `sandbox/helloworld.flow`, is the name of the flow program you want to run.
You want to change this to point to the program you are developing. 
So when you switch to develop another program, go to the `SublimeGDB` settings again 
and change the commandline for `flowcpp` to point to the other program.

Verify that `Flow.sublime-settings` file contains correct path to the the root folder of your code files too
(if `flowdir` is empty or contains wrong path, the debug will start but will show nothing in debugger windows). 
Global refactoring tools like symbol renaming require another path for working: "rootdir" - is a common root for all projects.

`Flow.sublime-settings` locations:

- Windows: `%APPDATA%\Roaming\Sublime Text 3\Packages\Flow\Flow.sublime-settings`
- Linux:   `~/.config/sublime-text-3/Packages/Flow/Flow.sublime-settings`

Restart Sublime Text to get the debugger to work.

`println()` output goes to the GDB Console window.
You can turn off word wrapping for that window by giving it focus, and then View -> Word wrap.

If your program goes into an infinite loop, you can break into it by typing

    -exec-interrupt

in the GDB command line at the bottom of the window.

### Keyboard shortcuts for debugger

- **F5**        Compile and start the program
- **Ctrl+F5**   Stop the program
- **F9**        Set break point
- **F10**       Step over line
- **F11**       Step into function call
- **Shift+F11** Step out of function call

Click on the appropriate line in the `GDB Callstack view` to go to that stack frame.
Click a variable in the `GDB Variables view` to show its children (if available).
Double click a variable in the `GDB Variables view` to modify its value.
You can also access some commands by right clicking in any view.

### Troubleshooting:

If you have a problem when debugging. i.e. debug doesn't start and you recieve a message like: `It seems you're not running gdb with the "mi" interpreter. Please add "--interpreter=mi" to your gdb command line`, then most probably it's a timeout issue.

You can try to adjust SublimeGDB settings by adding new string:

    {
      "gdb_timeout": <seconds>,
      "workingdir": "<FLOWDIR>",
      "commandline": "flowcpp --debug-mi sandbox/helloworld.flow"
    }

where seconds is a time that should be enough for compiling your program. Example:

    "gdb_timeout": 60

SublimeGDB may show a lot of messy messages in popup dialogs. It is possible to suppress them by adding setting:

    "i_know_how_to_use_gdb_thank_you_very_much": true

into `SublimeGDB.sublime-settings` file

Also, default window layout seems to be not perfect, and can be tuned by adding in the same file:

    "layout": {
      "cols": [0.0, 0.50, 0.75, 1.0],
      "rows": [0.0, 0.60, 1.0],
      "cells":
      [ // c1 r1 c2 r2
        [0, 0, 3, 1], // -> (0.00, 0.00), (1.00, 0.75)
        [0, 1, 1, 2], // -> (0.00, 0.75), (0.33, 1.00)
        [1, 1, 2, 2], // -> (0.33, 0.75), (0.66, 1.00)
        [2, 1, 3, 2]  // -> (0.66, 0.75), (1.00, 1.00)
      ]
    }

## Setup and Check Features

In main menu: `Project -> Open Project -> select <FLOWDIR>/flow.sublime-project`
This will open flow project. It is needed for all flow-related features to work properly.

You can make your own project, but it MUST be placed in `<FLOWDIR>`
To create your own project refer to Sublime documentation:

    http://www.sublimetext.com/support
    http://www.sublimetext.com/forum


This plugin provides syntax highlighting for flow files. Try to open a .flow file to see.
If it does not work, then open a `.flow` file, then do 
`View -> Syntax -> Open all with current extension as... -> flow`

Also try opening a `.lingo` file to see if highlighting is working there too.

Now, open `sandbox/hello.flow`, and go to `Tools -> Build system -> Flow` to get `F7` to 
work to do a compile check of the current file.

- Press `F7` to to save and compile the current flow file.
  If the file contains any errors, then Sublime will show the error messages inline in the editor.

- Press `shift+F7` to save, compile and run the current flow program (containing a main() function)
  using the C++ runner. 
  Use `View -> Show Console` to view the output from the compiler and flow program.  
  **`Warning`: If there is a syntax error then shift+F7 might start the previously compiled application.**

- Press `F12` to find the definition of a symbol. This only works if you open the Sublime Project 
  `flow.sublime-project` where the folder of `flow` is in the Sublime project.
  This is required so that path are correctly set up.

- Press `ctrl-t` to find the type of a local variable/expression under a cursor.
  **This feature works only with 'flowc' compiler.**

- Press `ctrl-r` to rename a symbol (function, variable or type) under a cursor.
  **This feature works only with 'flowc' compiler.**
  In case when the root folder of all projects, which will be affected by renaming,
  cannot be found by a heuristic algorithm and renaming doesn't cover all sources,
  a `rootdir` parameter should be set in `Flow.sublime-settings`.

- There is live syntax checking using `lint.bat` (or `lint.sh`).
  When you make a syntax error, a white rectangle appears, typically right after the error.
  See the lower left corner to read what the error is.

  *Note: Currently it checks syntax for all imports from `<FLOWDIR>` only.*  
  To extend it to include any project-specific directories add something similar to the `lint.bat`:

      @ECHO OFF
      set FLOW=%~dp0..
      set ROOT=%FLOW%\..
      set PROJECT=%ROOT%\project
      ! add any directory to be used for SublimeLinter syntax check
      @%~dp0..\flowtools\bin\windows\flow.exe --root . -I %FLOW%\lib -I %PROJECT% --sublime %1

  If live checking does not work, try `View -> Show console` and see if there are any error messages.
  You might have to increase the timeout allowed for background processes.

- Press `ctrl+shift+p` and type `Flow` to profile the current program.

  You can select between making 3 kinds of profiles: `time`, `instructions` or `memory`.
  1. Record the profiling and exit the program when done.
  2. Use `ctrl+shift+p` with `flow` again, and then view the profile.  
    Notice that in the view window, you can right click and choose "self rating" and other things for advanced analysis.
    *(The profile view feature requires the Java Runtime.)*

- There is syntax completion. Press `ctrl+space` to autocomplete an identifier.

- Press `ctrl+shift+p` and type `start refactor` to edit a file with rules for refactoring of flow code.
  When done adding the rule, then `ctrl+shift+p` again, and type `run refactor` and choose on what files to
  run the refactoring.

If the keyboard shortcuts doesn't work or you need to change them, have a look at

    ST3/Packages/Flow/Default (Windows).sublime-keymap

and modify the file corresponding to your OS to suit your needs.

## Tips & Tricks

To get `Ctrl+p` and `Find in Files` to work well, try `File -> Open folder` and open `<FLOWDIR>`.
We recommend you always use this.

To speed up `Find in Files` when searching for something in the source code, you can remove
auto-generated files and use something like:

    *.flow,*.markdown,*.lingo,*.sql,*.php,*.hx,*.datawarp,*.cpp,*.html,*-tmp.flow,*-ml,-out.flow,-obj,-objc

in `Where:` field.

On a Danish keyboard, it is worthwhile to add this to the Preferences, Key Bindings - User file:

    [
      { "keys": ["ctrl+\\"], "command": "show_panel", "args": {"panel": "console", "toggle": true} }
    ]

to get the console to work with `ctrl+½`.

### Auto Formatting

Sublime plugin `HTML-CSS-JS Prettify` can be handy to autoformat code.

Prerequisite is Node.js, which can be obtained from http://nodejs.org/download/

Installation through `Sublime Package Manager`:

    Ctrl+Shift+P or Cmd+Shift+P in Linux/Windows/OS X
    type install, select Package Control: Install Package
    type prettify, select HTML-CSS-JS Prettify

  Wait until completion.
  Check that `Sublime Text Menu -> Tools -> HTML-CSS-JS Prettify` is available

Customization -
- `Sublime Text Menu -> Tools -> HTML-CSS-JS Prettify -> Set Prettify Preferences`
  - Add `"flow"` to `“allowed_file_extensions": [ "js", "json", "jshintrc", "jsbeautifyrc", "flow" ]`
  - Customize other options suitably.
- `Sublime Text Menu -> Tools -> HTML-CSS-JS Prettify-> Set Plugin Options`
  - Make `"format_on_save": true`,

Flow syntax differs from js, so some additional customizations are required
(without such customizations, the formatted flow file will contain syntax errors):
Edit `beautify.js`, find "function tokenizer(input, opts, indent_string)", change the line "var punct = (":
the ? shoud be removed, "->" and "|>" should be added, so the result line will looks like
    
    var punct = ('+ - * / % & ++ -- = += -= *= /= %= == === != !== > < >= <= >> << >>> >>>= >>= <<= && &= | || ! ~ , : ^ ^= |= :: => ** -> |>').split(' ');

The file beautify.js is located in:
- Windows: `%APPDATA%\Sublime Text 3\Packages\HTML-CSS-JS Prettify\scripts\node_modules\js-beautify\js\lib\beautify.js`
- Linux:   `~/.config/sublime-text-3/Packages/HTML-CSS-JS Prettify/scripts/node_modules/js-beautify/js/lib/beautify.js`

### BracketHighlighter plugin

This section is optional, but this plugin can be very useful for functional language like flow.
It has several advantages:
- Very bright highlighting with visible style.
- Hightlight brackets for current block. There is no need to stay near bracket.
- Shortkeys for bracket navigation (go to left|right bracket)

Install plugin as any other plugins and use settings examples below.

`Menu\Preferences\Package settings\BracketHighlighter`:
- `Bracket settings` options:

      {
        // "content_highlight_bar": true,
        // "high_visibility_style": "stippled",
        // "high_visibility_color": "#00FF00FF",
        // "high_visibility_enabled_by_default": true
        "bracket_outside_adjacent": false,
        "bracket_styles": {
            "default": {
                "icon": "dot",
                "color": "region.greenish",
                "style": "solid"
            }
        }
    }

- `Key bindings - User` options:

      [
          // Go to left bracket
          {
              "keys": ["ctrl+["],
              "command": "bh_key",
              "args":
              {
                  "no_outside_adj": null,
                  "no_block_mode": null,
                  "lines" : true,
                  "plugin":
                  {
                      "type": ["__all__"],
                      "command": "bh_modules.bracketselect",
                      "args": {"select": "left"}
                  }
              }
          },
          // Go to right bracket
          {
              "keys": ["ctrl+]"],
              "command": "bh_key",
              "args":
              {
                  "no_outside_adj": null,
                  "no_block_mode": null,
                  "lines" : true,
                  "plugin":
                  {
                      "type": ["__all__"],
                      "command": "bh_modules.bracketselect",
                      "args": {"select": "right"}
                  }
              }
          },
      ]

### Additional tools

- Press `ctrl+shift+p` and type `dump uses` to run dump_uses tool for current flow file.  
  You can use either `Menu -> tools -> Flow: Dump uses` OR context menu OR `Ctrl+Alt+D` (by default)

- Press `ctrl+shift+F9` and type `formtest` to create .formtest file, containing a test usage of selected form
 (under the cursor) of current flow file.  
  You can use either `menu -> tools -> Flow: Create Formtest` for selected OR context menu OR `Ctrl+Alt+F9` (by default)


## Troubleshooting

If you get an error like

    UnicodeDecodeError: 'ascii' codec can't decode byte 0xcf in position 6: ordinal not in range(128)

when you compile, then see

http://www.sublimetext.com/forum/viewtopic.php?f=3&t=8512

(Linux)
If instead of autocompletion, Sublime Text shows weird text in popup, you might want to check your
flow/bin/ directory and check that flowcpp, flowcomplete and flow DOES NOT have '.sh' extension.
Flow.py plugin for Sublime has function ShellOrBatch, which looks for '.bat' files in Windows, and plain
names in Linux/Mac.

Here's the list of binaries and files/plugins that use them:

    SublimeLinter user settings:
      - lint(.sh|.bat)

    Flow Sublime plugin:
      - flow[.bat]
      - flowcpp[.bat]
      - flowcomplete[.bat]
      - flowprof[.bat]
      - flowsplosion.bat
      - buildswf.bat
      - runswf.bat

    Flow.sublime-build:
      - compile(.sh|.bat)

(Windows)
Sublime Text 3 has a bug https://forum.sublimetext.com/t/files-open-to-multiple-tabs-due-to-case-in-path/37136 
It leads to duplicate files in several tabs with different case in the path (drive letter)
Till bug fixed in ST, there are workaround:
we can reduce impact of the ST bug
I checked that Ctrl+P (internal ST feature) opens in capitilzed drive letter form.
The rest (debugger and find-definition) should use the same approach, so:
(dont' forget that python file use spaces and use indents to form block of code)
0) Make sure the path to your sources doesn't contain capitalized letters.
If yes, change it and reload Sublime project by closing and opening it.

    1) Find Definition:
    1.1) %APPDATA%\Sublime Text 3\Packages\Flow\Flow.py
    change flowdir function to return capitalized string by adding 
        res = res.capitalize()
    before line
        print("flowdir: finally "+res)
    1.2) in function def runcmd(self, flow_dir, cmd)
    add 
                targetFile = targetFile.capitalize()
    before 
                print ("targetFile = " + targetFile)
    
    2) Debugger:
    2.1) %APPDATA%\Sublime Text 3\Packages\SublimeGDB\resultparser.py
    change 
     return os.path.normcase(re.sub(cygwin_drive_regex, lambda m: "%s:/" % m.groups()[0], path))
    to
     return os.path.normcase(re.sub(cygwin_drive_regex, lambda m: "%s:/" % m.groups()[0], path)).replace("c:\\", "C:\\")
    2.2) %APPDATA%\Sublime Text 3\Packages\SublimeGDB\sublimegdb.py
    in def normalize(filename):
    change 
        return os.path.abspath(os.path.normcase(filename))
    to
        return os.path.abspath(os.path.normcase(filename)).capitalize()
    then restart sublime
