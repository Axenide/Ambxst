# Compact player volume scroll

Scroll over the compact player to change the default audio sink volume. A media
player must be available. This example uses Ambxst's existing audio service and
adds no interface text, settings, or external commands.

From the Ambxst checkout:

```sh
ambxst mods install ./examples/mods/compact-player-volume-scroll
ambxst mods enable community.compact-player-volume-scroll
ambxst reload
```

Do not enable this example with `community.volume-scroll`. That package includes
the same control and also handles scrolling over the full player and bar audio
controls. The manifest declares the conflict.

## Manifest fields

`changelog` points to the bundled release notes displayed in the update preview.
Keep the latest release first and bump `version` when publishing package changes.
`testedBaseCommits` records tested source revisions, not a promise that later
revisions will apply without conflicts.

`localization.mode` is `none` because this mod adds no interface text. For a mod
with an English-only interface, use:

```json
"localization": {
  "mode": "single",
  "defaultLanguage": "en",
  "languages": ["en"]
}
```

For an interface translated into English, Russian, and Spanish, use:

```json
"localization": {
  "mode": "translated",
  "defaultLanguage": "en",
  "languages": ["en", "ru", "es"]
}
```

Declare only languages the mod implements. If the package contains its own JSON
dictionaries, add `resources` with language codes mapped to package-relative
paths. Metadata does not load dictionaries or translate the interface; the mod
must implement that behavior. Mods using Ambxst's existing dictionaries can omit
`resources`.

This example is active, so `deprecated` is `false`. To retire a package after its
feature enters the base shell, publish a new patch version with a specific reason:

```json
"deprecated": true,
"deprecated_reason": "This feature is included in your Ambxst version. Remove this mod to avoid duplicate controls."
```

Use that reason only when it applies to the supported base versions. The manager
recommends removal and requires update review; it does not remove the mod itself.
The misspelled `depricated` and `depricated_reason` aliases are accepted for
compatibility. Prefer the canonical names in new packages.

Automatic updates and check frequency are user settings in the mod manager.
They do not belong in the package manifest. Declare `dependencies`,
`dependencySources`, `commands`, and `settings.schema` only when the mod uses them.
Permissions describe what code does; they do not sandbox it.

See the [mod author guide](../../../docs/mods/README.md) for the full format.
