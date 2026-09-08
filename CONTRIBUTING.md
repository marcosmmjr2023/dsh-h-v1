# Contributing to FreeDSH

Thanks for helping improve FreeDSH. Contributions do not need to be large: provider compatibility reports, documentation fixes, translations and reproducible bug reports are all useful.

## Good ways to start

Look for issues labeled:

- `good first issue` — small, self-contained tasks;
- `help wanted` — areas where outside help is especially useful;
- `documentation` — docs and onboarding;
- `provider` — model/provider integration and compatibility;
- `router` — routing and fallback behavior;
- `bug` — reproducible defects.

If no issue exists yet, opening one before a large change is encouraged so the approach can be discussed first.

## Development principles

1. Keep provider credentials and private runtime data out of git.
2. Prefer small, reviewable changes over unrelated refactors.
3. Preserve rollback/snapshot guarantees when changing update or sync flows.
4. Keep Windows and Linux behavior aligned where practical.
5. Do not claim a provider is "free" permanently; free tiers and limits change.
6. Keep FreeDSH clearly identified as an unofficial layer on top of DeepSeek Harness.

## Before opening a pull request

- Explain what problem the change solves.
- Include reproduction steps for bug fixes.
- Describe manual tests performed.
- Update documentation when user-visible behavior changes.
- Never include API keys, access tokens, local credentials, sessions or private logs.
- Run the repository's existing checks/workflows when applicable.

## Provider contributions

For a new or changed provider, please document:

- provider name;
- API/base URL used by the integration;
- model(s) tested;
- whether the tier tested was free, trial or paid at the time of testing;
- rate-limit/error behavior observed;
- fallback behavior;
- date tested.

Provider availability changes frequently, so compatibility evidence is more valuable than broad promises.

## Translation contributions

Translations should preserve technical meaning rather than translate product/API identifiers literally. Keep provider names, commands, environment variables and paths unchanged.

## Bug reports

A useful bug report contains:

- OS and version;
- DeepSeek Harness/core version;
- FreeDSH version/tag/commit;
- installation path (Windows/Linux/manual);
- expected behavior;
- actual behavior;
- minimal reproduction steps;
- sanitized logs if relevant.

Never paste secrets in an issue.

## Pull requests

Keep PRs focused. A reviewer should be able to understand the intent from the title and description without reverse-engineering the diff.

Suggested title prefixes:

- `fix:` bug fix
- `feat:` user-visible feature
- `docs:` documentation
- `provider:` provider integration
- `router:` routing/fallback behavior
- `i18n:` localization
- `community:` project/community infrastructure

By contributing, you agree that your contribution can be distributed under the repository's applicable license terms.
