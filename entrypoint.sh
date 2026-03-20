#!/usr/bin/env bash
set -euo pipefail

# ── 1. Post pending comment ──────────────────────────────────────────────────
echo "Posting pending comment..."
PENDING_RESPONSE=$(gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  "/repos/${REPO}/issues/${PR_NUMBER}/comments" \
  -f body="⏳ **Versed** is reviewing your changes...")

COMMENT_ID=$(echo "$PENDING_RESPONSE" | jq -r '.id')
echo "Pending comment posted (id: $COMMENT_ID)"

# ── 2. Get PR diff ───────────────────────────────────────────────────────────
echo "Fetching PR diff..."
DIFF=$(gh api \
  -H "Accept: application/vnd.github.v3.diff" \
  "/repos/${REPO}/pulls/${PR_NUMBER}")

if [ -z "$DIFF" ]; then
  echo "No diff found, skipping review."
  exit 0
fi

# Truncate diff to 50k chars to avoid hitting token limits
DIFF="${DIFF:0:50000}"

# ── 3. Send diff to Versed backend ──────────────────────────────────────────
echo "Sending diff to Versed..."
PAYLOAD=$(jq -n \
  --argjson repo_id "$VERSED_REPO_ID" \
  --arg diff "$DIFF" \
  --arg pr_title "${PR_TITLE:-}" \
  '{"repo_id": $repo_id, "diff": $diff, "pr_title": $pr_title}')

REVIEW_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "${VERSED_API_URL}/api/review" \
  -H "Authorization: Bearer ${VERSED_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

HTTP_CODE=$(echo "$REVIEW_RESPONSE" | tail -1)
BODY=$(echo "$REVIEW_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "200" ]; then
  echo "Versed API error (HTTP $HTTP_CODE): $BODY"
  gh api \
    --method PATCH \
    -H "Accept: application/vnd.github+json" \
    "/repos/${REPO}/issues/comments/${COMMENT_ID}" \
    -f body="❌ **Versed** failed to review this PR. Please check your configuration."
  exit 1
fi

# ── 4. Format and post review comment ───────────────────────────────────────
SUMMARY=$(echo "$BODY" | jq -r '.data.summary // "No summary"')
REVIEW_STATUS=$(echo "$BODY" | jq -r '.status // "passed"')
ISSUES=$(echo "$BODY" | jq -r '
  .data.issues[]? |
  "| \(.severity | ascii_upcase) | \(.file) | \(.description) |"
')
SUGGESTIONS=$(echo "$BODY" | jq -r '.data.suggestions[]? | "- \(.)"')

# Build status badge for comment heading
if [ "$REVIEW_STATUS" = "failed" ]; then
  STATUS_BADGE="❌ Failed"
else
  STATUS_BADGE="✅ Passed"
fi

COMMENT="## 🔍 Versed Code Review — ${STATUS_BADGE}

${SUMMARY}"

if [ -n "$ISSUES" ]; then
  COMMENT="${COMMENT}

### Issues

| Severity | File | Description |
|----------|------|-------------|
${ISSUES}"
fi

if [ -n "$SUGGESTIONS" ]; then
  COMMENT="${COMMENT}

### Suggestions

${SUGGESTIONS}"
fi

COMMENT="${COMMENT}

---
*Powered by [Versed](https://useversed.com)*"

# Update the pending comment with the final review
gh api \
  --method PATCH \
  -H "Accept: application/vnd.github+json" \
  "/repos/${REPO}/issues/comments/${COMMENT_ID}" \
  -f body="$COMMENT"

echo "Review posted successfully (status: ${REVIEW_STATUS})."
