# Change Log

## 0.0.1
- Initial release. Only syntax and snippets

## 0.0.2
- Debugger support (limited)

## 0.0.7
- Fixed incorrect debug template
- flow compiler defaults to flowc

## 0.0.8
- Enable multi-root workspace support

## 0.0.11
- Better documentation, example in tasks.json for both compilers
- Better problem matchers

## 0.0.12
- auto-update fixed
- dumping cwd and command line for flowcpp command

## 0.0.13
- new parameter - flow.compilerBackend
- printCalls renamed to print_calls
- debugger_args is now string

## 0.0.14
- get rid of bogus debug output

## 0.0.15
- add auto update watcher - whenever package.json changes, vscode shall fire an auto update prompt

## 0.0.16
 - debugger allows to set breakpoints while running the program

## 0.1.0
 - Find Definition added (using a language server proxying to flowc1)

## 0.1.1
 - Go to Implementation, Find all References, Go to Type Definition added

## 0.1.2
 - Rename added

## 0.1.3
 - Crash in Find Definition fixed
 - Find Definition works when cursor is at the end of word

## 0.1.4
 - Do not produce bytecode when typechecking (F7)
 - Do not create a new output channel every time upon F7

## 0.1.5
 - add commands for neko typecheck (Shift-F7) and run current file (Ctrl-F7)
 - fixed breakpoints in debugger

## 0.1.6
 - pump compiler errors from F7 and friends to the Problems tab
 - run flowc1 in the server mode to speed up code analysis

## 0.1.7
 - support Go to Implementation
 - F7 keeps focus in editor

## 0.1.8
 - support for Flowschema
 - F12 can jump back and forth between definition and declaration

## 0.1.10
 - automatically shutdown flowc when vscode exits
 - better token parsing

## 0.1.11
 - re-built with upgraded component versions due to security vulnerability

## 0.1.12
 - added support for `with` operator
 - partial support for flow.userCompilerServer setting

## 0.1.13
 - better way to shutdown `flowc` when exiting

## 0.2.0
 - update for new flow9 repository

## 0.2.1
 - added command flow.updateFlowRepo to stop flowc, update flow repo, start flowc

## 0.2.2
 - fixed debugger for one available local variable

## 0.2.3
 - fixed debugger for stack arguments

## 0.2.4
 - fixed debugger for multiple stack arguments

## 0.2.5
 - additional diagnostics for find-definition, less verbose for others

## 0.2.6
 - make find definition use folder with nearest flow.config as cwd

## 0.3.0
 - enable structured variable support in debugger

## 0.3.1
 - make debugger return all stack frames, not first 20

## 0.3.2
 - separate scopes for Arguments and Locals
 - frame navigation works
 - older unused code removed
 - watch expressions work

## 0.3.3
 - added debugging logging to language server

## 0.3.4
 - added support for outline
 - flow server is managed by extension, not language server

## 0.3.5
 - make an option to disable outline for performance reasons
 - turn off server logging
 - mark exported functions as Interfaces, and exported structs as Classes

## 0.3.6
 - small crash in language server fixed
 - fix syntax highlighting in strings with %

## 0.4.3
 - a new LSP server (native flowc) is added.
 - area9 logo is added

## 0.4.4
 - commands to start/stop http server are added.
 - commands to choose flow/JS LSP server are added.
 - status of http and LSP servers are added to statusbar.

## 0.4.5
 - instant syntax check at typing is implemented.

## 0.4.6
 - flow interactive console is added.

## 0.4.7
 - another LSP server is added (flowc_lsp), choice of LSP servers is modified.

## 0.4.8
 - command 'execCommand' on execution of a general command (like server-cache-info=1) on server is added.
 - http server status displays main memory stats: Used, Free and Total memory.

## 0.4.9
 - 'runUI' command is added: runs a visual application, compiled to html+js, in webview panel.

 ## 0.4.10
 - obsolete LSP modes (JS and flowc-based) are removed.

 ## 0.4.11
 - more concise format of server memory state is used.

 ## 0.4.12
 - html files are placed in the www2 directory in the nearest directory with flow.config file.

## 0.4.13
- a test editor written in flow is added. Readme is updated with instructions how to implement a custom editor written in flow.

## 0.5.0
 - flow notebook, based on Vscode Notebook API, is added.

## 0.5.1
 - syntax highlighting for gringo language is added.

## 0.5.2
 - syntax highlighting for lingo language is enhanced.

## 0.5.3
 - syntax highlighting for datawarp
 - syntax highlighting for blueprint strings in flow
 - syntax highlighting for lingo and sharekey is enhanced
 - do not run REPL without notebook
 - error handling fixed
 - use pretty print JSON in `noteflow` files, represent a multi-line string as an array

## 0.5.4
 - compound expressions and folding on hover and watch

## 0.6.0
 - [PR #1141](https://github.com/area9innovation/flow9/pull/1141)
 - Find definition and Hover for local variables
 - Updated dependencies
 - Improved verbose mode

## 0.6.1
 - Updated syntax highlighting for flow and sharekey

## 0.6.1
 - Highlight SQL and flow code inside <<>> strings
