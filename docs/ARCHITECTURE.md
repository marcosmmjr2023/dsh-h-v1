# FreeDSH Architecture Overview

This document is a contributor map, not a replacement for the detailed operational guides.

## Relationship to DeepSeek Harness

FreeDSH does not replace the DeepSeek Harness core. It installs/uses the upstream core and layers project-owned configuration, plugins, routing, UI additions, localization and lifecycle tooling around it.

```text
DeepSeek Harness core
        │
        ├── FreeDSH overlay/
        │      ├── settings / presets
        │      ├── Smart Model Router
        │      └── UI plugins / assets
        │
        ├── FreeLLMAPI integration
        │      └── configured external providers
        │
        ├── installer/
        │      └── Windows + Linux bootstrap/update
        │
        ├── tools/
        │      └── sync, snapshots, rollback, release helpers
        │
        └── core-i18n-pt/
               └── experimental pt-BR localization
```

## Main areas

### `overlay/`

The project-owned layer applied to the live DeepSeek Harness configuration. It contains the Smart Model Router and UI/configuration pieces that should be versioned and shared.

Runtime secrets, sessions and machine-specific private state do not belong here.

### Smart Model Router

The router is responsible for choosing an appropriate configured model/provider path and performing fallback when a route fails. The public user-facing modes are centered around different cost/capability trade-offs such as `auto`, `eco` and `ultra`.

Provider availability is inherently dynamic. Routing logic should therefore distinguish between:

- configuration (what the user allows);
- capability/cost intent (what the task needs);
- runtime health/errors (what is actually reachable now);
- fallback policy (what should happen next).

### FreeLLMAPI integration

FreeLLMAPI acts as a local aggregation/gateway layer for configured external providers. FreeDSH should treat provider free tiers as changing external conditions, not permanent guarantees.

### `installer/`

Bootstrap and update entry points for Windows and Linux. Installer changes are high impact because they touch first-run trust and local configuration preservation.

When changing installer behavior, preserve these expectations where applicable:

1. detect an existing setup;
2. avoid leaking credentials;
3. preserve user configuration when requested;
4. provide diagnostics when setup fails;
5. avoid silently destroying a known-good installation.

### `tools/`

Lifecycle tools for pull/push synchronization, snapshots, rollback, release/version helpers and related operational behavior.

The most important invariant is recoverability: destructive or replacement operations should have an understandable rollback path.

### `core-i18n-pt/`

Experimental localization for the upstream core. Keep translations separate from API identifiers, commands, file paths and other tokens that must remain exact.

## Data and secret boundaries

Safe-to-version content includes project code, generic settings/templates, documentation and public provider metadata.

Never version:

- API keys or access tokens;
- local credential files;
- user sessions;
- prompt/conversation history unless deliberately sanitized test fixtures;
- private logs;
- machine-specific secrets.

See [../SECURITY.md](../SECURITY.md).

## Where to contribute

| Goal | Start here |
|---|---|
| Add/fix provider behavior | Smart router / FreeLLMAPI integration |
| Change panel/UI | `overlay/` UI plugins |
| Improve installation | `installer/` |
| Improve sync/rollback | `tools/` |
| Improve pt-BR | `core-i18n-pt/` + translated docs |
| Improve onboarding | root README + `docs/` |

For large changes, open an issue first and describe the intended behavior and rollback/error handling.
