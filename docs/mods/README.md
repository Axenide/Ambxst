# Ambxst mod packages

Ambxst mods are declarative source transformations. A package contains an
`ambxst.mod.json` manifest, payload files, and optional unified patches. The
manager composes enabled packages onto a clean Ambxst source tree and commits
the active generation in one atomic state-file update after every operation
succeeds.

The manager does not poll repositories or run a resident worker. It reads local
state when requested, accesses the network only for an explicit install or
update, and builds a generation only when the enabled set or load order changes.

## Package layout

```text
example-mod/
├── ambxst.mod.json
├── settings.json
├── patches/
│   └── feature.patch
└── payload/
    └── Feature.qml
```

Packages can be installed from a local directory, a `.zip`, `.tar`, `.tar.gz`,
or `.tgz` archive, or a Git URL. New packages are always disabled. Archive
extraction rejects links, path traversal, more than 10,000 entries, and expanded
content over 128 MiB.

Update pulls a Git source with fast-forward only. Local-directory and archive
packages are reloaded from their original path. The old package is restored if
the replacement fails validation or generation composition.

## Manifest

```json
{
  "$schema": "https://raw.githubusercontent.com/Axenide/Ambxst/dev/docs/mods/manifest.schema.json",
  "manifestVersion": 1,
  "id": "org.example.feature",
  "name": "Example feature",
  "version": "1.0.0",
  "description": "Adds one focused shell feature.",
  "license": "MIT",
  "author": "Example contributor",
  "compatibility": {
    "api": 1,
    "ambxst": ">=1.2.0 <1.3.0",
    "testedBaseCommits": ["full-git-commit"]
  },
  "dependencies": [],
  "dependencySources": {},
  "conflicts": [],
  "commands": [],
  "permissions": ["Reads active media state"],
  "settings": {
    "schema": "settings.json"
  },
  "operations": [
    {
      "type": "overlay",
      "source": "payload/Feature.qml",
      "target": "modules/example/Feature.qml"
    },
    {
      "type": "patch",
      "source": "patches/feature.patch"
    }
  ]
}
```

An overlay can add a file. Replacing an existing file also requires
`"replace": true` and the current target's `expectedSha256`. This makes a base
change fail visibly instead of silently overwriting newer code.

Operations are applied in load order. A patch is first tried with
`git apply --check --whitespace=error-all`. Exact context rarely survives real
use: an earlier mod edits the same file, or Ambxst itself moves the lines a
patch was written against. So a patch that does not apply verbatim is retried
as a three-way merge against the pre-image blob recorded in the diff. The
composition runs in a temporary Git repository that borrows the base object
store, which keeps those blobs reachable after an Ambxst update. That repository
is deleted before the generation is activated, so a generation is plain source.

Two mods that only insert new lines at the same anchor are both kept, in load
order; this is what lets independent bar widgets register next to each other.
Two mods rewriting the same existing lines still stop the build, and the active
generation remains unchanged. Overlay replacements still verify the target
checksum at the point where they run. Dependencies are applied before
dependents; user load order resolves the remaining order.

A mod that adds a Settings section must claim a new `section` id and register
its panel under the same id. Renumbering the existing sections looks harmless in
one package and breaks as soon as a second package does it: the sidebar and the
panel list drift apart, and an entry opens somebody else's panel.

`compatibility.ambxst` is a hard requirement: a mod outside the range is never
built. `compatibility.testedBaseCommits` is advisory. The base moves with every
Ambxst update, so an unlisted revision only marks the package as untested in
Settings; composition, the health window, and rollback remain the real guards.

`author`, `authorUrl`, `homepage`, and `license` are shown before anything is
installed or enabled. Fill them in: the confirmation prompt is where a user
decides whether to trust the code, and an anonymous package gives them nothing
to check.

A manifest key this Ambxst does not know is reported in the package status and
otherwise ignored, so metadata added to the format later does not break older
installs.

`commands` declares executables that must be available before composition.
`permissions` is review metadata shown to the user. It is not a sandbox or an
authorization mechanism: installed QML runs with the user's permissions.

Required mods are listed by ID in `dependencies`. A distributable package can
also map a dependency ID to its package repository in `dependencySources`:

```json
"dependencies": ["community.i18n"],
"dependencySources": {
  "community.i18n": "https://github.com/example/ambxst-mod-i18n.git"
}
```

Settings shows missing and disabled requirements before the mod can be enabled.
It downloads them only after the user chooses **Install required mods**. The
source package must declare the expected ID; a different manifest is rejected.

The package source field accepts a local directory, an archive, a Git repository,
or a GitHub directory URL such as
`https://github.com/owner/repository/tree/main/packages/example`. GitHub directory
installs use a shallow sparse checkout and retain the original URL for updates.

## Settings schema

Mod settings use data, not package-provided settings UI. This keeps the Settings
surface native and prevents arbitrary controls from running before a mod is
enabled.

```json
{
  "$schema": "https://raw.githubusercontent.com/Axenide/Ambxst/dev/docs/mods/settings.schema.json",
  "version": 1,
  "fields": [
    {
      "key": "showLabel",
      "label": "Show label",
      "description": "Display a label next to the indicator.",
      "type": "boolean",
      "default": true,
      "restartRequired": false
    },
    {
      "key": "limit",
      "label": "Item limit",
      "type": "integer",
      "default": 5,
      "minimum": 1,
      "maximum": 20,
      "restartRequired": true
    }
  ]
}
```

Supported field types are `boolean`, `string`, `integer`, `number`, and `enum`.
Enum fields require an `options` array with `label` and `value` strings.

Enabled QML can read its values without polling and react to changes through the
native service:

```qml
import qs.modules.services

Component.onCompleted: ModsService.getSettings("org.example.feature", (settings, error) => {
    if (!error)
        applySettings(settings.values);
})

Connections {
    target: ModsService
    function onSettingChanged(modId, key, value) {
        if (modId === "org.example.feature")
            applySetting(key, value);
    }
}
```

## Activation and recovery

Each change creates an immutable generation under
`$XDG_DATA_HOME/ambxst/mods/generations`. The active generation changes
atomically in `$XDG_CONFIG_HOME/ambxst/mods.json`. The existing shell keeps
running until the user restarts Ambxst.

On the next start, the daemon gives the new generation an eight-second health
window. If Quickshell exits during that window, Ambxst restores the last
known-good generation and starts it immediately. After the window closes, no mod
health timer or worker remains active. `AMBXST_MODS_DISABLED=1 ambxst` bypasses
the active generation for manual recovery.

Ambxst also compares the generation metadata with the current base version and
Git revision before launch. After a base update, a stale generation is skipped
and the clean base starts. Settings then reports that a rebuild is required.

`ambxst update` does that rebuild itself: once the new source is in place it
re-composes the enabled set, prints any mod whose declared compatibility no
longer matches, and only then restarts. A mod whose patch cannot be merged onto
the new source stops its own build, and Ambxst starts on the clean base rather
than on a half-applied tree.

## Commands

```bash
ambxst mods list
ambxst mods install ./example-mod
ambxst mods enable org.example.feature
ambxst mods move org.example.feature up
ambxst mods update org.example.feature
ambxst mods rebuild
ambxst mods rollback
ambxst mods disable org.example.feature
ambxst mods remove org.example.feature
```

The same operations are available in **Settings → Mods**. Switch the list to
**Sort: Load order**, then drag the handle beside a package to place it at an
exact position. The manager rebuilds enabled packages in that order; the new
generation takes effect after Ambxst restarts.

## Example

`examples/mods/compact-player-volume-scroll` packages the compact-player volume
scroll change as a patch-only mod. It is intentionally small: the same patch can
be reviewed for upstream inclusion or installed through the manager without
editing the base checkout.
