# Security Policy

FreeDSH manages local configuration, provider credentials and update/sync flows, so security reports are taken seriously.

## Do not report secrets publicly

If you discover an exposed credential, token, private key, session value or other sensitive information, **do not paste it into a public issue**.

Until a dedicated private reporting channel is configured, open a public issue containing only a minimal, non-sensitive description such as “Potential secret-handling issue — maintainer contact requested”, without including the secret or exploit details.

## Credential rules

- Provider/API credentials must remain local.
- `.credentials.yaml`, environment variables, sessions, logs and runtime state must not be committed.
- Contributors must sanitize logs before attaching them to issues or pull requests.
- Do not expose FreeLLMAPI/admin interfaces publicly unless you have intentionally configured authentication, network controls and a non-default credential strategy.
- Treat any default/example credentials as examples only; replace them before exposing a service beyond localhost.

## Supported code

Security fixes should target the current `main` branch unless the maintainer explicitly identifies another supported release.

## Scope

Security-relevant areas include:

- secret leakage;
- unsafe installer/update behavior;
- command injection;
- path traversal or unsafe file writes;
- authentication/authorization bypass in project-owned components;
- unintended network exposure;
- insecure rollback/snapshot handling;
- supply-chain risks introduced by FreeDSH scripts or dependencies.

Issues in third-party providers or DeepSeek Harness itself should generally be reported to those upstream projects unless FreeDSH's integration is the source of the vulnerability.

## Responsible disclosure

Please allow reasonable time for investigation and remediation before publishing exploit details. We will prefer transparent advisories once users have a practical mitigation or fix.
