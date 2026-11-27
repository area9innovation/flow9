# Using flow9's mise configuration in your project

[mise](https://mise.jdx.dev) installs development tools for each project, sets env variables
and runs tasks. flow9 keeps its mise configuration in a form that your project can use too,
so that you do not repeat the tool versions, the haxelib fix and the Haxe library list.

This document has two parts:

- [Use it in your project](#use-it-in-your-project) is for you if your project compiles
  flow code.
- [Maintain it in flow9](#maintain-it-in-flow9) is for you if you change the shared files
  in flow9.

Tested with mise 2026.10.24 on Linux. macOS is not tested.

## Use it in your project

### Quick start

1. **Install mise 2026.10.6 or newer**, see
   [Getting started](https://mise.jdx.dev/getting-started.html).

2. **Check out flow9 next to your project, as `../flow9`,** locally and in CI:

   ```
   work/
   ├── flow9/
   └── your-project/
   ```

3. **Put these lines in the `mise.toml` in your project root:**

   ```toml
   min_version = "2026.10.6"
   include = ["../flow9/mise-shared.toml"]

   [task_config]
   includes = ["../flow9/mise-shared-tasks", "mise-tasks"]
   ```

4. **Run these commands in your project:**

   ```
   mise trust
   mise install
   mise run haxelib-setup
   ```

   `mise trust` is necessary one time for each checkout of your project. It also covers the
   file that you include from flow9.

5. **Compile:** `mise exec -- flowc1 your_file.flow js=out.js`. In a shell where mise is
   activated, `flowc1` is enough.

The sections below explain each line, and what goes wrong when one is missing.

### What you get

The `include` line loads flow9's `mise-shared.toml`. It gives you:

- java, haxe and neko, enough to run `flowc1` and to build every target it has;
- `FLOW`, the path of the flow9 checkout;
- `flow9/bin` on `PATH`, so `flowc1` and the other flow9 commands run from any folder;
- `HAXELIB_PATH`, set to `$FLOW/.haxelib`, see [The Haxe libraries](#the-haxe-libraries).

The `task_config.includes` line loads flow9's shared tasks. A file task is an executable
script in a task folder; mise names the task after the file. You get:

- `haxelib-setup`, which installs the Haxe libraries;
- `haxelib-patch`, which mise runs for you, see [haxelib and neko](#haxelib-and-neko).

Use both lines. With the tasks only, nothing sets `HAXELIB_PATH`, and a build does not find
the libraries that `haxelib-setup` installed. With `mise-shared.toml` only, you have no
`haxelib-setup` task in your project and must run it in flow9.

You do not get node, or the tasks that flow9's `mise.toml` defines, such as `build-flowc`.
Those are for work on flow9 itself.

### The include line

1. **Always set `min_version` next to `include`.** With it, an older mise stops with
   "version X is required" and the upgrade command.

   > **WARNING:** Without `min_version`, mise before 2026.10.6 treats `include` as an
   > unknown key and ignores it without an error. You then get none of the tools.

   `mise-shared.toml` has a `min_version` too. mise checks both, and the higher version is
   in force. When flow9 raises its own, you get the same "version X is required" message
   at your next pull of flow9, with no change to your `mise.toml`. The message names your
   `mise.toml` as the file with the error; the version in it tells you which file asks.

   The `min_version` in `mise-shared.toml` does not replace yours. A mise that is too old
   for `include` never reads `mise-shared.toml`.

2. **Keep the flow9 checkout at `../flow9`.** A symlink with that name works.

   > **WARNING:** While `../flow9/mise-shared.toml` does not exist, every mise command in
   > your project fails with "a config include must be a file". This happens when flow9 is
   > missing, has another name, or is on a commit older than this file.

3. **Remove `FLOW`, `HAXELIB_PATH`, the `flow9/bin` path entry and the java, haxe and neko
   tools from your own `mise.toml`.**

   > **WARNING:** An entry in your `mise.toml` wins over the same entry in
   > `mise-shared.toml`, without a message. A tool version that you leave there stays in
   > force when flow9 changes its own.

   To use another version on purpose, for example a newer java, put that tool in your
   `mise.toml`. `mise ls` and `mise config` show the tools from `mise-shared.toml` as tools
   of your `mise.toml`.

4. **Run `mise install` again after you pull flow9.** The tool versions come from the flow9
   commit that you have checked out. Nothing pins flow9's commit from your project.

### The task_config line

1. **Keep your own task folder in the list, and list it last.**

   > **WARNING:** `includes` replaces mise's default task folders. If `"mise-tasks"` is not
   > in the list, your own file tasks disappear from `mise tasks ls`, without an error.

   When two folders have a task with the same name, mise runs the one from the folder
   listed last. With your folder last, your task wins.

2. **Write the paths literally, relative to your project root.** A path can start with
   `{{ config_root }}`.

   > **WARNING:** mise reads `includes` before `[env]` and before `include`. So
   > `"{{ env.FLOW }}/mise-shared-tasks"` fails with "Field `FLOW` is not defined".

You get every file task in the folder. You cannot select single tasks.

### The Haxe libraries

flowc passes libraries to haxe with `-lib` for the JavaScript targets (`js=`, `es6=`,
`nodejs=1`, `html=`, `ts=`). `mise run haxelib-setup` installs them.

1. **Run `mise run haxelib-setup` before the first build, and after you pull flow9.** In
   CI, make your build task depend on it.

   The task installs the libraries listed in `flow9/mise-shared-tasks/haxelib.txt` into
   `flow9/.haxelib`. It keeps a copy of the list that it installed, and does nothing while
   `haxelib.txt` is equal to that copy. To install everything again, delete
   `flow9/.haxelib`.

2. **Keep no library list and no `.haxelib` folder in your project.** The libraries are
   with the compiler that asks for them, one set for each flow9 checkout. All projects next
   to that checkout use the same set. The list holds every library that any `flowc1` target
   needs, not only the ones that your project uses.

   > **WARNING:** haxelib uses a `.haxelib` folder in the current directory or any parent
   > before it looks at `HAXELIB_PATH`, and gives no message. A build then uses the
   > libraries in that folder, whatever `haxelib.txt` says. Delete such a folder from your
   > project. `haxelib-setup` prints a warning when it finds one in the folder that you run
   > it from, or in a parent.

3. **Compile through mise**, with `mise exec --` or in a shell where mise is activated.
   Without mise, nothing sets `HAXELIB_PATH`, and haxe looks for the libraries in your
   personal haxelib folder.

### haxelib and neko

You have nothing to do here: `mise install` does it. This section explains what you see.

haxe runs `haxelib path` for every `-lib`. haxelib comes with haxe, but it needs `libneko`
from neko, a separate release, and cannot find it by itself. The haxe tool in
`mise-shared.toml` therefore runs `haxelib-patch` as its `postinstall`, on every
`mise install`. `haxelib-patch` renames haxelib to `haxelib.bin` and puts a wrapper in its
place. The wrapper sets `LD_LIBRARY_PATH` for haxelib only, not for your shell. After a good
run, `mise install` prints a line that starts with `haxelib ->`.

Run `mise install` after the haxe or neko version changes, so that the wrapper points at the
new neko. Do not rely on `mise exec` or `mise run` to install a missing haxe: only
`mise install` is tested to run the `postinstall`.

### Problems

| What you see | What to do |
|---|---|
| "a config include must be a file" | Check out flow9 at `../flow9`, on a commit that has `mise-shared.toml`. |
| "version X is required" | Upgrade mise with the command in the message. |
| "Config files in ... are not trusted" | Run `mise trust` in your project. |
| haxelib cannot find `libneko` | Run `mise install`, or `mise run haxelib-patch`. |
| `haxelib-patch` reports that `haxelib.bin` is gone | Reinstall haxe: `mise install -f github:HaxeFoundation/haxe`. |
| "Repository ... does not exist. Please run `haxelib setup` again" | `flow9/.haxelib` is missing. Run `mise run haxelib-setup`, not `haxelib setup`. |
| haxe reports "Library ... is not installed" | Run `mise run haxelib-setup`. If it prints a warning about a `.haxelib` folder, delete that folder. |

## Maintain it in flow9

To work on flow9 itself, run `mise install` and `mise run haxelib-setup` in the flow9
checkout. flow9's `mise.toml` includes `mise-shared.toml` and lists `mise-shared-tasks`, the
same way a project does, so flow9 uses the one copy too.

A change to the shared files reaches every project that includes them, at that project's
next pull of flow9. The rules below keep those projects working.

### Change mise-shared.toml

1. **Put in `mise-shared.toml` only what every project that compiles flow needs.** A tool
   for work on flow9 itself, such as node, goes in `mise.toml`.

2. **Use only the keys that mise accepts in an included file:** `[env]`, `[tools]`,
   `[vars]`, `[hooks]`, `min_version` and the alias, plugin and wrapper tables. This is the
   reason for two files: `[tasks]`, `task_config`, `[settings]` and a nested `include` stay
   in `mise.toml`.

   > **WARNING:** Any other key makes mise fail with "invalid config include", in flow9
   > and in every project that includes the file.

3. **Refer to files in flow9 through `$FLOW`, never through `{{ config_root }}` or
   `$MISE_CONFIG_ROOT`.**

   > **WARNING:** Inside an included file, `{{ config_root }}` is the root of the project
   > that includes it, not flow9. This is also true inside `postinstall.run`. A path built
   > on it points into the wrong checkout, and works only when you test in flow9.

   A tool's `postinstall` sees the `[env]` of `mise-shared.toml`. So
   `bash "$FLOW/mise-shared-tasks/haxelib-patch"` works from every project.

4. **Raise `min_version` in `mise-shared.toml` when the file starts to use a feature of a
   newer mise.** Every project that includes the file then stops with "version X is
   required" until its mise is new enough. To announce a raise before you enforce it, use
   `min_version = { hard = "<current>", soft = "<next>" }`: mise prints "version X is
   recommended" and continues.

   Keep `min_version` in flow9's `mise.toml` as well, for the same reason as in any
   project: it is the only line that a mise without `include` reads.

### Add a task to mise-shared-tasks

`task_config.includes` takes whole folders, so the folder is how flow9 chooses what other
projects get. Put a file task in `mise-shared-tasks` only when another project can use it.
Put a task for flow9 only in `mise.toml`, or in a `mise-tasks` folder; flow9's `mise.toml`
lists both folders.

1. **Find the task's own files through the task's location**, such as
   `"$(dirname "${BASH_SOURCE[0]}")"` or `$MISE_TASK_DIR`. mise runs the task with the
   working directory set to the root of the project that runs it.

2. **Do not use `#MISE sources=` or `outputs=` with a relative path.** Let the script decide
   by itself whether there is work to do, as `haxelib-setup` does.

   > **WARNING:** mise resolves these paths against the project that runs the task, not
   > against flow9. A path to a file in flow9 then matches nothing, or matches a file of
   > the same name in the project, and mise skips the task with "sources up-to-date".

3. **Test the task from a second folder that includes `mise-shared-tasks`,** not only in
   flow9. Both mistakes above work in flow9 and fail only from another project.

### Change the Haxe library list

1. **Edit `mise-shared-tasks/haxelib.txt`, and make the same change in
   `.devcontainer/Dockerfile`.** The Dockerfile has its own `haxelib install` lines, because
   the dev container does not use mise.

2. **Add a library when any flowc target starts to ask for it.** The list is for all
   projects, so a library that only one of them uses still belongs here. A library too many
   costs a download; a missing one fails a build.
