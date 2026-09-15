# FreeDSH Roadmap

This roadmap is intentionally lightweight. It describes directions where community contributions are useful; it is not a promise that every item will ship.

## Now — make the project easy to adopt

- [x] Add a short demo GIF/video to the README. *(done — `assets/freedsh-demo.gif`)*
- [x] Ship the plugins as an installable DSH bundle, so an existing harness can add them with `dsh plugin --profile web add`. *(done for the git form — `dsh plugin --profile web add github:marcosmmjr2023/dsh-h-v1`; see [docs/INSTALL-BUNDLE.md](docs/INSTALL-BUNDLE.md))*
- [ ] Publish the bundle to the npm registry (`npm publish`), so the shorter `dsh plugin --profile web add freedsh` works and the project is searchable on npm. The workflow is ready (`.github/workflows/publish.yml`, needs the `NPM_TOKEN` secret).
- [x] Publish versioned GitHub Releases with a source ZIP and checksums. *(done — `.github/workflows/release.yml`)*
- [ ] Improve first-run provider setup and credential guidance.
- [ ] Expand provider compatibility testing.
- [ ] Improve installer diagnostics on Windows and Linux.
- [ ] Make common failure/fallback states easier to understand in the UI.
- [ ] Grow `good first issue` tasks for documentation, translations and testing.

## Next — make routing observable

- [ ] Request/provider usage statistics.
- [ ] Success/failure/fallback counters.
- [ ] Latency visibility per provider/model.
- [ ] Optional estimated-cost reporting where provider pricing data is available.
- [ ] Exportable/shareable benchmark summaries without secrets or prompt content.

## Later — community intelligence

- [ ] Reproducible provider benchmark format.
- [ ] Community-submitted compatibility/status reports.
- [ ] Better routing using observed latency/reliability.
- [ ] User-defined routing policies.
- [ ] More languages and OS coverage.
- [x] Easier plugin packaging/discovery for reusable FreeDSH components. *(bundle packaging done; publishable to npm and validated by `tools/check-npm-package.mjs`)*

## Contribution ideas

Good community-owned workstreams include:

1. **Provider compatibility:** test free/trial endpoints and document failure modes.
2. **Installer quality:** make clean installs and upgrades boring and predictable.
3. **Observability:** surface which provider/model actually answered and why fallback happened.
4. **Internationalization:** improve pt-BR and add new language packs.
5. **Benchmarks:** define small, reproducible tests instead of anecdotal “best model” claims.
6. **Documentation:** screenshots, videos, troubleshooting and beginner onboarding.

Please open an issue before starting a large roadmap item so scope and interfaces can be agreed first.
