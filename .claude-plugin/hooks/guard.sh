#!/usr/bin/env bash
# egm-autopilot PreToolUse guard (Bash tool). Exit 2 = block, message on stderr goes to Claude.
# Deterministic backstop: these rules hold even if the model, a prompt injection, or a bad
# ticket tries to bypass them. Server-side protections (protected branches, bot permissions)
# are still the real enforcement; this is defense in depth.
# Plugin hooks run in every session, so the rules apply only while egm-autopilot has marked
# this session active (egm_home.sh activate <session id>). Other sessions pass through.
set -euo pipefail

INPUT="$(cat)"
SID="$(printf '%s' "$INPUT" | sed -nE 's/.*"session_id"[[:space:]]*:[[:space:]]*"([A-Za-z0-9-]+)".*/\1/p' | head -n 1)"
[ -n "$SID" ] && [ -f "${EGM_HOME:-$HOME/.egm}/active/$SID" ] || exit 0

CMD="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')" || { echo "egm-autopilot guard: BLOCKED - cannot parse hook input" >&2; exit 2; }
[ -z "$CMD" ] && exit 0

block() { echo "egm-autopilot guard: BLOCKED - $1" >&2; exit 2; }

LOWER="$(printf '%s' "$CMD" | tr '[:upper:]' '[:lower:]')"

# 1. Never bypass hooks / signing
case "$LOWER" in *"--no-verify"*|*"--no-gpg-sign"*) block "bypassing git hooks/signing is not allowed";; esac

# 2. No force pushes
if printf '%s' "$LOWER" | grep -Eq 'git( [^|;&]*)? +push[^|;&]*( --force| -f( |$)|--force-with-lease| \+|:\+)'; then
  block "force push is not allowed"
fi

# 3. No pushes to protected/default branches (override list via EGM_PROTECTED_BRANCHES)
PROTECTED="${EGM_PROTECTED_BRANCHES:-main master develop release}"
if printf '%s' "$LOWER" | grep -Eq 'git( [^|;&]*)? +push( |$)'; then
  for b in $PROTECTED; do
    if printf '%s' "$LOWER" | grep -Eq "git( [^|;&]*)? +push[^|;&]*( |:)(refs/heads/)?($b|release/[^ ]*)( |\$)"; then
      block "pushing to protected branch '$b' is not allowed; push your ai/<KEY>-* branch"
    fi
  done
fi

# 4. No merging or approving MRs; the human owns that decision
if printf '%s' "$LOWER" | grep -Eq 'glab +mr +(merge|approve)|glab +api[^|;&]*merge_requests/[0-9]+/(merge|approve)'; then
  block "merging/approving MRs is reserved for humans"
fi

# 5. Commit attribution policy: every commit message must carry the Claude co-author trailer
if printf '%s' "$LOWER" | grep -Eq 'git( [^|;&]*)? +commit( |$)' \
   && printf '%s' "$LOWER" | grep -Eq '( -[a-z]*m[ =]|--message|( -f|--file))'; then
  MSG="$CMD"
  # -F/--file: check the file's text, not the command line.
  FILE="$(printf '%s' "$CMD" | sed -nE 's/.*( -F|--file)[ =]+("([^"]+)"|'"'"'([^'"'"']+)'"'"'|([^ ;&|]+)).*/\3\4\5/p')"
  [ -n "$FILE" ] && [ -f "$FILE" ] && MSG="$(cat "$FILE")"
  if ! printf '%s' "$MSG" | grep -Eiq 'Co-Authored-By: *Claude [^<]+<noreply@anthropic\.com>'; then
    block "commit message must include 'Co-Authored-By: Claude <exact model name> <noreply@anthropic.com>'"
  fi
fi

# 6. Obvious secret exfiltration / destructive patterns
if printf '%s' "$LOWER" | grep -Eq 'curl[^|;&]*(\.env|id_rsa|\.aws/credentials)|rm +-(rf|fr) +(/|~/?|\$home/?)( |$)'; then
  block "dangerous command pattern"
fi

exit 0
