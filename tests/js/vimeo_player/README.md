# Vimeo player regressions

Requires Node.js 18 or later. The wrapper suite has no npm dependencies:

```sh
npm test --prefix tests/js/vimeo_player
```

The Flow suite also requires Java, the repository's `bin/flowc1`, and a built native
`bin/flowcpp` runner. It exercises the actual Vimeo and YouTube constructors and
subscriptions without initializing a renderer:

```sh
npm run test:flow --prefix tests/js/vimeo_player
npm run test:all --prefix tests/js/vimeo_player
```

The runner appends `size-regression.flow` to a temporary copy of the production
`material_player.flow`, compiles it to bytecode, and runs its assertions. This
keeps private helpers private and leaves repository sources untouched. Coverage
includes feedback prevention, fallback retention across reloads, late layout
availability, intrinsic dimensions taking precedence, and YouTube's original
per-message sizing behavior.

These are locally runnable checks; this change does not add a CI job.
