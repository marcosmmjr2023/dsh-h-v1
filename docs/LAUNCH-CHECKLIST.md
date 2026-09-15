# FreeDSH Launch Checklist

Use this as an execution checklist, not as a strategy document.

## Before public launch

- [x] Merge the community-launch PR after CI passes. *(CI green: guard, tests, package, PowerShell syntax)*
- [x] Update repository description. *(inclui "DSH bundle" e pt-BR/Windows)*
- [x] Add repository topics. *(20 topics, com `pt-br`, `portuguese`, `localization`, `i18n`, `windows`, `windows-installer`, `dsh-bundle`, `freedsh`)*
- [x] Enable GitHub Discussions. *(`has_discussions` ativo)*
- [x] Create the initial Discussions categories. *(Announcements, General, Ideas, Polls, Q&A, Show and tell)*
- [x] Post the seed Discussions from `docs/DISCUSSIONS-SEED.md`. *(tópicos #11 a #15; fixe o #11 — Discussions não têm pin pela API)*
- [x] Add a sanitized 20–30 second demo GIF. *(`assets/freedsh-demo.gif`, no README e no site)*
- [ ] Add 3–4 sanitized screenshots. *(o GIF cobre a demonstração; screenshots estáticos seguem em aberto — issue #6)*
- [ ] Publish at least one dated provider compatibility/benchmark result.
- [x] Land a landing page and an installable bundle. *(<https://marcosmmjr2023.github.io/dsh-h-v1/> e `dsh plugin --profile web add github:marcosmmjr2023/dsh-h-v1`, ver `docs/INSTALL-BUNDLE.md`)*
- [x] Publish a versioned GitHub Release with a source ZIP and checksums. *(`v0.2.125`, via `.github/workflows/release.yml`)*
- [ ] Publish the bundle to the npm registry (`Actions → publish`, exige o secret `NPM_TOKEN`). Depois disso o comando curto `dsh plugin --profile web add freedsh` passa a valer e os textos devem citá-lo.
- [x] Confirm all install commands still work from a clean environment. *(instalador de 1 linha, bundle por git e bundle por tarball npm testados em `DSH_HOME` limpo; nenhuma instalação existente foi alterada)*
- [x] Confirm no credentials/private data appear in docs or media. *(guard de segredos no CI em todo arquivo versionado; o pacote npm tem verificação própria em `tools/check-npm-package.mjs` — anexos, `settings.yaml`, `profiles/` e credenciais ficam fora)*

## Launch day

- [ ] Publish one technical Reddit post where community rules allow it.
- [ ] Publish one Brazilian developer-community post.
- [ ] Publish one short LinkedIn/X post with a visual.
- [ ] Avoid identical cross-posting; adapt copy to each community.
- [ ] Respond to install questions and bug reports quickly.

## First week

- [ ] Triage all new issues.
- [ ] Add labels to every actionable issue.
- [ ] Thank and guide first-time contributors.
- [ ] Convert repeated support questions into documentation.
- [ ] Record provider compatibility reports with test dates.
- [ ] Identify the most common installation failure.
- [ ] Publish one concrete fix/improvement based on community feedback.

## First month

- [ ] Publish a short “what we learned” update.
- [ ] Highlight outside contributors in release notes.
- [ ] Review which acquisition channel produced real users rather than only stars.
- [ ] Review whether Discussions has enough activity to justify Discord.
- [ ] Prioritize provider observability / benchmark work if reports are accumulating.

## Metrics

Baseline no início do lançamento (Insights → Traffic, 14 dias): **90 views / 11 visitantes únicos**, 2136 clones (419 únicos), referrer `github.com` (54). Compare contra isso, não contra zero.

Track if available:

- unique visitors;
- clones;
- successful install reports;
- returning users;
- issues/provider reports;
- pull requests;
- Discussions activity;
- stars.

Do not optimize the project solely for stars.
