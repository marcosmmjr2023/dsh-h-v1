# FreeDSH Community Launch Playbook

This document is a practical checklist for launching FreeDSH publicly and turning repository traffic into users and contributors.

## 1. GitHub repository settings

Recommended repository description:

> FreeDSH — free-first multi-model routing, automatic fallback, safe updates and pt-BR support for DeepSeek Harness.

Recommended topics:

`deepseek`, `deepseek-harness`, `dsh`, `dsh-plugin`, `ai-agents`, `coding-agent`, `llm-router`, `openrouter`, `groq`, `cerebras`, `free-llm`, `ai-coding`

Enable **GitHub Discussions** and create these categories:

- Announcements
- Help
- Ideas
- Provider reports
- Show and tell
- Routing / benchmarks

Seed the first discussions with useful prompts instead of leaving the area empty:

1. Welcome to FreeDSH — what are you using it for?
2. Which free provider is working best for you this week?
3. Share your FreeDSH routing stack
4. Compatibility reports by OS / DeepSeek Harness version
5. Feature ideas and routing strategies

## 2. Launch assets

Before broad promotion, add:

- a 20–30 second demo GIF near the README hero;
- 3–4 sanitized screenshots;
- one real provider/fallback benchmark;
- one short example showing a task routed through multiple providers.

Never expose API keys, private prompts, personal paths, account identifiers or admin credentials in screenshots.

## 3. Reddit launch

Do not lead with “please star my repo”. Lead with a useful experiment.

Suggested title:

> I tried to run DeepSeek Harness with free models and automatic fallback — here’s the setup

Suggested structure:

1. The problem: relying on one provider/model is expensive or brittle.
2. What was built: a free-first router + fallback layer for DeepSeek Harness.
3. What was tested: providers, latency, failures and fallbacks.
4. What worked and what did not.
5. Link to the open-source repo for people who want to reproduce it.

Good communities to evaluate individually before posting:

- r/DeepSeek
- r/LocalLLaMA
- r/opensource
- coding-agent / AI-agent communities where self-promotion rules allow it

Always read each community’s current self-promotion rules before posting.

## 4. Hacker News

Suggested format:

> Show HN: FreeDSH – free-first model routing and safe updates for DeepSeek Harness

Keep the submission description technical and concise. The README should be able to answer the first questions without requiring a long explanation in comments.

## 5. X / LinkedIn / short-form posts

Promote one feature per post, not the entire product.

Example themes:

- Provider A fails → Provider B automatically takes over.
- A new DeepSeek Harness core is tested in a parallel instance instead of overwriting the working setup.
- A week of requests with the percentage served by free tiers.
- Before/after setup complexity.

Use a GIF or screenshot whenever possible.

## 6. Brazilian community

The pt-BR interface and docs are a differentiated entry point.

Content ideas:

- “Como usar DeepSeek Harness com modelos gratuitos no Windows”
- “Roteamento automático entre Groq, Cerebras, OpenRouter e outros modelos”
- “Como atualizar o DeepSeek Harness sem quebrar sua instalação atual”

Possible channels include LinkedIn, TabNews, Brazilian developer communities and short tutorial videos.

## 7. Community flywheel

The long-term loop should be:

```text
more users
  ↓
more provider compatibility reports
  ↓
better routing information
  ↓
better defaults / fewer failures
  ↓
more users
```

The provider compatibility matrix and benchmark issues are therefore community features, not just documentation tasks.

## 8. Metrics to watch

Prioritize:

1. unique repository visitors;
2. clones / install attempts;
3. successful installs;
4. returning users;
5. issues and provider reports;
6. pull requests;
7. Discussions participation;
8. stars.

Stars are useful for discovery, but they are not the primary measure of product adoption.

## 9. Suggested first 30 days

### Week 1
- Finish README GIF/screenshots.
- Enable Discussions.
- Publish one reproducible provider benchmark.

### Week 2
- Publish the first technical Reddit post.
- Publish a pt-BR tutorial/post.
- Respond quickly to every issue and install report.

### Week 3
- Post a second experiment based on real usage data.
- Invite small contributors to take `good first issue` tasks.

### Week 4
- Summarize what changed because of community feedback.
- Publish a small release note highlighting outside contributions.
- Decide whether a Discord is justified by actual recurring participation.
