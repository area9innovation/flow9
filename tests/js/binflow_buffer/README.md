# Binary buffer runtime tests

With Node.js and npm available, run from the repository root:

```sh
mise install
mise exec -- npm test --prefix tests/js/binflow_buffer
```

The test harness compiles the Haxe runtime to JavaScript with the Haxe version
pinned in `mise.toml`, then runs it with Node's test runner. No npm packages or
haxelib libraries need to be installed for this suite.
