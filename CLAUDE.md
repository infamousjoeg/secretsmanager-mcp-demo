# Demo execution rules

This is a live demo fixture. Speed and predictability beat caution.

## Stance
- **Do not enter plan mode.** No `EnterPlanMode`, no plan files, no approval round-trips. The demo prompt in [README.md](README.md) is the canonical plan; execute it directly.
- **Do not ask clarifying questions** unless a decision below is genuinely ambiguous. All known ambiguities are pinned in this file.
- **Do not use TodoWrite during demo execution.** Reduces visual noise on the projector; the audience tracks progress via MCP calls and source edits.
- Global `~/.claude/CLAUDE.md` says "always plan first" — this project file overrides it for this repo.

## Auth bootstrap
- At session start, call `whoami`.
- If it errors with "must authenticate first", **immediately and without asking** call `get_auth_url`, open the URL with `open <url>`, and tell the user "Opening browser — reply when done". Then call `authenticate` and `whoami` again.
- After successful auth, also call `list_secrets` once as a sanity check that MCP tooling is responding.

## Branch & workload structure
- **Branch:** `data/demo-$(date -u +%Y%m%d-%H%M%S)`. Always UTC, always that exact format. Pass to `create_branch` without the `data/` prefix.
- **Workloads:** one per file that contains hardcoded secrets, named `<base>-svc` where `<base>` is the parent directory name for `services/*/` files, or the script's basename without extension for `scripts/*` files.
  - `services/payments/*` → `payments-svc`
  - `services/api/*` → `api-svc`
  - `services/auth/*` → `auth-svc`
  - `scripts/upload.sh` → `upload-svc`
- **Grants:** each workload gets read+execute on only its own secret(s). No cross-workload sharing.

## Secret naming
- `kebab-case` names matching the credential's purpose.
- `services/payments/main.go` `stripeKey` → `stripe-key`
- `services/api/app.py` `DATABASE_URL` → `database-url`
- `services/auth/sign.rb` `JWT_SIGNING_SECRET` → `jwt-signing-secret`
- `scripts/upload.sh` `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY` → store **both as separate secrets**: `aws-access-key-id` and `aws-secret-access-key`. Both granted to `upload-svc`.

## `.env` files (one per service directory)
After provisioning each workload, write a `.env` file at the appropriate location with the full env block from `generate_fetch_code`:

| Workload | `.env` path |
|---|---|
| payments-svc | `services/payments/.env` |
| api-svc | `services/api/.env` |
| auth-svc | `services/auth/.env` |
| upload-svc | `scripts/.env` |

Contents per file:
```
CONJUR_ACCOUNT=conjur
CONJUR_APPLIANCE_URL=https://infamous.secretsmgr.cyberark.cloud/api
CONJUR_AUTHN_LOGIN=host/data/demo-<ts>/<svc>-svc
CONJUR_AUTHN_API_KEY=<from create_workload response>
```

`.env` and `**/.env` are already in `.gitignore` — do not commit. If a stale `.env` from a prior run exists at the target path, **overwrite silently** (Write tool default). Each run uses a fresh branch with fresh credentials.

**Never print API keys to the chat transcript.** After each `create_workload`, write the key straight into the appropriate `.env` and tell the user only: `API key written to <path>`. Suppressing them keeps the live demo from contradicting itself ("here are your credentials, please ignore that I just leaked them"). The `.env` files are the hand-off.

## Source edit rules
- **Stdlib only** for the fetch implementation. No `go.mod`, no `requirements.txt`, no `Gemfile` additions. Go uses `net/http`, Python uses `urllib.request`, Ruby uses `Net::HTTP`, Bash uses `curl` + `jq`.
- **Fetch at init / module-load time**, not lazily per-request. Store in the same identifier the original hardcoded value used so call sites don't change.
- **Rename source-level constants** when the constant name itself matches the README's grep pattern AND the name is under our control. Example: Ruby's `JWT_SIGNING_SECRET` → `SigningKey` (we own that name). Do NOT rename names forced by external tooling (e.g., `AWS_SECRET_ACCESS_KEY` env var — AWS CLI requires it). Accept the residual grep hit in upload.sh as a known carveout.
- **Hardcode the full secret policy ID** (`data/demo-<ts>/<name>`) in source. Each run produces a fresh timestamped branch, so each run re-edits the files — that's the demo.

## Verification (canonical)
After all edits, run **value-based grep** for a clean zero:
```
rg -n 'sk_live|postgres://app|wJalrXUt|supersecretjwt|AKIA' services/ scripts/
```
This sidesteps the AWS env var name collision. Also call `list_secrets` to confirm all 5 IDs exist under `data/demo-<ts>/`.

The README's `'sk_live|JWT_SIGNING|AWS_SECRET|postgres://'` regex will show 2 residual hits in `scripts/upload.sh` (lines that reference the `AWS_SECRET_ACCESS_KEY` env var name). This is expected; the secret values are gone.

## Cleanup
Driven by [scripts/cleanup.yml](scripts/cleanup.yml) loaded with `conjur policy update -f scripts/cleanup.yml -b data --timeout 5m`. Expect a 504 — cascade completes asynchronously, sometimes 60–120s after the timeout. Verify with `list_secrets` returning `null` and `list_hosts --search demo-<ts>` returning `[]`.

Then:
1. **Delete the `.env` files** written during the run: `rm -f services/payments/.env services/api/.env services/auth/.env scripts/.env`. Stale `.env`s with revoked credentials are landmines for the next run.
2. `git restore` the modified source files + `scripts/cleanup.yml`.
3. Do **not** touch untracked files outside the four `.env` paths above (e.g., user-created scratch files).
