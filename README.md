# RuleFuse Code Review Action

AI-powered code review for your GitHub pull requests, powered by [RuleFuse](https://rulefuse.io).

RuleFuse analyzes your PR diff against your team's custom rules and posts a structured review comment directly on the pull request — including a pass/fail verdict, flagged issues by severity and file, and actionable suggestions.

---

## Quick Start

Add this workflow file to your repository at `.github/workflows/rulefuse.yml`:

```yaml
name: RuleFuse Code Review

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  review:
    runs-on: ubuntu-latest
    permissions:
      pull-requests: write

    steps:
      - uses: Magnet-js/RuleFuse-action@v1
        with:
          api_token: ${{ secrets.RULEFUSE_API_TOKEN }}
          repo_id: ${{ secrets.RULEFUSE_REPO_ID }}
```

---

## Setup

1. Sign up at [rulefuse.io](https://rulefuse.io) and connect your GitHub account.
2. Register your repository and write a custom system prompt — your team's coding rules (e.g. *"Enforce TypeScript strict mode. No `any` types. Functions must not exceed 50 lines."*).
3. Copy your **API token** and **Repo ID** from the RuleFuse dashboard.
4. Add them as secrets in your GitHub repository:
   - Go to **Settings → Secrets and variables → Actions**
   - Add `RULEFUSE_API_TOKEN` — your API token
   - Add `RULEFUSE_REPO_ID` — your Repo ID (a number shown in the dashboard)
5. Add the workflow file shown in [Quick Start](#quick-start) to your repository.

---

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `api_token` | Yes | — | Your RuleFuse API token. Store as a GitHub secret. |
| `repo_id` | Yes | — | Your RuleFuse Repo ID (found in the dashboard). |
| `api_url` | No | `https://api.rulefuse.io` | RuleFuse API base URL. Only needed for self-hosted deployments. |

---

## Permissions

The action requires `pull-requests: write` to post and update the review comment. Declare this explicitly in your job:

```yaml
jobs:
  review:
    runs-on: ubuntu-latest
    permissions:
      pull-requests: write   # required
```

Without this permission the action will fail with a 403 error when attempting to post the comment.

---

## What the Action Does

1. **Posts a placeholder comment** on the PR immediately — so reviewers know a review is in progress.
2. **Fetches the PR diff** via the GitHub API (up to 50,000 characters).
3. **Sends the diff** and PR title to the RuleFuse backend, which runs your custom rules through Gemini 2.5 Flash.
4. **Updates the comment** with the full review: a pass/fail verdict, an issues table (severity · file · description), and a suggestions list.

---

## Review Comment Example

```
## 🔍 RuleFuse Code Review — ✅ Passed

The changes look good overall. One minor style issue was noted in the auth module.

### Issues

| Severity | File | Description |
|----------|------|-------------|
| WARNING | src/auth/token.ts | Function `validateToken` exceeds the 50-line limit |

### Suggestions

- Consider extracting the expiry check logic into a `isExpired` helper for reuse.

---
*Powered by RuleFuse*
```

A failed review (any issue with severity `error`, `critical`, `high`, or `blocker`) shows **❌ Failed** in the heading.

---

## Versioning

Pin to a major version tag for stability while still receiving patch updates:

```yaml
- uses: Magnet-js/RuleFuse-action@v1
```

Or pin to an exact release for maximum reproducibility:

```yaml
- uses: Magnet-js/RuleFuse-action@v1.0.0
```

Using `@main` is not recommended in production as it may include unreleased changes.

---

## Pricing

RuleFuse charges per PR review at approximately **€0.001 per review**. See [rulefuse.io](https://rulefuse.io) for details. Usage and costs are visible in the dashboard.

---

## License

MIT
