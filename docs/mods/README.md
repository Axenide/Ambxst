# Ambxst mod packages

Ambxst mods are declarative source transformations. A package contains an
`ambxst.mod.json` manifest, payload files, and optional unified patches. The
manager composes enabled packages onto a clean Ambxst source tree and commits
the active generation in one atomic state-file update after every operation
succeeds.

Repository checks run on request or on an optional schedule. Scheduled checks
and automatic installation are separate settings, both off for new users.
The existing daemon handles background work without a separate process.
Opening Settings does not trigger a network check.

## Using the manager

Open **Settings > Mods**. The **Mod guide** link opens this document.
Install a package, inspect its author and declared permissions, then enable it.
New packages stay disabled until you choose to enable them.

Use **Check for updates** to prepare candidates for all installed mods, or
**Check for updates** in a mod's details to check that package. Expand **Review updates**
to inspect versions, exact revisions, affected files, dependencies, and declared
permissions. **Apply reviewed updates** applies the prepared candidates.
The current shell keeps running until you restart it.

Only changed package contents produce an update. A new commit elsewhere in a
shared repository does not. If the author changes a package without raising its
version, the preview identifies it as a revision update and shows both revisions.

**What's new** shows the author's changelog from the staged package. Add a
`CHANGELOG.md` or `CHANGELOG.txt` file, or set `"changelog": "docs/changes.md"`
in the manifest. Lowercase filenames are also detected. Files must be UTF-8,
at most 64 KiB, and inside the package. The preview shows the file as plain text,
including its version headings; it does not infer or generate release notes.
If no readable changelog is supplied, the preview says so. Changelog content is
part of the reviewed candidate and is checked again before application.

The preview checks the complete enabled set against the current base. A changed
package is not installed if its manifest or composition fails. Newly required
mods need an explicit installation through **Install required mods**. After
resolving requirements, check again. A failed download can be retried with
**Check for updates**; successful independent candidates can still be reviewed.

Changing the installed set, update preferences, base source, or package contents
invalidates a prepared preview. A daemon restart also requires a fresh check.

## Scheduled checks and automatic installation

**Scheduled checks** looks for updates to all supported Git sources, including
mods with automatic installation turned off. Leave automatic installation off
to review and apply updates yourself. Turning scheduled checks off pauses all
background mod checks and installations without changing saved policies.
Manual checks and updates remain available.

The automatic installation switch sets the default for installed and future mods. Each mod can
use that default, opt in, or opt out. Changing the global switch preserves
individual choices. Disabled mods stay disabled after an update.

**Check frequency** sets one schedule for supported Git sources: hourly, every six
hours, daily (the default), or weekly. Changing it schedules the next check from
now without enabling automatic updates or discarding a valid preview.
**Remind me tomorrow** postpones the next check by 24 hours without changing
the recurring schedule. Failed checks still retry with backoff.

Automatic updates support Git repositories with a tracked branch and GitHub
package-directory sources. Local directories and archives require manual
updates. Detached Git revisions cannot be pulled; change their source explicitly
when moving to a different revision.

Checks begin no earlier than one minute after daemon startup. The scheduler
stores its next check time and wakes at most every fifteen minutes to see
whether a check is due. Failed checks back off from one hour to one day.
Automatic work pauses while mods are globally disabled or a generation awaits
its startup trial. The scheduler never restarts the shell.

Existing automatic-update users keep scheduled checks enabled until they change
the new setting. Changing an installation policy does not enable scheduled
checks. A manual preview is preserved until applied or dismissed. Background
previews can refresh at the next scheduled check. In a mixed preview, only
opted-in candidates without review warnings are installed automatically; the
others remain visible for manual review.

Changes to dependencies, dependency sources, permissions, required commands,
or a bypassed version requirement need review. A revision recovered after a
failed startup also needs review before another attempt. Permission declarations
describe package behavior; they do not restrict what its code can do.

## Compatibility and recovery

**Check compatibility** tests declared requirements and composition against the
current base. Enter a local candidate Ambxst checkout to check a different
version before installing it. This does not execute candidate QML and does not
prove runtime behavior. The candidate must be obtained separately; the manager
does not assume that a distribution's package updater exposes its next sources.

Updates are staged separately from installed packages. Applying them retains
the previous packages and state in a recovery journal. Interrupted application
is restored before the next state read. If the new generation fails the startup
health window, recovery restores its packages as well as the previous generation.
Further package changes wait until the pending update has been tested or recovered.

If the modded shell cannot open Settings, run:

```sh
ambxst mods rollback
# Or select the base shell for the next start:
ambxst mods base
ambxst
```

For a temporary bypass, use `AMBXST_MODS_DISABLED=1 ambxst`. Stop an already
running instance before starting a replacement. The backend commands work
without loading mod-provided QML.

**Diagnostic report** opens a preview with shell and mod versions, load order,
generation state, and the last update error code. Copy it when reporting a
problem. Settings values, environment variables, source URLs, and raw process
output are excluded. Nothing is uploaded automatically.

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

Update prepares a separate Git checkout and pulls with fast-forward only.
Local-directory and archive packages are reloaded from their original path.
The installed package remains unchanged during validation and composition.

## Manifest

```json
{
  "$schema": "https://raw.githubusercontent.com/Axenide/Ambxst/main/docs/mods/manifest.schema.json",
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
built. The user can relax it globally with the **Bypass Ambxst version check**
toggle in Settings → Mods, or with `ambxst mods bypass on`, which lets any
package compose regardless of its declared range. The bypass is a state flag,
not a per-mod setting: the status keeps reporting bypassed packages as
incompatible, and the toggle applies from the next build.
`compatibility.testedBaseCommits` is advisory. The base moves with every
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
"dependencies": ["org.example.core"],
"dependencySources": {
  "org.example.core": "https://github.com/example/ambxst-mod-core.git"
}
```

Settings shows missing and disabled requirements before the mod can be enabled.
It downloads them only after the user chooses **Install required mods**. The
source package must declare the expected ID; a different manifest is rejected.

The package source field accepts a local directory, an archive, a Git repository,
or a GitHub directory URL such as
`https://github.com/owner/repository/tree/main/packages/example`. GitHub directory
installs use a shallow sparse checkout and retain the original URL for updates.

## Deprecating a mod

Use `"deprecated": true` to recommend removing an installed mod. Add
`"deprecated_reason": "This feature is now included in Ambxst."` to explain
why. The manager shows the warning in the installed list and mod details.
It does not disable or remove the mod automatically. Updates to deprecated
packages require review, even when automatic updates are enabled.

The spellings `depricated` and `depricated_reason` are accepted aliases. Either
boolean flag marks the mod deprecated. If both reason fields are present,
`deprecated_reason` takes precedence. A reason alone does not deprecate a mod.

## Language metadata

Declare the interface languages in the package manifest:

```json
"localization": {
  "mode": "translated",
  "defaultLanguage": "en",
  "languages": ["en", "ru", "es"],
  "resources": {
    "en": "translations/en.json",
    "ru": "translations/ru.json",
    "es": "translations/es.json"
  }
}
```

Use `"mode": "single"` with `defaultLanguage` for an interface without
translations. Use `"mode": "none"` when the package introduces no interface
text. Omit `localization` only when language information is unknown.

Resources are optional JSON dictionaries with string keys and values. Paths
are relative to the package root. The manager checks supplied resources and
reports invalid declarations. These checks do not measure translation quality
or prove coverage of every visible string. The language list is identified as
author-provided information in Settings.

Metadata does not register translations or translate arbitrary mod strings.
Ambxst now includes native `I18n`; packages should use it and supply their own
translations as needed. A dependency on the former `community.i18n` mod is not
required for current Ambxst. Older packages without metadata continue to load
and show an unknown language state.

## Settings schema

Mod settings use data, not package-provided settings UI. This keeps the Settings
surface native and prevents arbitrary controls from running before a mod is
enabled.

```json
{
  "$schema": "https://raw.githubusercontent.com/Axenide/Ambxst/main/docs/mods/settings.schema.json",
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
health timer remains active. The optional update scheduler runs independently.
`AMBXST_MODS_DISABLED=1 ambxst` bypasses
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

In **Settings → Mods**, select a mod to check its source for updates. When an
update is available, **Update to <version>** opens a review for that mod. Updates
without a version change use **Update package**. The review shows release notes,
permissions, and any warnings before you confirm. Opening a single-mod review
may prepare a new plan for that mod; it never applies the other mods from a bulk
preview. Manual updates work with both global and per-mod automatic updates off.

The **Updates** section also offers individual update buttons and
**Apply reviewed updates** for the full preview. Restart after applying an update
to load the new generation. Finish a pending restart before applying another
update.

The running daemon retains prepared candidates between these commands:

```sh
ambxst mods check-updates
ambxst mods check-updates org.example.feature
ambxst mods apply-updates <plan-id-from-preview>
ambxst mods auto-update on
ambxst mods periodic-checks on
ambxst mods check-interval 6
ambxst mods auto-update off org.example.feature
ambxst mods auto-update inherit org.example.feature
ambxst mods check-compatibility /path/to/candidate-ambxst
ambxst mods diagnostics
```

`apply-updates` confirms the exact plan shown by `check-updates`. Review the
JSON before applying. Without a daemon, checks are read-only previews; start
the base shell and check again to retain a plan for application.

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
