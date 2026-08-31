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
change fail visibly instead of silently overwriting newer code. Patches are
checked with `git apply --check --whitespace=error-all` before they are applied.

Two enabled mods cannot currently modify the same target file. This conservative
rule keeps load order explicit and prevents a successful build whose behavior
depends on patch coincidence. Dependencies are applied before dependents; user
load order resolves the remaining order.

`commands` declares executables that must be available before composition.
`permissions` is review metadata shown to the user. It is not a sandbox or an
authorization mechanism: installed QML runs with the user's permissions.

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

The same operations are available in **Settings → Mods**.

## Example

`examples/mods/compact-player-volume-scroll` packages the compact-player volume
scroll change as a patch-only mod. It is intentionally small: the same patch can
be reviewed for upstream inclusion or installed through the manager without
editing the base checkout.
