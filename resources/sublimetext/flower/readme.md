## Flower - Flow Extensible Runner for Sublime Text 3 `(19.1c)`

### What is Flower?

Flower aims to provide hassle-free Flow developer experience for Sublime Text 3.

It is easy to install & comes with batteries, such as:

- Syntax definitions for Flow & Lingo;

- Auto-configuration of Linter & Debugger for Sublime Text;

- Auto-location of `flow.config` files to provide all necessary settings for running your project;

- Auto-location of root repository path;

- `F12` (Find definition) works on imports and with multiple cursors, shows definition inline;

- `F8` shows up quick menu to easily select Preset & Runner for the run:  
  - **Presets** define parametrized file runs: for local test / for product / for another project;  
  - **Runners** define ways to run presets: check, debug, run as cpp version or compile to js & open it up in browser;  

- Debugger is configured automagically - just install `SublimeGDB` package and run it with `Ctrl+F5`  
    - **Please note that SublimeGDB is not officially supported for ST3, so it may occassionally freeze editor**  

However, `flower` lacks certain features which are present in older `flow` plugin:

- autocompletion
- profiling
- refactoring
- lookup/rename symbol


### Installation & setup

1. Check that you have `flow/bin` path set in `PATH` environment variable:

    Windows: Computer properties - Advanced System Settings - Environment Variables.  
    Linux: Export paths in `.profile`, not just `.bashrc`.  
    Type `flow` or `flowcpp` in terminal to see if it works.  
    Type `import os; os.environ['PATH']` in Sublime Text console to see if paths are loaded in editor.  

2. Install the newest stable Sublime Text 3.1+

    Use *Linux repos* if you're on linux, instead of tarballs.

3. Install [**Package Control**](https://packagecontrol.io/installation)

4. Install **SublimeGDB** & **SublimeLinter** packages (`Package Control: Install Package`)

5. Open `Packages` folder (`Preferences - Browse Packages..`) 
   and remove old `Packages/Flow` plugin folder.  
    Do the same for `SublimeLinter-contrib-flow` if you have it  
    **Make sure to move them out of the `Packages/` folder completely**

6. Copy the `sublimetext/flower` as `Packages/flower` folder.

      Alternatively, you can create a symbolic link to always get the newest version.  
      On Linux:

       cd /home/user/.config/sublime-text-3/Packages/
       ln -s <repo>/flow9/resources/sublimetext/flower flower

      On Windows same can be achieved with `mklink`, see
      [guide](https://www.howtogeek.com/howto/16226/complete-guide-to-symbolic-links-symlinks-on-windows-or-linux/).

7. Modify settings (`Preferences: Flower Settings - User`):

    Set `repo` path parameter to the root location of your repositories if it's not auto-located
    from `<repo>/flow9` folder (default: `C:/`, i.e. `"repo": "C:/"`)

8. Modify keybindings if needed (`Preferences: Flower Key Bindings - User`)

9. Check messages in ST console (`` ctrl+` ``) if something is wrong. If you see `flower loaded` message
   on startup then you're good to go!

### Default keybindings

##### F12 - Find definition

   Finds definition of any token or imported module in source.  
   Works on import statements.  
   Works with multiple cursors - [Shortcuts](https://gist.github.com/dufferzafar/7673209)  
   Shows inline phantom with definition and buttons:

   - `🔻` - close all phantoms
   - `🔽` - close current phantom
   - `📋` - paste definition on line below
   - click on the definition will open its file

##### F8 - Show Flower quick panel

   Opens a panel to select Preset & Runner.

##### F7 - Compile current file

   Compiles `.bytecode` and `.debug` to see if the file can compile.  
   Use `F4/Shift+F4` to navigate errors in output panel.  

##### F10 - Run current file with QtByteRunner

   Compiles `.bytecode` and runs it with `flowcpp`.

##### Ctrl+F10 - Run current file with JS

   Compiles `.js`, puts it into `binaryfolder` and opens `url` in new browser tab.

##### Ctrl+F5 - Debug runner

   Overrides SublimeGDB `commandline` & `workingdir` settings with correct values and runs debugger.  
   Use `Ctrl+F5` again to close the debug session and restore editor layout.  

##### Ctrl+F8 - Show Build Panel

   Handy shortcut for `Tools - Build Results - Show Build Results`.


### Advanced Usage Tips

- You can just comment `name` or `main`/`cmd` in preset/runner to hide it from the quick list.

- Global `binaryfolder` setting will be used unless overridden in Preset. Defaults to working dir if not specified at all.

- Global `url` setting will be used for `"after": "web"` runners unless overridden in Preset.

- Typical key binding looks like so:

    `{ "keys": ["f7"], "command": "run_flow", "args": {"action": "js", "current": true} }`

    or

    `{ "keys": ["f7"], "command": "run_flow", "args": {"runner": "check", "current": true} }`

    Where:

    `"action": "js"` - selects `"js"` action to run file with; can be replaced with `"runner"`;  
      - *possible actions: compile, js, js_debug, cpp, debug.*  
    `"runner": "check"` - selects `"check"` runner specified in settings, case-insensitive;  
    `"preset": "myPreset"` - selects `"myPreset"` preset specified in settings, case-insensitive;  
    `"current": true` - selects current file as a preset, ignored if preset is present;  


### FAQ

**Q: I get error: ` Error loading syntax file "Packages/Flow/Flow.tmLanguage": Unable to open Packages/Flow/Flow.tmLanguage`**  
**A:** Sublime Text assigns syntax for each opened file, and since the old plugin was moved away, path was changed.  
       Close & Reopen all files or set new syntax with `Set Syntax: Flow` command.  

**Q: I get error on compilation: `Could not find <component>/<component>.flow. Use -I <path>`**  
**A:** Most likely this file's `flow.config` doesn't have this component in includes section.
       Open context menu with right-click and select `Open flow.config` to check.

**Q: In console I see that `flow9/bin/lint*` is run, but linter highlights every line as error!**  
**A:** That should never happen since plugin doesn't depend on `flow/bin/lint*` batch files.
       Make sure that you don't have `SublimeLinter-contrib-flow` package.

**Q: Linter works only when file is saved. How to lint code in the background?**  
**A:** Old linter/compiler works with files, so it's not possible to check source on the fly.

**Q: Lint error text is shown in status only when cursor is on the beginning of a line.
     How to make it show text in status when cursor is anywhere on this line?**  
**A:** This happens with old linter/compiler, which doesn't provide error column.
       Add this to `SublimeLinter` config: `"no_column_highlights_line": true`


### Changelog

#### 19.1c

- Fixed F8 menu not opening for empty file

#### 19.1b

- Fixed reading malformed `flow.config`.
- Fixed finding `flow.config` in current directory.


#### 19.1a

- Added `old_linter_path` config variable.

#### 19.1

- New year release for flow9!
