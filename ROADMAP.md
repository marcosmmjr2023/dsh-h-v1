# FreeDSH Roadmap

This roadmap is intentionally lightweight. It describes directions where community contributions are useful; it is not a promise that every item will ship.

## Now — make the project easy to adopt

- [ ] Add a short demo GIF/video to the README.
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
- [ ] Easier plugin packaging/discovery for reusable FreeDSH components.

## Contribution ideas

Good community-owned workstreams include:

1. **Provider compatibility:** test free/trial endpoints and document failure modes.
2. **Installer quality:** make clean installs and upgrades boring and predictable.
3. **Observability:** surface which provider/model actually answered and why fallback happened.
4. **Internationalization:** improve pt-BR and add new language packs.
5. **Benchmarks:** define small, reproducible tests instead of anecdotal “best model” claims.
6. **Documentation:** screenshots, videos, troubleshooting and beginner onboarding.

Please open an issue before starting a large roadmap item so scope and interfaces can be agreed first.
