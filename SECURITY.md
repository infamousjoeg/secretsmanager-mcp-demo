# Security

## About the secrets in this repository

This repo is a demo of secret remediation. By design, the four fixture files in [`services/`](services/) and [`scripts/`](scripts/) contain **deliberately fake hardcoded credentials**:

| File | Value | Why it's safe |
|------|-------|---------------|
| [services/payments/main.go](services/payments/main.go) | `sk_live_DEMO_FAKE_KEY_FOR_REMEDIATION_DEMO_DO_NOT_USE` | Includes `_` characters that break Stripe's `sk_live_[a-zA-Z0-9]+` shape — not detectable by secret scanners, not a valid Stripe key |
| [services/api/app.py](services/api/app.py) | `postgres://app:s3cretP@ss@db:5432/prod` | Demo connection string to a non-existent DB |
| [services/auth/sign.rb](services/auth/sign.rb) | `supersecretjwt-please-change-before-prod` | Obviously placeholder |
| [scripts/upload.sh](scripts/upload.sh) | `AKIAIOSFODNN7EXAMPLE` + `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` | The official AWS-docs example credential pair, blocked from authentication by AWS |

These exist so the demo has something to *fix*. Do not replace them with real values in commits.

## What is **not** in this repository

The maintainer's actual:

- CyberArk Conjur Cloud tenant URL
- CyberArk Identity tenant (pod) URL
- OAuth client ID, application ID, or API keys
- Any workload API keys generated during demo runs
- Any `.env` files created by the demo (`.gitignore` blocks them)

If you fork this repo and configure [.mcp.json](.mcp.json) for your own tenant, fill in the `<your-…>` placeholders — but never commit those changes upstream.

## Reporting a real secret leak

If you find a credential in this repo that looks real (matches a live Stripe / AWS / GitHub / database / etc. service rather than the docs examples above), please report it before opening a public issue:

- Email: **joe@joe-garcia.com**
- Include: file path, line number, and the leading characters of the value (do **not** paste the full secret in a public channel).

The maintainer will rotate the affected credential, force-push a sanitized history, and contact GitHub support to purge cached versions.

## Reporting a security issue in the demo itself

If you find a security issue with how the demo authenticates to Conjur, stores workload API keys in `.env` files, generates fetch code, etc. — open a regular GitHub issue. These aren't sensitive; they're discussion topics.

## Upstream issues

For bugs or vulnerabilities in the underlying CyberArk Secrets Manager MCP server, report to CyberArk via their official channels — not here.
