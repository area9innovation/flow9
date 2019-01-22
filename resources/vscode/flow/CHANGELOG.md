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