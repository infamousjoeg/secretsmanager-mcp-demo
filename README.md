# SecretsManagerMCP — Agentic Remediation Demo

A < 5-minute live demo of the Idira Secrets Manager MCP server. The headline: instead of executing a fixed remediation script, an AI agent reads a real polyglot codebase, **decides** the right branch/workload structure, and drives the MCP end-to-end to migrate every hardcoded secret to Secrets Manager — generating language-matched fetch code and editing each source file in place.

Built around the `localhost/cyberark/mcp-server:0.1.0-beta` MCP server against an Idira Secrets Manager, SaaS tenant.

---

## What the audience sees

| Beat | Why it lands |
|------|--------------|
| One scan of a 4-file repo turns up 4 hardcoded secrets across 4 languages | Concrete "this is the problem" moment |
| One natural-language prompt to the agent | The MCP angle becomes obvious — no script, no menu |
| Agent picks branch + per-service workload names on its own | Shows reasoning, not automation |
| `generate_fetch_code` produces SDK snippets in the matching language | Polyglot-friendly, audience-recognizable |
| Re-running the same scan returns zero hits | Clean before/after |
| `list_secrets` proves the secrets exist in Conjur | Trust through verification |

---

## Prerequisites

- Docker Desktop running.
- The MCP image loaded locally: `docker images | grep cyberark/mcp-server` should show `0.1.0-beta`.
- An Idira Identity OAuth2 client registered in your tenant, with the correct redirect URI (see *Port choice* below).
- An MCP client that supports stdio MCP servers (this demo uses Claude Code).
- One free TCP port on the host for the OAuth callback (default 8080; we use 8081 because 8080 was occupied).

---

## Working configuration

The `.mcp.json` in this repo:

```jsonc
{
  "mcpServers": {
    "SecretsManagerMCP": {
      "command": "docker",
      "args": [
        "run", "--rm", "-i",
        "-p", "8081:8081",
        "-e", "CONJUR_API_URL=<your-tenant>.secretsmgr.cyberark.cloud",
        "-e", "OAUTH_APPLICATION_ID=<your-oauth-app-id>",
        "-e", "OAUTH_CLIENT_ID=<your-oauth-client-id>",
        "-e", "OAUTH_ISSUER_URI=https://<your-pod>.id.cyberark.cloud",
        "-e", "OAUTH_REDIRECT_URI=http://localhost:8081/callback",
        "localhost/cyberark/mcp-server:0.1.0-beta"
      ]
    }
  }
}
```

### Gotchas that bit us (worth knowing)

1. **`OAUTH_ISSUER_URI` is your Identity tenant URL — and your tenant alias may not be it.** Idira Identity assigns each tenant a *pod* hostname of the form `<podid>.id.cyberark.cloud`, where `<podid>` is something like `abc1234`. Your friendly tenant alias such as `<alias>.id.cyberark.cloud` may not even resolve. Two reliable ways to find your real issuer:
   1. Open `https://<alias>.cyberark.cloud/` in a browser — it redirects login to your pod URL.
   2. Run `curl https://<pod>.id.cyberark.cloud/.well-known/openid-configuration` and confirm the `issuer` field matches.
2. **Port mapping must align everywhere.** The MCP's callback server binds to whatever port is in `OAUTH_REDIRECT_URI` — so `-p H:C` must satisfy `H == C == port(OAUTH_REDIRECT_URI) == port(OAuth client's registered redirect URI)`. If any of those four disagree, the browser redirect lands on a port nobody is listening on. The Idira docs only document the 8080:8080 default and don't flag this constraint.
3. **`CONJUR_API_URL` must not include `https://`.** The 0.1.0-beta binary prepends `https://` unconditionally and will try to hit `https://https://...`, producing a cryptic `dial tcp: lookup https on ...:53: no such host` error. The official docs example **does** include the scheme — the docs are wrong for this version.

---

## First-time authentication

In your MCP client:

1. Call `get_auth_url` — opens a browser to the Idira Identity tenant login.
2. Log in.
3. Browser redirects to `http://localhost:8081/callback` and shows a success page.
4. Call `authenticate` — completes the token exchange.
5. Call `whoami` to confirm.

If `get_auth_url` ever times out or your tool calls go to an unresponsive session, quit and relaunch your MCP client (a stuck stdio session can swallow calls silently).

---

## Demo flow (target ≤ 5 minutes)

| t | Action | Tool calls |
|---|--------|-----------|
| 0:00 | Scene-set. `rg -n 'sk_live\|JWT_SIGNING\|AWS_SECRET\|postgres://' services/ scripts/` — six red hits across four files. | bash |
| 0:20 | Confirm session is live. | `whoami` |
| 0:30 | **Single demo prompt** (verbatim below). | (user prompt) |
| 0:45 – 4:00 | Agent works: `list_all_resources` → `create_branch demo-<ts>` → per-service `create_workload`, `create_secret`, `grant_secret_permission`, `generate_fetch_code` → `Edit` source. | MCP + Edit |
| 4:00 | Re-run the same `rg` — empty. Open one rewritten file to show the SDK-driven fetch. | bash + read |
| 4:30 | Proof in Conjur. | `list_secrets` |
| 4:50 | Close: *"Four secrets, four languages, four workloads, one prompt."* | — |

### The demo prompt

> Find every hardcoded secret in this repo and properly migrate each one to Secrets Manager. Pick a sensible branch and per-service workload structure (one workload per service, named `<service>-svc`), generate language-matched fetch code, and edit the source files so the secrets are read at runtime. Use `data/demo-<timestamp>` as the root branch so we don't collide with anything.

### MCP tools exercised

`whoami`, `list_all_resources`, `create_branch`, `create_workload` ×4, `create_secret` ×4, `grant_secret_permission` ×4, `generate_fetch_code` ×4, `list_secrets` — 8 of the 11 tools the server exposes.

---

## The fixture

Four believable, tiny services, each with a single hardcoded secret of a different shape:

| File | Lang | Secret |
|------|------|--------|
| [services/payments/main.go](services/payments/main.go) | Go | `stripeKey` (`sk_live_...`) |
| [services/api/app.py](services/api/app.py) | Python (Flask) | `DATABASE_URL` with embedded password |
| [services/auth/sign.rb](services/auth/sign.rb) | Ruby (Sinatra) | `JWT_SIGNING_SECRET` |
| [scripts/upload.sh](scripts/upload.sh) | Bash | `AWS_SECRET_ACCESS_KEY` |

Each file is 10–25 lines so diffs read cleanly on a projector. The Ruby file deliberately uses `JWT_SIGNING_SECRET` in two more places (encode + decode) so the audience sees the same secret consumed multiple times — that subtlety reinforces *why* central management matters.

`generate_fetch_code` only supports `ruby`, `go`, `curl`, `java` — Python and Bash both fall back to `curl`. Worth calling out on the day; it's actually a nice subplot ("curl works everywhere").

---

## Cleanup

The MCP exposes no delete tools, and APIv2 has no direct "delete branch" endpoint either. Cleanup is **policy-driven** via `!delete` statements ([statement ref](https://docs.cyberark.com/secrets-manager-saas/latest/en/content/operations/policy/statement-ref-delete.htm), [policy load](https://docs.cyberark.com/secrets-manager-saas/latest/en/content/operations/policy/policy-load.html)).

1. Open [scripts/cleanup.yml](scripts/cleanup.yml).
2. Replace `<BRANCH>` with the timestamped branch the demo created (e.g. `demo-20260519-184321`).
3. Load it in **PATCH mode** against the parent `data` branch — POST rejects `!delete` and PUT is not allowed on `data`:

   ```sh
   conjur policy update -f scripts/cleanup.yml -b data --timeout 5m
   ```

   Or via REST:

   ```sh
   curl -X PATCH \
     -H "Authorization: Token token=\"$(printf %s "$ACCESS_TOKEN" | base64)\"" \
     -H "Content-Type: text/plain" \
     --data-binary @scripts/cleanup.yml \
     https://<your-tenant>.secretsmgr.cyberark.cloud/api/policies/conjur/policy/data
   ```

4. **Always verify with `list_secrets`** — the demo branch's IDs should be gone. Do not trust the HTTP response; see the gotcha below.

### Gotcha: the cascade delete reliably 504s — but completes anyway

A single `!delete !policy demo-<ts>` against a populated branch (4 workloads + 5 secrets + 5 grants) takes long enough server-side that the load balancer returns `504 Gateway Time-out` (or `context deadline exceeded` from the CLI if you didn't pass `--timeout`). **The cleanup succeeds anyway** — the proxy times out, but Conjur finishes the work asynchronously.

What this means operationally:

- **Do not retry on 504.** Pause, then verify.
- **Verify by listing, not by reading the HTTP status.** Run `list_secrets` (returns `null` when empty) and `list_hosts --search demo-<ts>` (returns `[]`). If both are empty, you're done — regardless of what the CLI/curl said.
- Symptom of a *real* failure: `list_secrets` still shows the demo branch's IDs after the call, or `conjur policy replace -f /dev/null -b data/demo-<ts>` returns something other than `404 Policy 'data/demo-<ts>' not found`. (The 404 is actually the success signal — it means the branch is gone.)

If verification shows the cascade *didn't* complete, fall back to: (a) `conjur policy replace -f /dev/null -b data/demo-<ts>` to wipe the branch's contents first, then (b) re-run the `!delete !policy demo-<ts>` PATCH against `data` — the now-empty branch deletes fast.

---

## Pre-show checklist (rehearse this)

- [ ] Token still valid — call `whoami`; if it errors, re-run the auth flow before going live.
- [ ] `rg` shows 6 hits across 4 files.
- [ ] MCP container is the latest config: `docker ps --filter ancestor=localhost/cyberark/mcp-server:0.1.0-beta` shows `0.0.0.0:8081->8081/tcp`.
- [ ] A blank terminal pane is ready for the opening `rg`.
- [ ] Decide ahead of time: if Claude picks weird workload names, you'll let it run (the prompt is the canonical source) — or stop and re-prompt with tighter naming guidance.

---

## Things worth filing upstream with Idira

- **Docs gap:** the MCP setup page treats `8080` as the only port. Document the constraint that the host port, container port, `OAUTH_REDIRECT_URI` port, and OAuth client's registered redirect URI must all match.
- **Binary bug:** `CONJUR_API_URL` is double-prefixed with `https://`. Either strip the scheme defensively in the binary or correct the docs example to use a bare hostname.
- **Cryptic error message:** when the URL is malformed, the error `dial tcp: lookup https on 192.168.65.7:53: no such host` is opaque. Returning "invalid CONJUR_API_URL — expected hostname, got URL" would save people a lot of time.
