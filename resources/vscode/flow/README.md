# Flow for VS Code

This folder contains Visual Studio Code extension for flow and lingo. Structure:
 - flow - the extension source code
 - flow.vsix - compiled extension

## INSTALLATION and UPDATE
1. Launch Visual Studio Code
2. Click the Extensions bar on the left (ctrl+shift+x)
3. Click `More -> Install from VSIX...` and choose `flow.vsix`

Alternatively, run the following command line: `code --install-extension flow.vsix` or one of the `install-or-update` scripts provided. 

The extension has auto-update functionality. At every activation (aka VSCode start-up) it will check for its updates by looking at package.json in flow repository and prompt user to update. The update procedue is also automatic.

Configure the flow root folder under File->Preferences-Settings, and then "Flow configuration" and change `flow.root` to 
point to the root of Flow repo (typically `c:\area9\flow`).

Consider to download and install the font "Fira code". Then go to File -> Preferences -> Settings, Text Editor, Font, change the Font family
to "Fira code" and make sure "Font Ligatures" is checked.

https://github.com/tonsky/FiraCode/releases

Install these extensions by clicking extentions in the sidebar, and typing these names:

- GitLens
- Bracket Pair Colorizer 2

Be sure to click the "Spaces: 4" area in the bottom and change to use indentation by Tabs with size 4.

## COMMON USAGE

See if there is a `*.code-workspace` file in your project, and then open that. There might also be a
`.vscode` folder in your project, which can contain project-specific tasks and keybindings.

Use F7 to compile check the current file.
Use Shift+F7 to run the current file

Ctrl+p to open file.

Ctrl+click on compile errors to open at that point.

Double click the name of the file in the file tab to make it stay open.

Ctrl+k o to open the current file in a new window.

On Danish keyboard, ctrl+shift+½ will navigate to matching parenthesis.


## FEATURES AND CONFIGURATION
* Syntax highligting (flow, lingo, flowschema, sharekey), code snippets, and brace matching work out of the box
* There are 3 commands:
    * `flow.flowcpp` - that is also bound to F7 to type check current flow file using default compiler (flowc1 unless changed)
    * `flow.compileNeko` - that is also bound to Ctrl+F7 to type check current file using neko compiler
    * `flow.run` - that is also bound to Shift+F7 to run current file with `flowcpp`
* There are the following configuration settings found under File->Preferences-Extensions, and then "Flow configuration":
    1. `flow.root` - that shall point to the root of Flow repo (typically `c:\area9\flow`, this is also the default value)
    2. `flow.compiler` - the compiler to use. Supports same notation as in `flow.config` file - i.e. `nekocompiler`, `flowcompiler`, `flowc`, or `0`, `1`, `2`. Default is flowc, and that is fine.
    3. `flow.compilerBackend` - the backend to use for compiler. Acceptable values are `flowcpp`, `java`, `auto` (default, current best practice), `manual` (verbose command - as specified).
    4. `flow.userCompilerServer` - whether to use or not the compiler server. Only works with `flowc`
    compiler. Defaults to true.
    4. `flow.projectRoot` - force IDE to use specified path as a project root and resolve all files to run against it when running `flowcpp` command. No need to change this. Use a workspace instead. But can be useful in multi-root workspaces. Meant to be used on workspace or workspace folder level. The value is one of the following:
        * absolute path - use this path as project root
        * name of workspace folder in the workspace - always use specified workspace folder as a project root
        * relative path - treat as relative path to the first workspace folder, use as project root

* VS Code uses tasks to build projects, and they have to be set up on per-project(workspace) basis. 
The idea is that tasks define actions to be performed on the project as a whole - for example, no 
matter which file you are currently editing, to run or debug the project, you need to run the "main" 
file. You might have different compile targets - i.e. bytecode and js, or you might want to 
customize the arguments given to flowcpp when running or debugging (i.e. screen size or 
`devtrace=1`). Tasks allow to do just that. To use tasks: 
    1. Open a folder in VS Code - it will make it a workspace (best to open a repo root)
    2. Choose `Tasks -> Configure Tasks` - it will create `tasks.json` (choose external program if asked to)
    3. Copy task definition from the `tasks.json` file next to this README to your tasks.json
    4. You might want to change your tasks - i.e. always pass a single file to compile - self-explanatory how to do
* Debugging support - limited now, but breakpoints and variables (simple) are supported. To debug a program:
    1. Open a folder in VS Code - it will make it a workspace
    2. Choose `Debug -> Add Configuration...` - it will create a `launch.json` and let you choose a template to use
    3. Choose `Flow: Debug Program`
    4. Modify the flow file to launch (relative to repo/workspace root) and a name
    5. Click `F5` to launch debugger
* The following code analysis tools are supported:
    1. Jump to definition (F12) - this jumps to the declaration - i.e. an entry in the `export` 
    section. If the cursor is already on definition, jumps to declaration (like Ctrl-F12).
    2. To show the definition in popup, hover the mouse over a symbol and hold down CTRL
    3. Go to Implementation (Ctrl-F12) - this jumps to the definition
    4. Rename - experimental
 
## Requirements
Flow language tools configured in a standard layout - i.e. c:\area9\flow. There is a flow.root configuration parameter (in VS Code) to override that.

## Debug
See https://code.visualstudio.com/docs/extensions/example-hello-world .

## Build
1. Make sure Node.js, NPM and `vsce` package are all installed (i.e. `npm install -g vsce`)
2. Update the `README.md` file inside the flow folder if needed
2. Run `build.cmd` to update the `flow.vsix` package

## Release Notes
See [Changelog](./CHANGELOG.md).
