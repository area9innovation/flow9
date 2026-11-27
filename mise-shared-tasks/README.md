# Using flow9's mise configuration in your project

Your project can use the same tools, env variables and tasks as flow9, from one copy:

- To get the tools and env variables, include `../flow9/mise-shared.toml` with a top-level
  `include`. See [Tools and env variables](#tools-and-env-variables).
- To get the file tasks, list `../flow9/mise-shared-tasks` in `task_config.includes`. See
  [Tasks](#tasks).

Each of the two works without the other. Check out flow9 next to your project, as
`../flow9`, locally and in CI:

```
work/
├── flow9/
└── your-project/
```

## Tools and env variables

mise loads configuration from another file only through the top-level `include` key. In an
included file, mise accepts fewer keys than in `mise.toml`. For example, `[tasks]` is not
allowed there. For this reason flow9 splits its configuration in two files:

- `mise-shared.toml` holds the flow toolchain and its env variables. Your project can
  include it.
- `mise.toml` includes `mise-shared.toml` and adds what only flow9 needs: node and flow9's
  own tasks.

flow9's `mise-shared.toml` gives you:

- java, haxe and neko, enough to run `flowc1` and to build every target it has;
- `FLOW`, the path of the flow9 checkout;
- `flow9/bin` on `PATH`, so `flowc1` and the other flow9 commands run from any folder;
- `HAXELIB_PATH`, see [haxelib](#haxelib).

### Include flow9's mise-shared.toml

1. **Put these lines at the top of your `mise.toml`:**

   ```toml
   min_version = "2026.10.6"
   include = ["../flow9/mise-shared.toml"]
   ```

   mise reads local files in `include` from 2026.10.6 on. With `min_version`, an older mise
   stops with "version X is required" and the upgrade command.

   > **WARNING:** Always set `min_version` next to `include`. Without it, mise before
   > 2026.10.6 treats `include` as an unknown key and ignores it without an error.

2. **Keep the flow9 checkout at `../flow9`.** `mise-shared.toml` sets `FLOW` to
   `../flow9`, relative to your project root, unless your project is flow9 itself.

   > **WARNING:** With the sibling under any other name, every mise command in your project
   > fails with "failed to parse template ... NotFound". A `FLOW` in your own `[env]` does not
   > prevent this. A symlink named `../flow9` works.

3. **Remove `FLOW`, `HAXELIB_PATH`, the `flow9/bin` path entry and the java, haxe and neko
   tools from your own `mise.toml`.** An entry that you keep there wins over the one in
   `mise-shared.toml`, so a leftover pin stays in force without a message.

   `mise ls` and `mise config` show the tools from `mise-shared.toml` as tools of your
   `mise.toml`.

### Change flow9's mise-shared.toml

If you maintain flow9, follow these rules.

1. **Put in `mise-shared.toml` only what every project that compiles flow needs.** A tool
   for work on flow9 itself, such as node, goes in `mise.toml`.

2. **Use only the keys that mise accepts in an included file:** `[env]`, `[tools]`,
   `[vars]`, `[hooks]`, `min_version` and the alias, plugin and wrapper tables. Any other
   key, a nested `include` too, makes mise fail with "invalid config include". This happens
   in flow9 and in every project that includes the file.

3. **Refer to files in flow9 through `$FLOW`, never through `{{ config_root }}` or
   `$MISE_CONFIG_ROOT`.**

   > **WARNING:** Inside an included file, `{{ config_root }}` is the root of the project
   > that includes it, not flow9. This is also true inside `postinstall.run`. A path built on
   > it points into the wrong checkout.

   A tool's `postinstall` sees the `[env]` of `mise-shared.toml`. So
   `bash "$FLOW/mise-shared-tasks/haxelib-patch"` works from every project.

## Tasks

flow9 keeps the file tasks that other projects can use in the `mise-shared-tasks` folder:
`haxelib-setup` and `haxelib-patch`, see [haxelib](#haxelib). `task_config.includes` takes whole
folders, so a separate folder is how flow9 chooses what you get. You do not get the inline
tasks in flow9's `mise.toml`, such as `build-flowc`.

### Use flow9's tasks

1. **List `../flow9/mise-shared-tasks` in `task_config.includes`, together with your own folder:**

   ```toml
   [task_config]
   includes = ["../flow9/mise-shared-tasks", "mise-tasks"]
   ```

   You get every file task in the folder. You cannot select single tasks. When two folders
   have a task with the same name, mise runs the one from the folder listed last, so list
   your own folder last.

   > **WARNING:** `includes` replaces mise's default task folders. If you remove
   > `"mise-tasks"` from the list, your own file tasks disappear.

   > **WARNING:** Write the paths literally, relative to your project root, or start them with
   > `{{ config_root }}`. mise renders `includes` before `[env]` and before `include`. So
   > `"{{ env.FLOW }}/mise-shared-tasks"` fails with "Field `FLOW` is not defined".

### Add a task to flow9's mise-shared-tasks

If you maintain flow9, put a file task in `mise-shared-tasks` only when another project can
use it, and write it so that it works from there. Put a task for flow9 only in `mise.toml`, or
in a `mise-tasks` folder; flow9's `mise.toml` lists both folders in `task_config.includes`.

1. **Find the task's own files through the task's location**, such as
   `"$(dirname "${BASH_SOURCE[0]}")"` or `$MISE_TASK_DIR`. mise runs the task with the
   working directory set to the root of the project that runs it.

2. **Do not use `#MISE sources=` or `outputs=` with a relative path.**

   > **WARNING:** mise resolves these paths against the project that runs the task, not
   > against flow9. A path to a file in flow9 then matches nothing, or matches a file of the
   > same name in the project, and mise skips the task with "sources up-to-date".

   Let the script decide by itself whether there is work to do, as `haxelib-setup` does.

## haxelib

haxe runs `haxelib path` for every `-lib`, so a build with Haxe libraries needs two things:
a haxelib that starts, and the libraries installed. flow9 provides a task for each.

1. **Run `mise install`.** The haxe tool in `mise-shared.toml` runs `haxelib-patch` as its
   `postinstall`, on every `mise install`. You do not run the task yourself.

   haxelib comes with haxe, but it needs `libneko` from neko, a separate release, and cannot
   find it by itself. `haxelib-patch` renames haxelib to `haxelib.bin` and puts a wrapper in
   its place. The wrapper sets `LD_LIBRARY_PATH` (Linux) or `DYLD_LIBRARY_PATH` (macOS) for
   haxelib only, not for your shell.

2. **Run `mise run haxelib-setup`.** It installs the libraries listed in
   `flow9/mise-shared-tasks/haxelib.txt` into `flow9/.haxelib`. Run it in flow9, or in your project
   when you include `../flow9/mise-shared-tasks`. In CI, make your build task depend on it.
   `haxelib-setup` keeps a copy of the list that it installed, and does nothing while
   `haxelib.txt` is equal to that copy. To install everything again, delete `flow9/.haxelib`.

   `mise-shared.toml` sets `HAXELIB_PATH` to `$FLOW/.haxelib`. The libraries are with the
   compiler that asks for them, one set for each flow9 checkout, and your project needs no
   list and no `.haxelib` of its own. The list holds every library that any `flowc1` target
   needs, not only the ones your project uses.

   > **WARNING:** A `.haxelib` folder in the current directory or any parent wins over
   > `HAXELIB_PATH`, without a message. Delete such a folder from your project.

   > **WARNING:** While `flow9/.haxelib` is missing, every haxelib command fails with
   > "Repository ... does not exist. Please run `haxelib setup` again". Do not run
   > `haxelib setup`; run `mise run haxelib-setup`.

3. **If haxelib reports that it cannot find `libneko`, run `mise run haxelib-patch`.** If the
   task reports that `haxelib.bin` is gone, reinstall haxe:
   `mise install -f github:HaxeFoundation/haxe`.

4. **To change a library or its version, edit `mise-shared-tasks/haxelib.txt` in flow9, and
   make the same change in `flow9/.devcontainer/Dockerfile`.** The Dockerfile has its own
   `haxelib install` lines, because the dev container does not use mise.
